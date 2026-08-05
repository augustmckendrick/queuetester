# QuickStart 1 - Setup Management Cluster

Please review the [Guide to QuickStarts](index.md) for preliminaries. This QuickStart guide details setting up a single-VM environment for managing and interacting with {{{ docsVersionInfo.k0rdentName }}}, and for hosting its components on a single-node local Kubernetes management cluster. Once {{{ docsVersionInfo.k0rdentName }}} is installed on the management cluster, you can drive it by SSHing into the management node (`kubectl` is there and will be provisioned with the appropriate `kubeconfig`) or remotely by various means. For example, you can install the management cluster `kubeconfig` in Lens or another Kubernetes dashboard on your laptop, tunnel across from your own local `kubectl`, and so on.

## Install a Kubernetes cluster as the management cluster

The {{{ docsVersionInfo.k0rdentName }}} management cluster is a plain Kubernetes cluster; you can use any CNCF-certified 
distribution to create it. For example, we have documented creating a [single-node k0s cluster](../admin/installation/create-mgmt-clusters/mgmt-create-k0s-single.md), a [multi-node k0s cluster](../admin/installation/create-mgmt-clusters/mgmt-create-k0s-multi.md), 
and an [AWS EKS multi-node cluster](../admin/installation/create-mgmt-clusters/mgmt-create-eks-multi.md) to use as your management cluster. The instructions on this page explain the single-node k0s process,
but feel free to deploy one of the other configurations, then move on to configuring and creating a child cluster on your chosen architecture.

