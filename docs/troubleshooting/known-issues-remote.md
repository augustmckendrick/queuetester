# Troubleshooting

## Steps to Debug Remote Cluster Deployments

1. Check the `ClusterDeployment` status condition on the management cluster:

    ```bash
    kubectl -n $CLUSTER_NAMESPACE get clusterdeployment.k0rdent.mirantis.com $CLUSTER_NAME -o=jsonpath='{.status.conditions[?(@.type=="Ready")]}' | jq
    ```

1. Check the `RemoteMachine` status condition on the management or regional cluster:

    ```bash
    kubectl -n $CLUSTER_NAMESPACE get remotemachine $CLUSTER_NAME -o=jsonpath='{.status.conditions[?(@.type=="Ready")]}' | jq
    ```

1. In case of worker provisioning issues, check the logs of the k0smotron infrastructure controller pod on
the management or regional cluster:

    ```bash
    kubectl -n $SYSTEM_NAMESPACE logs -l k0smotron-provider=infrastructure --tail=-1 | grep "fail\|error"
    ```

1. If needed, SSH into the VM to check system or k0s logs:

    For k0s logs:

    ```bash
    sudo journalctl -u k0sworker
    ```

    For container logs, see the `/var/log/containers` directory. For more information, see [k0s troubleshooting](https://docs.k0sproject.io/v1.34.3+k0s.0/troubleshooting/logs/).


# Known Issues

## The ClusterDeployment provisioning is stuck with `Control plane not yet initialized` status

Ensure that all the prerequisites for the remote cluster deployment have been met, especially the following:

* When using the LoadBalancer k0smotron service type, the Cloud Controller Manager must be installed and working on
the management or regional cluster (when the cluster is deployed in a region).

    To troubleshoot LoadBalancer provisioning, check the following on the management or regional cluster:

    ```bash
    kubectl -n $CLUSTER_NAMESPACE get services kmc-$CLUSTER_NAME-lb
    ```

    If the service is stuck in `Pending` state, ensure that the Cloud Controller Manager is installed and properly configured.
    Check the logs of the Cloud Controller Manager for any issues.

* The storage solution must be configured and working properly.

    To troubleshoot storage provisioning, check the following on the management or regional cluster:

    ```bash
    kubectl -n $CLUSTER_NAMESPACE get pvc -l cluster.x-k8s.io/cluster-name=$CLUSTER_NAME
    ```

    If the PVCs are stuck in `Pending` state, ensure that the storage solution is properly configured and working.
    Check the logs of the storage provisioner for any issues.


## RemoteMachine error: `open /etc/k0s.token: invalid argument: failed to stat parent directory`

This issue typically occurs when using an unsupported target operating system (e.g., Ubuntu 26.04). Ensure you
are running only supported operating systems: Ubuntu 20.04, 22.04, or 24.04. For details, see
[k0s System Requirements](https://docs.k0sproject.io/v1.35.4+k0s.0/system-requirements/#host-operating-system).


## Control plane pods are in CrashLoopBackOff state with `no matches for kind "Chart" in group "helm.k0sproject.io"` error

Ensure you are using k0s version >= `v1.35.4+k0s.0`. This version contains multiple fixes related to Helm.

When using the default `remote-cluster` ClusterTemplate, you can configure the k0s version by setting
the `spec.config.k0s.version` field in the `ClusterDeployment` object. For example:

```yaml
config:
  k0s:
    version: v1.35.4+k0s.0
```

## Control plane pods are in CrashLoopBackOff: `too many open files` error

This issue typically occurs when the `fs.inotify` limits are set to a low value on the cluster that hosts control plane
components (either management or regional).

Ensure that the `fs.inotify` limits are properly configured. For example, when your management or regional cluster
is running k0s, do the following on your control plane nodes:

1. Add the following lines to a new `*.conf` file (e.g., `inotify-watch.conf`) under the `/etc/sysctl.d/` directory:

    ```bash
    fs.inotify.max_user_watches=524288
    fs.inotify.max_user_instances=512
    ```

1. Apply the changes:

    ```bash
    sudo sysctl -p --system
    ```

1. If you have already started a child cluster, restart the `ClusterDeployment`'s control plane pods. Run the following command using
the kubeconfig for the management cluster (or the regional cluster if the cluster was deployed in a region).
Replace `$CLUSTER_NAMESPACE` and `$CLUSTER_NAME` with the namespace and name of your `ClusterDeployment`:

    ```bash
    kubectl -n $CLUSTER_NAMESPACE delete pods -l cluster.x-k8s.io/cluster-name=$CLUSTER_NAME -l app.kubernetes.io/component=control-plane
    ```

Related to: [New hosted control plane pods are in CrashLoopBackOff](https://docs.k0smotron.io/stable/troubleshooting/#new-hosted-control-plane-pods-are-in-crashloopbackoff).
