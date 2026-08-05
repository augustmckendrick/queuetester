# Upgrade to v1.10.0

## Cgroup v1 Deprecation

Starting with k0s `v1.35.4+k0s.0`, cgroup v1 is no longer supported. As a result, pre-flight checks will fail during
cluster deployment on systems that still use cgroup v1.

If you need to run clusters with k0s `v1.35.4+k0s.0` or later on a system with cgroup v1, your cluster template must be
configured to bypass pre-flight checks. Add the `--ignore-pre-flight-checks` flag and disable the cgroup v1 failure check.

For hosted clusters:

```yaml
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: K0smotronControlPlane
spec:
  k0sConfig:
    spec:
      workerProfiles:
        - name: default
          values:
            failCgroupV1: false
```

For standalone clusters:

> WARNING: The `--ignore-pre-flight-checks` flag is currently not supported for control plane nodes in
> standalone clusters with k0s `v1.35.4+k0s.0`. 
> Related issue: [--ignore-pre-flight-checks flag NOT exposed in the k0s <role> install commands](https://github.com/k0sproject/k0s/issues/7717).
> This limitation is expected to be addressed in a future k0s release.

```yaml
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: K0sControlPlane
spec:
  k0sConfigSpec:
    args:
      - --ignore-pre-flight-checks
    k0s:
      spec:
        workerProfiles:
          - name: default
            values:
              failCgroupV1: false
```

For more information, see the official k0s documentation: [Control Groups (cgroups)](https://docs.k0sproject.io/stable/external-runtime-deps/?h=cgroup#control-groups-cgroups).
