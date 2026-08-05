# Using a Private Secure Registry to deploy {{{ docsVersionInfo.k0rdentName }}}

## Prerequisites

If you are deploying {{{ docsVersionInfo.k0rdentName }}} with registry overrides (see
[Configuring a Custom OCI Registry for KCM components](appendix-extend-mgmt.md#configuring-a-custom-oci-registry-for-kcm-components)),
and your registry endpoint is secured with a certificate signed by an unknown Certificate Authority (CA), you must
ensure that the CA certificate is trusted by your management cluster nodes before deploying {{{ docsVersionInfo.k0rdentName }}}.

To do this, add the CA certificate to the system’s trust store on each management cluster node.

### For Management Clusters Running on k0s

Before starting the k0s controller, do the following:

1. Copy the CA certificate file (e.g., `<PATH_TO_CA_CERT>`) to the system’s trusted certificate directory:

    ```bash
    sudo cp <PATH_TO_CA_CERT> /usr/local/share/ca-certificates/
    ```

2. Update the system’s trusted certificates:

    ```bash
    sudo update-ca-certificates
    ```

3. Proceed to install k0s as usual.

### For Management Clusters Running on Kind

1. Create a Kind configuration file that mounts the CA certificate into the container nodes.
Suppose your CA certificate is located at `<PATH_TO_CA_CERT>` on your host.

    ```yaml
    # kind-config.yaml
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
      - role: control-plane
        extraMounts:
          - hostPath: <PATH_TO_CA_CERT>
            containerPath: /usr/local/share/ca-certificates/registry-ca.crt
    ```

2. Create the Kind cluster using the configuration:

    ```bash
    kind create cluster --config kind-config.yaml --name <KIND_CLUSTER_NAME>
    ```

3. Run the following command to update the trust store inside the container. Repeat this command for each node in the
Kind cluster, replacing `<KIND_CLUSTER_NAME>-control-plane` with the name of the Docker container representing that
node:

    ```bash
    docker exec <KIND_CLUSTER_NAME>-control-plane update-ca-certificates
    ```
