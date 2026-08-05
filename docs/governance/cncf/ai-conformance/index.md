# Kubernetes AI conformance

This document summarizes how k0rdent satisfies the Kubernetes AI Conformance requirements for Kubernetes v1.35.
It is a reviewer-facing evidence page built from captured test runs on k0rdent v1.9.0 with a child cluster running k0s v1.35.3+k0s.0.

## Test environment

The evidence below was captured against a k0rdent-managed child cluster on Azure:

- k0rdent (KCM) v1.9.0 on a kind management cluster
- Child cluster: 3× `Standard_A4_v2` control-plane VMs + 2× `Standard_NC4as_T4_v3` worker VMs (one NVIDIA Tesla T4 each)
- k0s v1.35.3+k0s.0 (Kubernetes v1.35.3) on the child cluster
- Catalog-driven installs via `MultiClusterService` for GPU Operator, Envoy Gateway, Volcano, KubeRay; raw Helm for kube-prometheus-stack and dra-example-driver

## DRA support

**Requirement:** Dynamic Resource Allocation APIs must be available and usable for accelerator allocation.

**Status on k0rdent:** Implemented.

k0rdent's child cluster runs Kubernetes v1.35.3, where DRA is available at `resource.k8s.io/v1` and enabled by default. We validated the full DRA flow with the upstream `dra-example-driver` v0.2.1: each worker advertised eight simulated devices via a `ResourceSlice`, the scheduler allocated one to a Pod through a `ResourceClaimTemplate`, and the consuming container received the allocated device's metadata as environment variables.

This shows not only that the API surface exists, but that the allocation path is functional end to end on a k0rdent-provisioned cluster.

Minimal example:

```console
$ kubectl api-resources --api-group=resource.k8s.io
NAME                     APIVERSION           KIND
deviceclasses            resource.k8s.io/v1   DeviceClass
resourceclaims           resource.k8s.io/v1   ResourceClaim
resourceclaimtemplates   resource.k8s.io/v1   ResourceClaimTemplate
resourceslices           resource.k8s.io/v1   ResourceSlice

$ kubectl -n dra-demo get resourceclaim
NAME                     STATE
dra-demo-pod-gpu-mwv6r   allocated,reserved

$ kubectl logs -n dra-demo dra-demo-pod | grep GPU_DEVICE_5
GPU_DEVICE_5="gpu-5"
GPU_DEVICE_5_RESOURCE_CLAIM="03f5fca0-c04c-43d2-9ba9-db6f570bce00"
GPU_DEVICE_5_SHARING_STRATEGY="TimeSlicing"
GPU_DEVICE_5_TIMESLICE_INTERVAL="Default"
```

The four per-device environment variables - identity, claim UUID, sharing strategy, and time-slice interval, are the direct demonstration of the spec's "fine-grained resource requests beyond simple counts" wording: structured metadata that varies per allocation, derived from the driver's understanding of its own device pool.

Further reading:

- [Dynamic Resource Allocation in Kubernetes](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/)
- [kubernetes-sigs/dra-example-driver](https://github.com/kubernetes-sigs/dra-example-driver)

## Driver runtime management

**Requirement:** The platform should support installation and management of accelerator drivers and runtime components.

**Status on k0rdent:** Implemented.

k0rdent supports NVIDIA driver and runtime management through the NVIDIA GPU Operator, installed via the k0rdent catalog `gpu-operator-26-3-1` ServiceTemplate as a `MultiClusterService` reconciled onto the child cluster. On the test cluster, the operator installed the NVIDIA driver, configured the NVIDIA runtime for containerd, and registered the `nvidia`, `nvidia-cdi`, and `nvidia-legacy` `RuntimeClass` resources. GPU-requesting Pods that opt into `runtimeClassName: nvidia` receive working CUDA access; the device plugin advertises `nvidia.com/gpu` capacity on each worker.

Minimal example:

```console
$ kubectl -n gpu-operator exec ds/nvidia-driver-daemonset -- \
    nvidia-smi --query-gpu=driver_version --format=csv,noheader
580.126.20

$ kubectl logs cuda-smoketest
NVIDIA-SMI 580.126.20             Driver Version: 580.126.20

$ kubectl get runtimeclass
NAME            HANDLER
nvidia          nvidia
nvidia-cdi      nvidia-cdi
nvidia-legacy   nvidia-legacy
```

Further reading:

- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)
- [k0rdent service templates](https://docs.k0rdent.io/next/admin/ksm/ksm-service-templates/)
- [Nvidia GPU Operator Service Template](https://catalog.k0rdent.io/latest/apps/nvidia/)

## GPU sharing

**Requirement:** The platform should support mechanisms to share a single physical accelerator among multiple workloads.

**Status on k0rdent:** Implemented.

k0rdent supports GPU sharing through NVIDIA device plugin time-slicing, configured via a single `kubectl patch` against the GPU Operator's `ClusterPolicy`. On the test cluster, each Tesla T4 was reconfigured to advertise four schedulable `nvidia.com/gpu` replicas; cluster-wide capacity moved from `nvidia.com/gpu = 2` to `nvidia.com/gpu = 8`, and four GPU-requesting Pods ran concurrently on a single physical GPU, all reporting the same physical GPU UUID. T4 hardware does not support MIG, so time-slicing is the applicable sharing mechanism on this SKU. Sharing was reverted with a second `kubectl patch'.

Minimal example:

```console
$ kubectl get node <worker> -o jsonpath='{.status.capacity.nvidia\.com/gpu}{"\n"}'
4

$ kubectl get node <worker> -o jsonpath='{.metadata.labels.nvidia\.com/gpu\.sharing-strategy}{"\n"}'
time-slicing

$ kubectl get node <worker> -o jsonpath='{.metadata.labels.nvidia\.com/gpu\.product}{"\n"}'
Tesla-T4-SHARED

$ for p in shared-gpu-{1..4}; do kubectl logs "$p" | head -1; done
GPU 0: Tesla T4 (UUID: GPU-05fd76a7-f718-d68f-1ed3-28921dd4bcbf)
GPU 0: Tesla T4 (UUID: GPU-05fd76a7-f718-d68f-1ed3-28921dd4bcbf)
GPU 0: Tesla T4 (UUID: GPU-05fd76a7-f718-d68f-1ed3-28921dd4bcbf)
GPU 0: Tesla T4 (UUID: GPU-05fd76a7-f718-d68f-1ed3-28921dd4bcbf)
```

The identical UUID across four pods that the scheduler treats as separate `nvidia.com/gpu` units is the distinctive proof of time-slicing.

Further reading:

- [NVIDIA k8s-device-plugin](https://github.com/NVIDIA/k8s-device-plugin)
- [NVIDIA GPU Operator time-slicing documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)

## Virtualized accelerator

**Requirement:** The platform should support virtualized accelerators where available.

**Status on k0rdent:** Not Implemented.

k0rdent does not ship a packaged vGPU integration. Virtualized GPU support depends on NVIDIA vGPU licensing and A100-class or newer hardware, both outside the scope of this submission's evidence cluster (T4). Users running on vGPU-capable hardware can install the vGPU driver and standard NVIDIA Device Plugin via the GPU Operator; this path is supported upstream but was not demonstrated in this submission.

Further reading:

- [NVIDIA vGPU documentation](https://docs.nvidia.com/grid/)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)

## AI inference

**Requirement:** A working Kubernetes Gateway API implementation must support inference traffic management.

**Status on k0rdent:** Implemented.

k0rdent supports Gateway API resources and standard Gateway implementations. We installed Envoy Gateway v1.7.1 via the k0rdent catalog `envoy-gateway-1-7-1` ServiceTemplate (the chart bundles Gateway API CRDs), then configured a `GatewayClass`, `Gateway`, and `HTTPRoute` to route `/predict` traffic to a mock inference backend. The child cluster's CCM allocated a real Azure Standard Load Balancer IP for the `Gateway`, so requests exercise the full external path. Requests matching the `/predict` prefix reached the backend; requests against `/` were rejected by Envoy with `404 Not Found`, and the absence of the backend's distinctive `x-app-name: http-echo` response header on the rejected request confirms the rejection happened in the data plane, not in the backend.

Minimal example:

```console
$ kubectl get gatewayclass eg
NAME   CONTROLLER                                      ACCEPTED
eg     gateway.envoyproxy.io/gatewayclass-controller   True

$ kubectl get gateway eg
NAME   CLASS   ADDRESS         PROGRAMMED
eg     eg      20.235.37.179   True

$ curl -si http://20.235.37.179/predict
HTTP/1.1 200 OK
x-app-name: http-echo
{"prediction":0.87}

$ curl -si http://20.235.37.179/
HTTP/1.1 404 Not Found
```

k0rdent v1.9.0 itself replaced its internal Nginx Ingress with Envoy Gateway behind the Gateway API; the platform demonstrates the same implementation it asks workloads to use.

Further reading:

- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)

## Gang scheduling

**Requirement:** The platform must support all-or-nothing scheduling for distributed workloads.

**Status on k0rdent:** Implemented.

k0rdent supports gang scheduling with Volcano, installed via the k0rdent catalog `volcano-1-14-1` ServiceTemplate (this template was contributed to the catalog as part of the AI conformance work). We demonstrated both successful atomic placement and full refusal of an oversized gang: a two-task job was bound atomically and ran to completion, while a twelve-task job whose combined CPU demand exceeded the cluster was refused. Every Pod stayed `Pending` even though four of them would have fit individually. The PodGroup's `spec.minResources.cpu: 18` field captures the gang's resource demand as a first-class object, evaluated as a single unit.

Minimal example:

```console
$ kubectl get vcjob gang-demo
NAME        STATUS      MINAVAILABLE
gang-demo   Completed   2

$ kubectl get vcjob gang-overflow
NAME            STATUS    MINAVAILABLE
gang-overflow   Pending   12

$ kubectl get pods -l volcano.sh/job-name=gang-overflow -o wide | head -3
NAME                     READY   STATUS    NODE
gang-overflow-worker-0   0/1     Pending   <none>
gang-overflow-worker-1   0/1     Pending   <none>

$ kubectl describe podgroup -n default | grep -A1 'NotEnoughResources'
    Reason:  NotEnoughResources
    Message: 12/12 tasks in gang unschedulable: ... Pending: 4 Schedulable, 8 Unschedulable.
```

Volcano explicitly identifies the four pods that would individually fit and refuses to bind any of them. That asymmetry is gang scheduling.

Further reading:

- [Volcano](https://volcano.sh/en/)
- [Volcano Service Template](https://catalog.k0rdent.io/latest/apps/volcano/)

## Cluster autoscaling

**Requirement:** The platform must support scaling accelerator-capable node groups through Kubernetes cluster autoscaling.

**Status on k0rdent:** Implemented.

k0rdent does not ship its own autoscaler.
k0rdent provisions clusters via Cluster API and renders standard CAPI `MachineDeployment` resources (`cluster.x-k8s.io/v1beta2`) for every worker pool, so the upstream Kubernetes Cluster Autoscaler with the CAPI provider (`--cloud-provider=clusterapi`) integrates without modification.
Accelerator-aware scale-up is driven by pending Pods that request `nvidia.com/gpu` and by the GPU resources advertised through the NVIDIA device plugin, mounted on `MachineDeployment`-scoped node pools labelled accordingly.

The same upstream chart is also available in the k0rdent catalog as `cluster-autoscaler-9-55-0` for one-step installation.

Reference configuration (CAPI provider):

```shell
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set cloudProvider=clusterapi \
  --set autoDiscovery.clusterName=<your-clusterdeployment-name>
```

Further reading:

- [Kubernetes Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [Cluster Autoscaler Cluster API provider](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/clusterapi)
- [Cluster Autoscaler GPU support](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler#gpu-support)
- [Cluster Autoscaler ServiceTemplate](https://catalog.k0rdent.io/latest/apps/cluster-autoscaler/)

## Pod autoscaling

**Requirement:** Horizontal Pod Autoscaler must function correctly for Pods that use accelerators.

**Status on k0rdent:** Implemented.

k0rdent's child cluster inherits k0s's bundled `metrics-server`, so HPA works out of the box on a default cluster - no additional install required. We deployed a GPU-requesting Deployment (`nvidia.com/gpu: 1` per replica) and an `autoscaling/v2` HPA targeting CPU utilization with `maxReplicas=3`. Under load, HPA increased the replica count from one to three; two Pods placed (one per GPU worker) and the third remained `Pending` because the scheduler enforced the cluster-wide `nvidia.com/gpu = 2` cap independently of HPA's signal.

The combination demonstrates both clauses of the requirement: HPA functions correctly for accelerator-using Pods, and the scheduler enforces accelerator capacity even when autoscaling wants more replicas.

Minimal example:

```console
$ kubectl get hpa gpu-burner
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS
gpu-burner   Deployment/gpu-burner   cpu: 500%/50%   1         3         3

$ kubectl get pods -l app=gpu-burner -o wide
NAME                          READY   STATUS    NODE
gpu-burner-759c8596bf-k6hr7   1/1     Running   <worker-1>
gpu-burner-759c8596bf-jspb7   1/1     Running   <worker-2>
gpu-burner-759c8596bf-wgrs7   0/1     Pending   <none>
```

For custom AI/ML metrics (the second clause of the requirement), the standard Kubernetes Custom Metrics API (`custom.metrics.k8s.io`) and External Metrics API (`external.metrics.k8s.io`) are available; an adapter such as `prometheus-adapter` or KEDA can be installed against the cluster's monitoring backend to drive HPA off DCGM or workload metrics. The platform requirement is that `autoscaling/v2` and the metrics-API extension model are available, both of which they are on k0rdent.

Further reading:

- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [metrics-server](https://github.com/kubernetes-sigs/metrics-server)

## Accelerator metrics

**Requirement:** The platform must expose fine-grained accelerator metrics through a standard, machine-readable endpoint.

**Status on k0rdent:** Implemented.

k0rdent supports accelerator metrics through NVIDIA DCGM Exporter, deployed by the GPU Operator on every worker. The evidence run integrated DCGM Exporter with `kube-prometheus-stack` using a `ServiceMonitor` and verified that Prometheus scraped per-GPU metrics labelled with UUID, model name, PCI bus ID, hostname, and driver version.
All four spec-named DCGM metrics: `DCGM_FI_DEV_GPU_UTIL`, `DCGM_FI_DEV_FB_USED`, `DCGM_FI_DEV_GPU_TEMP`, `DCGM_FI_DEV_POWER_USAGE`, flow through end-to-end and are queryable via the standard Prometheus API.

The platform's customer-facing observability product is **k0rdent Observability and FinOps (KOF)**, which uses the same `ServiceMonitor` discovery contract and Prometheus exposition format, ingesting into VictoriaMetrics. KOF is the recommended production backend for k0rdent users; `kube-prometheus-stack` was used here because it is the field-standard backend for AI conformance evidence and matches the topology of a single Azure child cluster reviewed in isolation.

Minimal example:

```console
$ curl -s 'http://localhost:9090/api/v1/query?query=DCGM_FI_DEV_GPU_UTIL'
"__name__":"DCGM_FI_DEV_GPU_UTIL"
"UUID":"GPU-05fd76a7-f718-d68f-1ed3-28921dd4bcbf"
"modelName":"Tesla T4"
"Hostname":"k0rdent-ai-conformance-md-stxjr-77mds"
"DCGM_FI_DRIVER_VERSION":"580.126.20"
```

Further reading:

- [NVIDIA DCGM Exporter](https://docs.nvidia.com/datacenter/dcgm/latest/gpu-telemetry/dcgm-exporter.html)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [k0rdent Observability and FinOps (KOF)](https://docs.k0rdent.io/next/admin/kof/)

## AI service metrics

**Requirement:** The platform must discover and collect workload metrics in a standard format.

**Status on k0rdent:** Implemented.

k0rdent supports workload metrics collection through Prometheus Operator-compatible monitoring stacks. We installed `kube-prometheus-stack`, applied a `ServiceMonitor` for a sample inference-shaped workload, and verified that Prometheus discovered the target and stored its metrics with workload-identifying labels. This demonstrates the standard collection path most AI services use in practice: workload metrics exposed on `/metrics` in Prometheus exposition format, discovered via `ServiceMonitor`, and stored in Prometheus. The same path applies to AI inference servers (vLLM, KServe, Triton, NIM, etc.) that expose Prometheus-format `/metrics`.

For production deployments, k0rdent's **KOF** consumes the same `ServiceMonitor` and `PodMonitor` resources via prometheus-operator-crds and ingests into VictoriaMetrics. The discovery contract is identical to the one demonstrated here.

Minimal example:

```console
$ curl -s 'http://localhost:9090/api/v1/query' \
    --data-urlencode 'query=up{job="sample-inference"}'
"job":"sample-inference"
"namespace":"default"
"value":[..., "1"]

$ curl -s 'http://localhost:9090/api/v1/query' \
    --data-urlencode 'query=node_cpu_seconds_total{job="sample-inference"}'
"__name__":"node_cpu_seconds_total"
```

Further reading:

- [Prometheus Operator `ServiceMonitor`](https://prometheus-operator.dev/docs/developer/getting-started/#using-servicemonitors)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [k0rdent Observability and FinOps (KOF)](https://docs.k0rdent.io/next/admin/kof/)

## Secure accelerator access

**Requirement:** Accelerator access must be isolated so that only authorized workloads can use the device.

**Status on k0rdent:** Implemented.

k0rdent relies on the standard Kubernetes device plugin model for GPU isolation, mediated by the NVIDIA Device Plugin and the `nvidia` `RuntimeClass`. On the test cluster, a Pod without a GPU request and without `runtimeClassName: nvidia` had no access to NVIDIA tooling or device nodes (`nvidia-smi: not found`). When three Pods each requested one GPU on a two-GPU cluster, the scheduler admitted two (one per GPU worker) and kept the third `Pending` with `Insufficient nvidia.com/gpu`.

Together, these checks show both isolation-by-default and capacity enforcement for accelerator access.

Minimal example:

```console
$ kubectl logs no-gpu-request
sh: 1: nvidia-smi: not found
NO GPU ACCESS (expected)

$ kubectl get pods gpu-hog-1 gpu-hog-2 gpu-hog-3
NAME        READY   STATUS
gpu-hog-1   1/1     Running
gpu-hog-2   1/1     Running
gpu-hog-3   0/1     Pending
```

Further reading:

- [Kubernetes device plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/)
- [NVIDIA k8s-device-plugin](https://github.com/NVIDIA/k8s-device-plugin)

## Robust controller

**Requirement:** The platform must be able to run at least one complex AI operator with CRDs and reliable reconciliation behavior.

**Status on k0rdent:** Implemented.

k0rdent supports complex AI operators such as KubeRay, installed via the k0rdent catalog `kuberay-operator-1-6-1` ServiceTemplate. We reconciled a `RayCluster` into head and worker Pods plus the supporting headless Service, ran a distributed Ray task end-to-end (the task connected to GCS, observed both nodes in the cluster, and returned the expected results), then deleted the head Pod to verify that the operator recreated it and restored the cluster to a ready state.

This goes beyond a basic install check: it demonstrates CRD registration, reconciliation of child resources, a successful workload, and recovery after disruption.

Minimal example:

```console
$ kubectl get raycluster raycluster-demo
NAME              DESIRED WORKERS   AVAILABLE WORKERS   STATUS
raycluster-demo   1                 1                   ready

$ kubectl exec -i "$HEAD_POD" -- python - <<'PY'
import ray; ray.init(address='auto')
@ray.remote
def f(x): return x * x
print('Result:', ray.get([f.remote(i) for i in range(5)]))
print('Nodes:', len(ray.nodes()))
PY
Result: [0, 1, 4, 9, 16]
Nodes: 2

$ kubectl describe raycluster raycluster-demo | grep -E 'CreatedHeadPod|DeletedHeadPod'
Normal  CreatedHeadPod    Created head Pod default/raycluster-demo-head-gkpwl
Normal  DeletedHeadPod    Deleted head Pod default/raycluster-demo-head-gkpwl
Normal  CreatedHeadPod    Created head Pod default/raycluster-demo-head-p6qqn
```

Further reading:

- [KubeRay](https://docs.ray.io/en/latest/cluster/kubernetes/)