[k0s Kubernetes](https://k0sproject.io) is a CNCF-certified minimal single-binary Kubernetes that installs with one command and brings along its own CLI. We're using it to quickly set up a single-node management cluster on our manager node. However, {{{ docsVersionInfo.k0rdentName }}} works on any CNCF-certified Kubernetes. If you choose to use something else, we would love to hear how you set things up to work for you.

> NOTE:
> k0s isn't supported on MacOS, but you can install a test cluster using:
> ```
> brew install kind && kind create cluster -n k0rdent
> ```
> Skip ahead to [Install kubectl](#install-kubectl).

Download and install k0s:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get.k0s.sh | sudo sh
sudo k0s install controller --enable-worker --no-taints
sudo k0s start
```

You can check to see if the cluster is working by leveraging `kubectl` (installed and configured automatically by k0s) via the k0s CLI:

```bash
sudo k0s kubectl get nodes
```

You should see something like this:

```console { .no-copy }
NAME              STATUS   ROLES    AGE   VERSION
ip-172-31-29-61   Ready    <none>   46s   v1.31.2+k0s
```

## Install kubectl

k0s installs a compatible `kubectl` and makes it accessible via its own client. But to make your environment easier to configure, we advise installing `kubectl` the normal way on the manager node and using it to control the local k0s management cluster:

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
sudo apt-get update
sudo apt-get install -y kubectl
```

## Get the local k0s cluster's kubeconfig for kubectl

On startup, k0s stores the administrator's `kubeconfig` in a local directory, making it easy to access:

```bash
sudo cp /var/lib/k0s/pki/admin.conf KUBECONFIG
sudo chmod +r KUBECONFIG
export KUBECONFIG=./KUBECONFIG
```

At this point, your newly-installed `kubectl` should be able to interoperate with the k0s management cluster with administrative privileges. Test to see that the cluster is ready (this usually takes about one minute):

```bash
kubectl get nodes
```

You should see something like this:

```console { .no-copy }
NAME              STATUS   ROLES           AGE   VERSION
ip-172-31-29-61   Ready    control-plane   25m   v1.31.2+k0s
```

## Install Helm

The Helm Kubernetes package manager is used to install {{{ docsVersionInfo.k0rdentName }}} services. We'll install Helm as follows:

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Issuing these commands should produce something very much like the following output:

```console { .no-copy }
Downloading https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
Verifying checksum... Done.
Preparing to install helm into /usr/local/bin
helm installed into /usr/local/bin/helm
```

## Install {{{ docsVersionInfo.k0rdentName }}}

Now we'll install {{{ docsVersionInfo.k0rdentName }}} itself into the k0s management cluster:

```bash
helm install kcm {{{ extra.docsVersionInfo.ociRegistry }}} --version {{{ extra.docsVersionInfo.k0rdentDotVersion }}} -n kcm-system --create-namespace
```
```console { .no-copy }
Pulled: ghcr.io/k0rdent/kcm/charts/kcm:{{{ extra.docsVersionInfo.k0rdentDotVersion }}}
Digest: {{{ extra.docsVersionInfo.k0rdentDigestValue }}}
NAME: kcm
LAST DEPLOYED: {{{ extra.docsVersionInfo.k0rdentDigestDate }}}
NAMESPACE: kcm-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

{{{ docsVersionInfo.k0rdentName }}} startup takes several minutes.

## Check that {{{ docsVersionInfo.k0rdentName }}} cluster management pods are running

One fundamental {{{ docsVersionInfo.k0rdentName }}} subsystem, k0rdent Cluster Manager (KCM), handles cluster lifecycle management on clouds and infrastructures. For example, it helps you configure and compose clusters and manages infrastructure via Cluster API (CAPI). Before continuing, check that the KCM pods are ready:

```bash
kubectl get pods -n kcm-system   # check pods in the kcm-system namespace
```

You should see something like:

```console { .no-copy }
NAME                                                           READY   STATUS
NAME                                                           READY   STATUS    RESTARTS   AGE
azureserviceoperator-controller-manager-db4c875d7-f68vz        1/1     Running   0          6h41m
azureserviceoperator-controller-manager-db4c875d7-nzvmc        1/1     Running   0          6h41m
capa-controller-manager-d68956949-88tqk                        1/1     Running   0          6h41m
capd-controller-manager-84c76c4ddc-xvhnx                       1/1     Running   0          6h41m
capg-controller-manager-578d48979c-6x85x                       1/1     Running   0          6h41m
capi-controller-manager-9577f8854-5d2pz                        1/1     Running   0          6h42m
capi-ipam-in-cluster-controller-manager-56c7bd877c-76dpp       1/1     Running   0          6h41m
capi-ipam-infoblox-controller-manager-548877ddb5-wjtkg         1/1     Running   0          6h41m
capk-controller-manager-7699d4479b-ncwpx                       1/1     Running   0          6h41m
capo-controller-manager-6875d8fc54-rfcg5                       1/1     Running   0          6h40m
capv-controller-manager-fd97b7d55-ncr64                        1/1     Running   0          6h41m
capz-controller-manager-f698659cf-2mn9q                        1/1     Running   0          6h41m
helm-controller-5466948d9f-5sr6m                               1/1     Running   0          6h45m
k0smotron-controller-manager-bootstrap-5686664764-r7p5l        1/1     Running   0          6h42m
k0smotron-controller-manager-control-plane-6456dfd98-jqm7j     1/1     Running   0          6h41m
k0smotron-controller-manager-infrastructure-8479cbc858-wlxrc   1/1     Running   0          6h41m
kcm-cert-manager-76c7bcbcff-6ln5x                              1/1     Running   0          6h45m
kcm-cert-manager-cainjector-66c48469bb-jhvv4                   1/1     Running   0          6h45m
kcm-cert-manager-webhook-f6587877f-4ndk9                       1/1     Running   0          6h45m
kcm-cluster-api-operator-647d865b8c-2js6l                      1/1     Running   0          6h42m
kcm-controller-manager-7d795bc8f-kmzw8                         1/1     Running   0          6h42m
kcm-rbac-manager-7579db64d9-42p27                              1/1     Running   0          6h45m
kcm-regional-telemetry-57fb8c6f8f-fljqp                        1/1     Running   0          6h45m
kcm-reloader-fc9cbb8cf-mjpb5                                   1/1     Running   0          6h45m
orc-controller-manager-6fb5b76975-jvlx6                        1/1     Running   0          6h42m
source-controller-597784bdbb-zk62n                             1/1     Running   0          6h45m
velero-5c95c499cf-wx2c8                                        1/1     Running   0          6h45m
```

Pods reported in states other than Running should become ready momentarily.

## Check that the projectsveltos pods are running

The other fundamental {{{ docsVersionInfo.k0rdentName }}} subsystem, k0rdent State Manager (KSM), handles services configuration and lifecycle management on clusters. This utilizes the [projectsveltos](https://github.com/projectsveltos) Kubernetes Add-On Controller and other open source projects. Before continuing, check that the KSM pods are ready:

```bash
kubectl get pods -n projectsveltos   # check pods in the projectsveltos namespace
```

You should see something like:

```console { .no-copy }
NAME                                      READY   STATUS    RESTARTS   AGE
access-manager-84d4d7747d-c8hqk           1/1     Running   0          6h42m
addon-controller-54b9c4f974-vfsg6         1/1     Running   0          6h41m
classifier-manager-6556b9d7c7-5gk7f       1/1     Running   0          6h42m
event-manager-5548b4f698-dz9h2            1/1     Running   0          6h42m
hc-manager-7bd8cff8c-mf6fr                1/1     Running   0          6h42m
mcp-server-554f4799b9-f8hgh               1/1     Running   0          6h42m
sc-manager-567cc8f5d7-kgj95               1/1     Running   0          6h42m
shard-controller-7bcb99dbf7-qwd7r         1/1     Running   0          6h42m
sveltos-agent-manager-6c68cf498c-t4xl6    1/1     Running   0          6h41m
techsupport-controller-7b5bd7d4c7-gsv5k   1/1     Running   0          6h42m
```

If you have fewer pods than shown above, just wait 5 minutes or so for all the pods to reconcile and start running.

## Verify that {{{ docsVersionInfo.k0rdentName }}} itself is ready

The actual measure of whether {{{ docsVersionInfo.k0rdentName }}} is ready is the state of the `Management` object. To check, issue this command:

```bash
kubectl get Management -n kcm-system
```
```console { .no-copy }
NAME   READY   RELEASE     AGE
kcm    True    kcm-{{{ extra.docsVersionInfo.k0rdentVersion }}}   9m
```

## Verify that KCM provider and related templates are available

{{{ docsVersionInfo.k0rdentName }}} KCM leverages CAPI to manage Kubernetes cluster assembly and host infrastructure. CAPI requires infrastructure providers for different clouds and infrastructure types. These are delivered and referenced within {{{ docsVersionInfo.k0rdentName }}} using templates, instantiated in the management cluster as objects. Before continuing, verify that the default provider template objects are installed and verified. Other templates are also stored as provider templates in this namespace (for example, the templates that determine setup of KCM itself and other parts of the {{{ docsVersionInfo.k0rdentName }}} system, such as projectsveltos, which is a component of {{{ docsVersionInfo.k0rdentName }}} State Manager (KSM, see below)) as well as the k0smotron subsystem, which enables creation and lifecycle management of managed clusters that use Kubernetes-hosted control planes (such as control planes as pods):

```bash
kubectl get providertemplate -n kcm-system   # list providertemplate objects in the kcm-system namespace
```

You should see output similar to:

```console { .no-copy }
NAME                                   VALID
cluster-api-{{{ extra.docsVersionInfo.providerVersions.dashVersions.clusterApi }}}                                true
cluster-api-provider-aws-{{{ docsVersionInfo.providerVersions.dashVersions.clusterApiProviderAws }}}                   true
cluster-api-provider-azure-{{{ docsVersionInfo.providerVersions.dashVersions.clusterApiProviderAzure }}}                 true
cluster-api-provider-docker-{{{ docsVersionInfo.providerVersions.dashVersions.clusterApiProviderDocker }}}                true
cluster-api-provider-gcp-{{{ docsVersionInfo.providerVersions.dashVersions.clusterApiProviderGcp }}}                   true
cluster-api-provider-infoblox-{{{ docsVersionInfo.providerVersions.dashVersions.clusterApiProviderInfoblox }}}              true
cluster-api-provider-ipam-{{{ docsVersionInfo.providerVersions.dashVersions.clusterApiProviderIpam }}}                  true
cluster-api-provider-k0sproject-k0smotron-{{{ docsVersionInfo.providerVersions.dashVersions.k0smotron }}}  true
cluster-api-provider-openstack-{{{ docsVersionInfo.providerVersions.dashVersions.clusterApiProviderOpenstack }}}             true
cluster-api-provider-vsphere-{{{ docsVersionInfo.providerVersions.dashVersions.clusterApiProviderVsphere }}}               true
kcm-{{{ docsVersionInfo.k0rdentVersion }}}                                         true
kcm-regional-{{{ docsVersionInfo.providerVersions.dashVersions.regional }}}                               true
projectsveltos-{{{ docsVersionInfo.providerVersions.dashVersions.sveltosProvider }}}                              true
```

## Verify that KCM ClusterTemplate objects are available

CAPI also requires control plane and bootstrap (worker node) providers to construct and/or manage different Kubernetes cluster distros and variants. Again, these providers are delivered and referenced within {{{ docsVersionInfo.k0rdentName }}} using templates, instantiated in the management cluster as `ClusterTemplate` objects. Before continuing, verify that default `ClusterTemplate` objects are installed and valid:

```bash
kubectl get clustertemplate -n kcm-system   # list clustertemplate objects in the kcm-system namespace
```

You should see output similar to:

```console { .no-copy }
NAME                             VALID
adopted-cluster-{{{ docsVersionInfo.providerVersions.dashVersions.adoptedCluster }}}            true
aws-eks-{{{ extra.docsVersionInfo.providerVersions.dashVersions.awsEksCluster }}}                   true
aws-hosted-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.awsHostedCpCluster }}}             true
aws-standalone-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.awsStandaloneCpCluster }}}         true
azure-aks-{{{ extra.docsVersionInfo.providerVersions.dashVersions.azureAksCluster }}}                  true
azure-hosted-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.azureHostedCpCluster }}}           true
azure-standalone-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.azureStandaloneCpCluster }}}       true
docker-hosted-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.azureHostedCpCluster }}}          true
gcp-gke-{{{ extra.docsVersionInfo.providerVersions.dashVersions.awsEksCluster }}}                   true
gcp-hosted-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.awsHostedCpCluster }}}             true
gcp-standalone-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.awsStandaloneCpCluster }}}         true
openstack-hosted-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.openstackStandaloneCpCluster }}}       true
openstack-standalone-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.openstackStandaloneCpCluster }}}   true
remote-cluster-{{{ extra.docsVersionInfo.providerVersions.dashVersions.remoteCluster }}}            true
vsphere-hosted-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.vsphereHostedCpCluster }}}         true
vsphere-standalone-cp-{{{ extra.docsVersionInfo.providerVersions.dashVersions.vsphereStandaloneCpCluster }}}     true
```

## Next steps

Your QuickStart management node is now complete, and {{{ docsVersionInfo.k0rdentName }}} is installed and operational. Next, it's time to select [AWS](quickstart-2-aws.md), [Azure](quickstart-2-azure.md), [GCP](quickstart-2-gcp.md), [Remote SSH Servers](quickstart-2-remote.md) or [KubeVirt](quickstart-2-kubevirt.md) as an environment for hosting managed clusters.
