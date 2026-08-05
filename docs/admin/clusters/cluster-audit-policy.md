# Enabling Audit Logging

An audit log is an append-only, time-ordered, tamper-evident record of who did what, to which resource, when,
from where, and with what result, across a system's control plane and the data plane where it touches controlled
or regulated resources (credentials, secrets, regulated data).

{{{ docsVersionInfo.k0rdentName }}} provides a consistent mechanism for managing cluster audit policy through
the `ClusterAuditPolicy` resource.

By separating audit policy from cluster templates and automating its propagation,
{{{ docsVersionInfo.k0rdentName }}} removes error-prone manual steps and provides a repeatable, auditable way
to enforce audit policy across a fleet of clusters.

## ClusterAuditPolicy Resource

{{{ docsVersionInfo.k0rdentName }}} supports configuring audit policy for child clusters through
the `ClusterAuditPolicy` custom resource. Each `ClusterAuditPolicy` resource can be referenced by one or
more `ClusterDeployment` objects.

The resource contains a `Policy` object from the `audit.k8s.io/v1` API group with rules defining which events are
recorded and what data they include. For details, see the official Kubernetes
[Auditing guide](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy) and
the [Policy configuration reference](https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/#audit-k8s-io-v1-Policy)
for supported `Policy` fields.

### Examples

You can use a minimal `ClusterAuditPolicy` to log all requests at the Metadata level:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ClusterAuditPolicy
metadata:
  name: default
  namespace: my-namespace
spec:
  policy:
    rules:
      - level: Metadata
```

<details>
<summary>Audit Policy Example</summary>

If you are creating your own audit policy, you can use the following configuration as a starting point:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ClusterAuditPolicy
metadata:
  name: default
  namespace: my-namespace
spec:
  policy:
    rules:
      # The following requests were manually identified as high-volume and low-risk,
      # so drop them.
      - level: None
        users: ["system:kube-proxy"]
        verbs: ["watch"]
        resources:
          - group: "" # core
            resources: ["endpoints", "services", "services/status"]
      - level: None
        userGroups: ["system:nodes"]
        verbs: ["get"]
        resources:
          - group: "" # core
            resources: ["nodes", "nodes/status"]
      - level: None
        users:
          - system:kube-controller-manager
          - system:cloud-controller-manager
          - system:kube-scheduler
          - system:serviceaccount:kube-system:endpoint-controller
        verbs: ["get", "update"]
        namespaces: ["kube-system"]
        resources:
          - group: "" # core
            resources: ["endpoints"]
      - level: None
        users: ["system:apiserver"]
        verbs: ["get"]
        resources:
          - group: "" # core
            resources: ["namespaces", "namespaces/status", "namespaces/finalize"]
      - level: None
        users: ["cluster-autoscaler"]
        verbs: ["get", "update"]
        namespaces: ["kube-system"]
        resources:
          - group: "" # core
            resources: ["configmaps", "endpoints"]
      # Don't log leader election lease updates (high-volume from all controllers).
      - level: None
        verbs: ["get", "update"]
        resources:
          - group: "coordination.k8s.io"
            resources: ["leases"]
      # Don't log HPA fetching metrics.
      - level: None
        users:
          - system:kube-controller-manager
          - system:cloud-controller-manager
        verbs: ["get", "list"]
        resources:
          - group: "metrics.k8s.io"
      # Don't log these read-only URLs.
      - level: None
        nonResourceURLs:
          - /healthz*
          - /version
          - /swagger*
      # Don't log events requests because of performance impact.
      - level: None
        resources:
          - group: "" # core
            resources: ["events"]
      # node and pod status calls from nodes are high-volume and can be large, don't log responses for expected updates from nodes
      - level: Request
        users: ["kubelet", "system:node-problem-detector", "system:serviceaccount:kube-system:node-problem-detector"]
        verbs: ["update","patch"]
        resources:
          - group: "" # core
            resources: ["nodes/status", "pods/status"]
        omitStages:
          - "RequestReceived"
      - level: Request
        userGroups: ["system:nodes"]
        verbs: ["update","patch"]
        resources:
          - group: "" # core
            resources: ["nodes/status", "pods/status"]
        omitStages:
          - "RequestReceived"
      # deletecollection calls can be large, don't log responses for expected namespace deletions
      - level: Request
        users: ["system:serviceaccount:kube-system:namespace-controller"]
        verbs: ["deletecollection"]
        omitStages:
          - "RequestReceived"
      # Secrets, ConfigMaps, TokenRequest and TokenReviews can contain sensitive & binary data,
      # so only log at the Metadata level.
      - level: Metadata
        resources:
          - group: "" # core
            resources: ["secrets", "configmaps", "serviceaccounts/token"]
          - group: authentication.k8s.io
            resources: ["tokenreviews"]
        omitStages:
          - "RequestReceived"
      # Get responses can be large; skip them.
      - level: Request
        verbs: ["get", "list", "watch"]
        resources:
          - group: "admissionregistration.k8s.io"
          - group: "apiextensions.k8s.io"
          - group: "apiregistration.k8s.io"
          - group: "apps"
          - group: "authentication.k8s.io"
          - group: "authorization.k8s.io"
          - group: "autoscaling"
          - group: "batch"
          - group: "certificates.k8s.io"
          - group: "coordination.k8s.io"
          - group: "discovery.k8s.io"
          - group: "extensions"
          - group: "flowcontrol.apiserver.k8s.io"
          - group: "metrics.k8s.io"
          - group: "networking.k8s.io"
          - group: "node.k8s.io"
          - group: "policy"
          - group: "rbac.authorization.k8s.io"
          - group: "scheduling.k8s.io"
          - group: "storage.k8s.io"
          # k0s
          - group: "k0s.k0sproject.io"
          - group: "helm.k0sproject.io"
          - group: "autopilot.k0sproject.io"
        omitStages:
          - "RequestReceived"
      # Default level for known APIs
      - level: RequestResponse
        resources:
          - group: "admissionregistration.k8s.io"
          - group: "apiextensions.k8s.io"
          - group: "apiregistration.k8s.io"
          - group: "apps"
          - group: "authentication.k8s.io"
          - group: "authorization.k8s.io"
          - group: "autoscaling"
          - group: "batch"
          - group: "certificates.k8s.io"
          - group: "coordination.k8s.io"
          - group: "discovery.k8s.io"
          - group: "extensions"
          - group: "flowcontrol.apiserver.k8s.io"
          - group: "metrics.k8s.io"
          - group: "networking.k8s.io"
          - group: "node.k8s.io"
          - group: "policy"
          - group: "rbac.authorization.k8s.io"
          - group: "scheduling.k8s.io"
          - group: "storage.k8s.io"
          # k0s
          - group: "k0s.k0sproject.io"
          - group: "helm.k0sproject.io"
          - group: "autopilot.k0sproject.io"
        omitStages:
          - "RequestReceived"
      # Default level for all other requests.
      - level: Metadata
        omitStages:
          - "RequestReceived"
```

</details>


### Key Fields

* **`spec.policy`** – Contains the full `audit.k8s.io/v1` `Policy` object consumed by the Kubernetes API server. For
all supported options, see the official Kubernetes documentation: [Audit Policy](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy).

## Configuring Audit Policy for ClusterDeployments

To enable audit policy for a cluster, set the `spec.auditPolicy` field to reference an existing `ClusterAuditPolicy`
object in the same namespace:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ClusterDeployment
metadata:
  name: cluster-name
  namespace: my-namespace
spec:
  template: openstack-hosted-cp-1-0-12
  credential: openstack-cluster-identity-cred
  auditPolicy: default
```

## Integration with ClusterTemplates

When audit policy is enabled, {{{ docsVersionInfo.k0rdentName }}} injects the audit policy configuration into the
control plane and manages updates when the configuration changes.

### What k0rdent Generates

When `spec.auditPolicy` is configured and the referenced `ClusterAuditPolicy` exists, the KCM controller performs
the following actions:

1. Generates a `ConfigMap` named `<cluster-deployment-name>-audit-policy` containing the `Policy` configuration.
2. Passes audit policy values to the `HelmRelease` responsible for deploying the cluster control plane:

```yaml
    audit:
      policyRef:
        name: cluster-name-audit-policy
        key: policy
        hash: g8d3f7b8
```

* `audit.policyRef.name` – Name of the `ConfigMap` containing the audit policy configuration.
* `audit.policyRef.key` – Key within the `ConfigMap` where the audit policy is stored.
* `audit.policyRef.hash` – Hash of the configuration content; used to trigger control plane updates when the configuration changes.

### What ClusterTemplates Must Consume

The `ClusterTemplate` must consume these values to configure the API server correctly. Built-in templates already
reference this information.

If you are creating custom `ClusterTemplates`, you must explicitly reference these values. In particular,
the control plane resources (`K0smotronControlPlane` or `K0sControlPlane`) must:

1. Mount the audit policy config map into control plane nodes or pods.
2. Set the API server `--audit-policy-file` flag to the mounted configuration file.

> WARNING:
> Updating `spec.auditPolicy` changes the configuration hash and triggers a rolling recreation of control plane machines.
> For clusters that were initially deployed with a single control plane node, this operation may cause the cluster to
> lose etcd quorum during the rollout, potentially resulting in a cluster outage.
> For mitigation steps and additional details, see [Cluster Control Plane Rollout](update-cluster.md#control-plane-machines-rollout).

Additionally, you can configure the Kubernetes API server audit log backend using the following API server parameters:
`audit-log-path`, `audit-log-maxage`, `audit-log-maxbackup`, `audit-log-maxsize`.
When `audit-log-path` is set to `"-"`, the API server writes audit logs to standard output instead of a file.
In this mode, log rotation and retention are managed externally, and the `audit-log-max*` settings do not apply.

For more information, see the Kubernetes documentation on the [audit log backend](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#log-backend).

Examples of how to consume these values in ClusterTemplates are available in the [templates directory](https://github.com/k0rdent/kcm/tree/main/templates/cluster)
of the official {{ docsVersionInfo.k0rdentName }} repository.

### Example: `K0smotronControlPlane` Audit Policy Configuration

This example shows how a hosted control plane consumes the injected audit policy configuration.

```yaml
spec:
  k0sConfig:
    apiVersion: k0s.k0sproject.io/v1beta1
    kind: ClusterConfig
    metadata:
      name: k0s
    spec:
      mounts:
      {{- if .Values.audit.policyRef.name }}
      - path: {{ include "audit-policy.dir" . }}
        configMap:
          defaultMode: 420
          items:
            - key: {{ .Values.audit.policyRef.key  | quote }}
              path: policy-{{ .Values.audit.policyRef.hash }}.yaml
          name: {{ .Values.audit.policyRef.name  | quote }}
      {{- end }}
      ...
      api:
        extraArgs:
          {{- if .Values.audit.policyRef.name }}
          audit-policy-file: /var/lib/k0s/audit/policy-{{ .Values.audit.policyRef.hash }}.yaml
          audit-log-path: "-"
          {{- end }}
      ...
```

### Example: `K0sControlPlane` Audit Policy Configuration

This example shows the configuration for standalone control plane clusters.

```yaml
spec:
  k0sConfigSpec:
    {{- if .Values.audit.policyRef.name }}
    files:
    - contentFrom:
        configMapRef:
          name: {{ .Values.audit.policyRef.name  | quote }}
          key: {{ default "policy" .Values.audit.policyRef.key  | quote }}
      permissions: "0644"
      path: /var/lib/k0s/audit/policy-{{ .Values.audit.policyRef.hash }}.yaml
    {{- end }}
    ...
    k0s:
      apiVersion: k0s.k0sproject.io/v1beta1
      kind: ClusterConfig
      metadata:
        name: k0s
      spec:
        api:
          extraArgs:
            {{- if .Values.audit.policyRef.name }}
            audit-policy-file: /var/lib/k0s/audit/policy-{{ .Values.audit.policyRef.hash }}.yaml
            {{- if .Values.audit.logPath }}
            audit-log-path: {{ .Values.audit.logPath | quote }}
            {{- end }}
            {{- if and .Values.audit.logPath (ne .Values.audit.logPath "-") }}
            {{- if .Values.audit.logMaxAge }}
            audit-log-maxage: {{ .Values.audit.logMaxAge | quote }}
            {{- end }}
            {{- if .Values.audit.logMaxBackup }}
            audit-log-maxbackup: {{ .Values.audit.logMaxBackup | quote }}
            {{- end }}
            {{- if .Values.audit.logMaxSize }}
            audit-log-maxsize: {{ .Values.audit.logMaxSize | quote }}
            {{- end }}
            {{- end }}
            {{- end }}
      ...
```
