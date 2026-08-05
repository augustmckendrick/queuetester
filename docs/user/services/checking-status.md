# Checking status

The `.status.services` field of the `ClusterDeployment` and `MultiClusterService` objects shows the deployment status for each service.

## Service Status Structure

Each entry in `.status.services[]` contains:

- `type`: Deployment type - `Helm`, `Kustomize`, or `Resource`
- `name`: Service name
- `namespace`: Service namespace
- `template`: ServiceTemplate name used
- `version`: Application version from the ServiceTemplate
- `state`: Current deployment state (see below)
- `failureMessage`: Error message if state is `Failed`
- `lastStateTransitionTime`: When the state last changed

### Service States

- **`Pending`**: Service is waiting (e.g., for dependencies to be satisfied)
- **`Provisioning`**: Service is currently being deployed
- **`Deployed`**: Service successfully deployed and running
- **`Failed`**: Service deployment failed (check `failureMessage`)
- **`Deleting`**: Service is being removed

## ClusterDeployment Status Example

For example, if you were to `describe` the `ClusterDeployment` with these services, you would see status information such as:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ClusterDeployment
metadata:
  . . .
  generation: 1
  name: wali-aws-dev
  namespace: kcm-system
  . . .
spec:
  . . .
  serviceSpec:
    services:
    - name: ingress-nginx
      namespace: ingress-nginx
      template: ingress-nginx-4-11-3
    - name: kyverno
      namespace: kyverno
      template: kyverno-3-2-6
    . . .
status:
  . . .
  observedGeneration: 1
  services:
    - lastTransitionTime: "2024-12-11T23:03:05Z"
      name: ingress-nginx
      namespace: ingress-nginx
      state: Deployed
      template: ingress-nginx-4-11-3
      type: Helm
      version: ingress-nginx-4-11-3
    - lastTransitionTime: "2024-12-11T23:03:05Z"
      name: kyverno
      namespace: kyverno
      state: Deployed
      template: kyverno-3-2-6
      type: Helm
      version: kyverno-3-2-6
```

Based on the information above both kyverno and ingress-nginx are installed in their respective namespaces on the target cluster.
You can check to see for yourself:

```bash
kubectl get pod -n kyverno
```
```console { .no-copy }
NAME                                             READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-96c5d48b4-sg5ts     1/1     Running   0          2m39s
kyverno-background-controller-65f9fd5859-tm2wm   1/1     Running   0          2m39s
kyverno-cleanup-controller-848b4c579d-ljrj5      1/1     Running   0          2m39s
kyverno-reports-controller-6f59fb8cd6-s8jc8      1/1     Running   0          2m39s
```
```bash
kubectl get pod -n ingress-nginx 
```
```console { .no-copy }
NAME                                       READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-cbcf8bf58-zhvph   1/1     Running   0          24m
```

You can get more information on how to access the child cluster in the [create a cluster deployment](../../admin/clusters/deploy-cluster.md)
chapter, and more on `ServiceTemplate` objects in the [Template Guide](../../reference/template/index.md).

## Checking Service Upgrade Paths

Both `ClusterDeployment` and `MultiClusterService` provide upgrade path information in `.status.servicesUpgradePaths[]`:

```yaml
status:
  servicesUpgradePaths:
    - name: ingress-nginx
      namespace: ingress-nginx
      template: ingress-nginx-4-11-3
      availableUpgrades:
        - versions:
            - name: ingress-nginx-4-11-5
              version: 4.11.5
            - name: ingress-nginx-4-12-0
              version: 4.12.0
```

This shows which ServiceTemplates the current service can be upgraded to. See [Service Upgrade](service-upgrade.md) for more details.

## Monitoring Commands

**View service status:**
```bash
kubectl get clusterdeployment <name> -n <namespace> -o jsonpath='{.status.services[*].state}'
```

**Check for failed services:**
```bash
kubectl get clusterdeployment <name> -n <namespace> -o jsonpath='{.status.services[?(@.state=="Failed")]}'
```

**View failure messages:**
```bash
kubectl get clusterdeployment <name> -n <namespace> -o jsonpath='{.status.services[*].failureMessage}' | tr ' ' '\n'
```

**Check service versions:**
```bash
kubectl get clusterdeployment <name> -n <namespace> -o jsonpath='{range .status.services[*]}{.name}{"\t"}{.version}{"\n"}{end}'
```

## MultiClusterService Status

For `MultiClusterService`, the status includes service upgrade paths for all defined services and `MultiClusterService` conditions:

```yaml
status:
  conditions:
    - lastTransitionTime: "2025-11-07T23:25:25Z"
      message: ""
      observedGeneration: 2
      reason: Succeeded
      status: "True"
      type: ServicesReferencesValidation
    - lastTransitionTime: "2025-11-07T23:25:25Z"
      message: ""
      observedGeneration: 2
      reason: Succeeded
      status: "True"
      type: ServicesDependencyValidation
    - lastTransitionTime: "2025-11-07T23:25:25Z"
      message: ""
      observedGeneration: 2
      reason: Succeeded
      status: "True"
      type: MultiClusterServiceDependencyValidation
    - lastTransitionTime: "2025-11-07T23:28:44Z"
      message: 1/1
      reason: Succeeded
      status: "True"
      type: ClusterInReadyState
    - lastTransitionTime: "2025-11-07T23:28:44Z"
      message: Object is ready
      reason: Succeeded
      status: "True"
      type: Ready
  observedGeneration: 2
  servicesUpgradePaths:
    - availableUpgrades:
        - versions:
            - name: external-secrets-8abcd
              version: 0.11.0
      name: managed-eso
      namespace: global
      template: external-secrets-7vpwh
```

**Monitor MultiClusterService:**
```bash
# View overall status
kubectl get multiclusterservice <name> -o wide
```
