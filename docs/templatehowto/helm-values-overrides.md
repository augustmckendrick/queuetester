# Helm Values Overrides

This document describes all Helm values that are automatically configured when deploying a cluster or a provider.
To effectively use these values, the `ClusterTemplate`'s or `ProviderTemplate`'s Helm chart must be designed to consume them.
For complete examples of cluster and provider templates that consume these values, refer to the
[templates](https://github.com/k0rdent/kcm/tree/main/templates) in the `k0rdent/kcm` repository.

## `global`

k0rdent supports several global configurations options that manages global values for cluster and provider templates:

1. [Global Registry Configuration](../appendix/appendix-extend-mgmt.md#configuring-a-custom-oci-registry-for-kcm-components)
1. [Custom k0s URL Configuration](../appendix/appendix-extend-mgmt.md#configuring-a-global-k0s-url)
1. [Proxy Configuration](../appendix/proxy.md)
1. [Configuring Automatic Provider Reload Annotations](../appendix/appendix-extend-mgmt.md#configuring-automatic-provider-reload-annotations)

When configured, the following global values are automatically injected into all cluster and provider templates.
These values can be used to configure the Helm charts of the templates and ensure consistent configuration across
all clusters and providers.

Provider values overrides:

| Path                            | Description                                                                |
|---------------------------------|----------------------------------------------------------------------------|
| `global.registry`               | Global registry URL                                                        |
| `global.imagePullSecrets`       | Global array of image pull secrets to pull images from private registries  |
| `global.proxy`                  | Global proxy configuration                                                 |
| `global.enableProvidersReload`  | Global boolean flag to enable automatic providers reload                   |

Cluster values overrides:

| Path                              | Description                                                |
|-----------------------------------|------------------------------------------------------------|
| `global.registry`                 | Global registry URL                                        |
| `global.k0sURL`                   | Global k0s binary download URL                             |
| `global.registryCertSecret`       | Name of the Secret containing the registry TLS certificate |
| `global.k0sURLCertSecret`         | Name of the Secret containing the k0s URL TLS certificate  |
| `global.registryCredentialSecret` | Name of the Secret containing registry pull credentials    |

#### Example

Refer to the [templates](https://github.com/k0rdent/kcm/tree/main/templates) in the `k0rdent/kcm` repository
for examples of how to use global values in cluster and provider templates.

---

## `clusterIdentity`

A reference to the cluster identity resource containing credentials used to access the infrastructure provider.

Always set. Populated from the `Credential` object's `spec.identityRef` associated with the `ClusterDeployment`.

| Path                         | Description                                     |
|------------------------------|-------------------------------------------------|
| `clusterIdentity.apiVersion` | APIVersion of the credential identity reference |
| `clusterIdentity.kind`       | Kind of the credential identity reference       |
| `clusterIdentity.name`       | Name of the credential identity reference       |
| `clusterIdentity.namespace`  | Namespace of the credential identity reference  |

The `clusterIdentity` values must be passed to infrastructure objects. The exact way to use the `clusterIdentity`
values in a cluster template depends on the provider (see the provider documentation for details).

#### Example

##### Values

```yaml
clusterIdentity:
  apiVersion: v1
  kind: Secret
  name: my-credential-secret
  namespace: kcm-system
```

##### Usage (OpenStack)

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: OpenStackCluster
...
spec:
  identityRef:
    name: {{ .Values.clusterIdentity.name  | quote }}
```

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: OpenStackMachineTemplate
...
spec:
  template:
    spec:
      identityRef:
        name: {{ .Values.clusterIdentity.name  | quote }}
```

---

## `clusterLabels`

Set only if `clusterLabels` is **not** already defined in the user-provided `spec.config` values.
Defaults to the `ClusterDeployment` object's own labels.

| Path            | Description                                     |
|-----------------|-------------------------------------------------|
| `clusterLabels` | Labels to be applied to the CAPI cluster object |

#### Example

##### Values

```yaml
clusterLabels:
  k0rdent: demo
```

##### Usage

```yaml
apiVersion: cluster.x-k8s.io/v1beta2
kind: Cluster
metadata:
  {{- if .Values.clusterLabels }}
  labels: {{- toYaml .Values.clusterLabels | nindent 4 }}
  {{- end }}
```

---

## `auth`

See details in [Identity and Authorization Management](../admin/clusters/cluster-iam-setup.md).

Set only when a `ClusterAuthentication` object is referenced in the `ClusterDeployment` spec and
its `spec.authenticationConfiguration` is non-nil. The `auth.configWithAnon` field is additionally set to `true`
only if anonymous authentication is explicitly configured.


| Path                     | Description                                                                                       |
|--------------------------|---------------------------------------------------------------------------------------------------|
| `auth.configSecret.name` | Name of the automatically generated authentication configuration Secret (`<cd-name>-auth-config`) |
| `auth.configSecret.key`  | Key within the Secret containing the authentication config                                        |
| `auth.configSecret.hash` | Hash of the authentication configuration content (for change detection)                           |
| `auth.configWithAnon`    | Boolean indicating anonymous authentication is configured                                         |

#### Example

##### Values

```yaml
auth:
  configSecret:
    name: my-clusterdeployment-auth-config
    key: config
    hash: 1234567890abcdef
  configWithAnon: true
```

##### Usage

```yaml
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: K0sControlPlane
spec:
  k0sConfigSpec:
    {{- if .Values.auth.configSecret.name }}
    files:
      - contentFrom:
          secretRef:
            name: {{ .Values.auth.configSecret.name  | quote }}
            key: {{ default "config" .Values.auth.configSecret.key  | quote }}
        permissions: "0644"
        {{- if .Values.auth.configSecret.hash }}
        path: /var/lib/k0s/auth/config-{{ .Values.auth.configSecret.hash }}.yaml
        {{- else }}
        path: /var/lib/k0s/auth/config.yaml
        {{- end }}
    {{- end }}
    k0s:
      spec:
        api:
          extraArgs:
            {{- if .Values.auth.configSecret.name }}
            {{- if .Values.auth.configSecret.hash }}
            authentication-config: "/var/lib/k0s/auth/config-{{ .Values.auth.configSecret.hash }}.yaml"
            {{- else }}
            authentication-config: /var/lib/k0s/auth/config.yaml
            {{- end }}
            {{- end }}
```

---

## `audit`

See details in [Enabling Audit Logging](../admin/clusters/cluster-audit-policy.md).

Set only when a `ClusterAuditPolicy` object is referenced in the `ClusterDeployment` `spec.auditPolicy`.


| Path                     | Description                                                                                              |
|--------------------------|----------------------------------------------------------------------------------------------------------|
| `audit.policyRef.name`   | Name of the automatically generated ConfigMap with audit policy configuration (`<cd-name>-audit-policy`) |
| `audit.policyRef.key`    | Key within the ConfigMap containing the audit policy config                                              |
| `audit.policyRef.hash`   | Hash of the audit policy content (for change detection)                                                  |

#### Example

##### Values

```yaml
audit:
  policyRef:
    name: my-clusterdeployment-audit-policy
    key: policy
    hash: 1234567890abcdef
```

##### Usage

```yaml
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: K0sControlPlane
spec:
  k0sConfigSpec:
    {{- if .Values.audit.policyRef.name }}
    files:
      - contentFrom:
          configMapRef:
            name: {{ .Values.audit.policyRef.name  | quote }}
            key: {{ default "policy" .Values.audit.policyRef.key  | quote }}
        permissions: "0644"
        {{- if .Values.audit.policyRef.hash }}
        path: /var/lib/k0s/audit/policy-{{ .Values.audit.policyRef.hash }}.yaml
        {{- else }}
        path: /var/lib/k0s/audit/policy.yaml
        {{- end }}
    {{- end }}
    k0s:
      spec:
        api:
          extraArgs:
            {{- if .Values.audit.policyRef.name }}
            {{- if .Values.audit.policyRef.hash }}
            audit-policy-file: "/var/lib/k0s/audit/policy-{{ .Values.audit.policyRef.hash }}.yaml"
            {{- else }}
            audit-policy-file: "/var/lib/k0s/audit/policy.yaml"
            {{- end }}
            {{- end }}
```
