# Upgrading to {{{ docsVersionInfo.k0rdentName}}} v1.1.1

## API versions and upgrading from pre-1.0.0 versions

Because of the change from `v1alpha1` to `v1beta1`, clusters running k0rdent versions older than v1.0.0 cannot be upgraded directly to v1.1.1. First follow the [directions](index.md) to [upgrade to v1.0.0](upgrade-to-1-0-0.md), and then perform a second upgrade to v1.1.1.

## Upgrade k0rdent Observability and FinOps (KOF)

After upgrading KOF to v1.1.1, please run:

  ```bash
  kubectl apply --server-side --force-conflicts \
    -f https://github.com/grafana/grafana-operator/releases/download/v5.18.0/crds.yaml
  ```

Also run the same for each regional cluster:

  ```bash
  kubectl get secret -n kcm-system $REGIONAL_CLUSTER_NAME-kubeconfig \
    -o=jsonpath={.data.value} | base64 -d > regional-kubeconfig

  KUBECONFIG=regional-kubeconfig kubectl apply --server-side --force-conflicts \
    -f https://github.com/grafana/grafana-operator/releases/download/v5.18.0/crds.yaml
  ```

These steps are required by `grafana-operator`, as noted in its [release notes](https://github.com/grafana/grafana-operator/releases/tag/v5.18.0).
