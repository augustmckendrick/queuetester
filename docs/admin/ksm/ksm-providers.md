# KSM Providers

{{{ docsVersionInfo.k0rdentName }}} provides API to make underlying CD software pluggable and leverage it for KSM purposes.
There are two crucial API types: `StateManagementProvider` and `ServiceSet`.

## StateManagementProvider

The `StateManagementProvider` ensures that `ServiceSet` objects produced by {{{ docsVersionInfo.k0rdentName }}} controllers
are reconciled and transformed into provider-specific objects. The controller validates that all required components
([adapter](#adapter), [provisioner](#provisioner), and [CRDs](#provisioner-crds)) are ready using user-defined CEL expressions.

### Key Features

- **Provider Validation**: Validates that adapter, provisioner, and CRDs are ready before allowing service deployments
- **CEL-based Readiness Rules**: Flexible readiness checks using Common Expression Language (CEL)
- **Label-based ServiceSet Selection**: Uses label selectors to match ServiceSet objects
- **Suspend Capability**: Can temporarily suspend provider reconciliation
- **RBAC Management**: Automatically manages required RBAC permissions

It is also possible to [Build Your Own KSM Provider](ksm-byo-provider.md)

Here is an example of built-in `StateManagementProvider` object:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: StateManagementProvider
metadata:
  name: ksm-projectsveltos
spec:
  adapter:
    apiVersion: apps/v1
    kind: Deployment
    name: kcm-controller-manager
    namespace: kcm-system
    readinessRule: |-
      self.status.availableReplicas == self.status.replicas &&
      self.status.availableReplicas == self.status.updatedReplicas &&
      self.status.availableReplicas == self.status.readyReplicas
  provisioner:
  - apiVersion: apps/v1
    kind: Deployment
    name: addon-controller
    namespace: projectsveltos
    readinessRule: |-
      self.status.availableReplicas == self.status.replicas &&
      self.status.availableReplicas == self.status.updatedReplicas &&
      self.status.availableReplicas == self.status.readyReplicas
  provisionerCRDs:
  - group: config.projectsveltos.io
    resources:
    - profiles
    - clustersummaries
    version: v1beta1
  selector:
    matchLabels:
      ksm.k0rdent.mirantis.com/adapter: kcm-controller-manager
  suspend: false
status:
  conditions:
  - lastTransitionTime: "2025-08-26T10:58:26Z"
    message: Successfully ensured RBAC
    observedGeneration: 1
    reason: RBACEnsuredSuccessfully
    status: "True"
    type: RBACReady
  - lastTransitionTime: "2025-08-27T21:29:49Z"
    message: Successfully ensured adapter
    observedGeneration: 1
    reason: AdapterEnsuredSuccessfully
    status: "True"
    type: AdapterReady
  - lastTransitionTime: "2025-08-26T10:59:37Z"
    message: Successfully ensured provisioner
    observedGeneration: 1
    reason: ProvisionerEnsuredSuccessfully
    status: "True"
    type: ProvisionerReady
  - lastTransitionTime: "2025-08-26T10:59:17Z"
    message: Successfully ensured provisioner CRDs
    observedGeneration: 1
    reason: ProvisionerCRDsEnsuredSuccessfully
    status: "True"
  ready: true
```

### Adapter

This is some workload deployed in management cluster which will reconcile `ServiceSet` objects. Built-in adapter comes bundled as a part of `kcm-controller-manager` binary.
Adapter is expected to convert `ServiceSpec` object being reconciled to provider-specific object and collect status of defined services.

### Provisioner

This is a set of or a single workload which will reconcile provider-specific objects produced by the adapter. For built-in provider it's a `addon-controller` provided by ProjectSveltos.

### Provisioner CRDs

This is a set of CRDs which are required by adapter and provisioners to operate normally.

The `.spec.provisionerCRDs` field defines the expected CRDs:

```yaml
provisionerCRDs:
  - group: config.projectsveltos.io
    version: v1beta1
    resources:
      - profiles
      - clusterprofiles
      - clustersummaries
```

**Fields:**
- `group`: API group of the CRD
- `version`: API version of the CRD
- `resources`: Array of resource names that must exist

> NOTE: `StateManagementProvider` controller does not deploy any workloads or CRDs to the management cluster.
> The only goal of this controller is to ensure that all components, required to deploy services, exist and
> operate normally.

## StateManagementProvider Specification

### Required Fields

#### `.spec.selector`
Label selector for matching `ServiceSet` objects. Only ServiceSets with matching labels will be handled by this provider.

```yaml
spec:
  selector:
    matchLabels:
      ksm.k0rdent.mirantis.com/adapter: kcm-controller-manager
```

This selector ensures only ServiceSets created by the kcm-controller-manager are processed by this provider.

#### `.spec.adapter`
Defines the adapter workload and its readiness criteria.

**Fields:**
- `apiVersion`: API version of the adapter resource (e.g., `apps/v1`)
- `kind`: Kind of the adapter resource (e.g., `Deployment`, `StatefulSet`)
- `name`: Name of the adapter resource
- `namespace`: Namespace where the adapter is deployed
- `readinessRule`: CEL expression to evaluate adapter readiness

**Example:**
```yaml
adapter:
  apiVersion: apps/v1
  kind: Deployment
  name: kcm-controller-manager
  namespace: kcm-system
  readinessRule: |-
    self.status.availableReplicas == self.status.replicas &&
    self.status.availableReplicas == self.status.updatedReplicas &&
    self.status.availableReplicas == self.status.readyReplicas
```

#### `.spec.provisioner[]`
Array of provisioner workloads and their readiness criteria. Can define multiple provisioners if needed.

**Fields (same as adapter):**
- `apiVersion`
- `kind`
- `name`
- `namespace`
- `readinessRule`

**Example:**
```yaml
provisioner:
  - apiVersion: apps/v1
    kind: Deployment
    name: addon-controller
    namespace: projectsveltos
    readinessRule: |-
      self.status.availableReplicas == self.status.replicas &&
      self.status.availableReplicas == self.status.updatedReplicas
```

#### `.spec.provisionerCRDs[]`
Array of required CRDs. The controller verifies these CRDs exist before marking the provider as ready.

**Fields:**
- `group`: API group (e.g., `config.projectsveltos.io`)
- `version`: API version (e.g., `v1beta1`)
- `resources`: Array of resource names (e.g., `["profiles", "clusterprofiles"]`)

### Optional Fields

#### `.spec.suspend`
Boolean flag to suspend provider reconciliation. When `true`, it will be indicator for adapter that `ServiceSet` objects referring given `StateManagementProvider` should be skipped.

**Default:** `false`

**Use cases:**
- Maintenance windows
- Troubleshooting
- Preventing changes during critical operations

```yaml
spec:
  suspend: true
```

## StateManagementProvider Status

The status reflects the current state of the provider and its components.

### Status Fields

#### `.status.ready`
Boolean indicating overall provider readiness. `true` when all conditions are met.

#### `.status.conditions[]`
Array of conditions describing component states:

**Condition Types:**

1. **`RBACReady`**
   - **Purpose**: RBAC permissions are configured
     - **Reasons**: `RBACEnsuredSuccessfully`, `RBACNotReady`, `FailedToGetGVKForAdapter`, `FailedToGetGVKForProvisioner`, `FailedToEnsureClusterRole`, `FailedToEnsureClusterRoleBinding`, `FailedToEnsureServiceAccount`, `RBACUnknown`

2. **`AdapterReady`**
   - **Purpose**: Adapter workload is ready
   - **Reasons**: `AdapterEnsuredSuccessfully`, `AdapterUnknown`, `AdapterNotReady`

3. **`ProvisionerReady`**
   - **Purpose**: All provisioner workloads are ready
   - **Reasons**: `ProvisionerEnsuredSuccessfully`, `ProvisionerUnknown`, `ProvisionerNotReady`

4. **`ProvisionerCRDsReady`**
   - **Purpose**: All required CRDs are installed
   - **Reasons**: `ProvisionerCRDsEnsuredSuccessfully`, `ProvisionerCRDsUnknown`, `ProvisionerCRDsNotReady`

**Condition Fields:**
- `type`: Condition type (see above)
- `status`: `"True"` or `"False"`
- `reason`: Short reason code
- `message`: Human-readable message
- `lastTransitionTime`: Timestamp of last status change
- `observedGeneration`: Generation number when condition was set

### Example Status

```yaml
status:
  ready: true
  conditions:
    - type: RBACReady
      status: "True"
      reason: RBACEnsuredSuccessfully
      message: Successfully ensured RBAC
      lastTransitionTime: "2025-08-26T10:58:26Z"
      observedGeneration: 1
    - type: AdapterReady
      status: "True"
      reason: AdapterEnsuredSuccessfully
      message: Successfully ensured adapter
      lastTransitionTime: "2025-08-27T21:29:49Z"
      observedGeneration: 1
    - type: ProvisionerReady
      status: "True"
      reason: ProvisionerEnsuredSuccessfully
      message: Successfully ensured provisioner
      lastTransitionTime: "2025-08-26T10:59:37Z"
      observedGeneration: 1
    - type: ProvisionerCRDsReady
      status: "True"
      reason: ProvisionerCRDsEnsuredSuccessfully
      message: Successfully ensured provisioner CRDs
      lastTransitionTime: "2025-08-26T10:59:17Z"
      observedGeneration: 1
```

### Monitoring Provider Status

Check provider status:
```bash
kubectl get statemanagementprovider -A
```

Short name available:
```bash
kubectl get smp -A
```

Detailed status:
```bash
kubectl describe statemanagementprovider ksm-projectsveltos
```

### Troubleshooting

If `.status.ready` is `false`, check individual conditions:

**RBAC Issues:**
```bash
kubectl get statemanagementprovider <name> -o jsonpath='{.status.conditions[?(@.type=="RBACReady")]}'
```

**Adapter Issues:**
```bash
# Check if adapter exists
kubectl get deployment kcm-controller-manager -n kcm-system

# Check adapter readiness
kubectl describe deployment kcm-controller-manager -n kcm-system
```

**Provisioner Issues:**
```bash
# Check if provisioner exists
kubectl get deployment addon-controller -n projectsveltos

# Check provisioner logs
kubectl logs -n projectsveltos deployment/addon-controller
```

**CRD Issues:**
```bash
# List expected CRDs
kubectl get crd | grep config.projectsveltos.io
```

## CEL Readiness Rules

Readiness rules use [CEL (Common Expression Language)](https://kubernetes.io/docs/reference/using-api/cel/) to evaluate resource status.

### Common Patterns

**Deployment Readiness:**
```cel
self.status.availableReplicas == self.status.replicas &&
self.status.availableReplicas == self.status.updatedReplicas &&
self.status.availableReplicas == self.status.readyReplicas
```

**StatefulSet Readiness:**
```cel
self.status.readyReplicas == self.status.replicas &&
self.status.currentRevision == self.status.updateRevision
```

**DaemonSet Readiness:**
```cel
self.status.numberReady == self.status.desiredNumberScheduled &&
self.status.numberAvailable == self.status.desiredNumberScheduled
```

**Pod Readiness:**
```cel
self.status.phase == "Running" &&
self.status.conditions.exists(c, c.type == "Ready" && c.status == "True")
```

### Custom Readiness Examples

**Check minimum replicas:**
```cel
self.status.availableReplicas >= 2
```

**Check specific generation:**
```cel
self.status.observedGeneration == self.metadata.generation
```

**Combined conditions:**
```cel
self.status.replicas > 0 &&
self.status.availableReplicas == self.status.replicas &&
!has(self.status.conditions) ||
self.status.conditions.exists(c, c.type == "Available" && c.status == "True")
```

## Creating Custom Providers

To integrate a custom CD solution:

1. **Deploy Your CD Solution** to the management cluster
2. **Create Adapter** that watches ServiceSet objects and creates provider-specific resources
3. **Register CRDs** used by your provider
4. **Create StateManagementProvider** object with appropriate selectors and readiness rules
5. **Define provider name** in ClusterDeployment/MultiClusterService `.spec.serviceSpec.provider.name` to use your provider

**Example Custom Provider:**

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: StateManagementProvider
metadata:
  name: my-custom-provider
spec:
  adapter:
    apiVersion: apps/v1
    kind: Deployment
    name: my-adapter-controller
    namespace: my-cd-system
    readinessRule: |-
      self.status.availableReplicas > 0
  provisioner:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-cd-controller
      namespace: my-cd-system
      readinessRule: |-
        self.status.readyReplicas == self.status.replicas
  provisionerCRDs:
    - group: cd.example.com
      version: v1alpha1
      resources:
        - applications
        - deployments
  selector:
    matchLabels:
      ksm.k0rdent.mirantis.com/adapter: my-adapter-controller
  suspend: false
```

## ServiceSet

`ServiceSet` acts as an intermediary between {{{ docsVersionInfo.k0rdentName }}} API (ClusterDeployment/MultiClusterService) and provider-specific objects. It represents the desired state of services to be deployed on a specific cluster.

### Purpose

- **Abstraction Layer**: Decouples service definitions from provider-specific implementations
- **Per-Cluster State**: Each ServiceSet targets a single cluster
- **Provider Translation**: Adapters watch ServiceSets and create provider-specific resources
- **Status Aggregation**: Collects deployment status from provider objects

### ServiceSet Lifecycle

1. **Creation**: ClusterDeployment or MultiClusterService controllers create ServiceSets
2. **Label Matching**: StateManagementProvider uses label selectors to identify relevant ServiceSets
3. **Adapter Processing**: Adapter (part of provider) reconciles ServiceSet and creates provider objects
4. **Status Updates**: Adapter updates ServiceSet status with deployment results
5. **Deletion**: When parent object is deleted or cluster no longer matches, ServiceSet is removed

### ServiceSet Specification

#### Required Fields

**`.spec.cluster`**
Reference to the target ClusterDeployment name. Format: `<name>`.

**`.spec.provider`**
Provider configuration for service deployment.

**Fields:**
- `name`: Name of the StateManagementProvider
- `config`: Provider-specific configuration (JSON)
- `selfManagement`: Boolean indicating deployment to management cluster (for MCS only)

**`.spec.services[]`**
Array of services to deploy with resolved values.

**Fields:**
- `name`: Service release name
- `namespace`: Service release namespace
- `template`: ServiceTemplate name
- `values`: Merged Helm values (as YAML string)
- `valuesFrom`: Array of ConfigMap/Secret references
- `helmOptions`: Helm installation options

#### Optional Fields

**`.spec.multiClusterService`**
Name of the MultiClusterService that created this ServiceSet (if applicable).

### ServiceSet Status

The status reflects the current deployment state of services.

#### Status Fields

**`.status.deployed`**
Boolean indicating whether services have been deployed. Default: `false`.

**`.status.provider`**
Provider state information:
- `ready`: Boolean - provider is ready to handle services
- `suspended`: Boolean - provider is suspended, omitted if `false`

**`.status.services[]`**
Array of service deployment states, one entry per service.

**ServiceState Fields:**
- `type`: Service deployment type - `Helm`, `Kustomize`, or `Resource`
- `name`: Service name
- `namespace`: Service namespace
- `template`: ServiceTemplate name used
- `version`: Application version from template
- `state`: Current state - `Deployed`, `Provisioning`, `Failed`, `Pending`, or `Deleting`
- `failureMessage`: Error message if state is `Failed`
- `lastStateTransitionTime`: Timestamp of last state change

**Service States:**
- `Pending`: Service is waiting (e.g., for dependencies)
- `Provisioning`: Service is being deployed
- `Deployed`: Service successfully deployed
- `Failed`: Service deployment failed
- `Deleting`: Service is being removed

**`.status.conditions[]`**
Overall conditions for the ServiceSet.

### Labels and Annotations

#### Required Labels

ServiceSets must have the adapter label matching the provider's selector:

```yaml
metadata:
  labels:
    ksm.k0rdent.mirantis.com/adapter: kcm-controller-manager
```

#### Annotations

**`k0rdent.mirantis.com/service-set-paused`**
Default {{{ docsVersionInfo.k0rdentName }}} provider is ProjectSveltos. {{{ docsVersionInfo.k0rdentName }}} embeds adapter
which respects this annotation. When annotation is set, it will be passed to underlying ProjectSveltos objects - `Profile` or `ClusterProfile`.
ProjectSveltos will respect this annotation and pauses reconciliation of its resources, if the annotation value is `true`.

```yaml
metadata:
  annotations:
    k0rdent.mirantis.com/service-set-paused: "true"
```

### Example: ClusterDeployment to ServiceSet

Here is an example of `ClusterDeployment` object with defined service to be deployed and the `ServiceSet` object produced out of `ClusterDeployment` spec:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ClusterDeployment
metadata:
  name: sample-cluster
  namespace: kcm-system
spec:
  # spec fields related to cluster configuration are omitted
  serviceSpec:
    provider:
      name: kcm-projectsveltos
      config:
        continueOnError: false
        priority: 100
        stopOnConflict: false
        syncMode: Continuous
    services:
      - template: ingress-nginx-4-11-0
        name: managed-ingress
```

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ServiceSet
metadata:
  name: sample-cluster
  namespace: kcm-system
  labels:
    ksm.k0rdent.mirantis.com/adapter: kcm-controller-manager
spec:
  cluster: kcm-system
  provider:
    name: kcm-projectsveltos
    config:
      continueOnError: false
      priority: 100
      stopOnConflict: false
      syncMode: Continuous
  services:
    - template: ingress-nginx-4-11-0
      name: managed-ingress
      namespace: default
status:
  conditions:
    - lastTransitionTime: "2025-08-27T10:30:15Z"
      message: Profile is ready
      observedGeneration: 1
      reason: ServiceSetProfileReady
      status: "True"
      type: ServiceSetProfile
  deployed: true
  provider:
    ready: true
    suspended: false # will be omitted
  services:
    - lastStateTransitionTime: "2025-08-27T10:30:15Z"
      name: managed-ingress
      namespace: default
      state: Deployed
      template: ingress-nginx-4-11-0
      type: Helm
      version: "4.11.0"
```

### Monitoring ServiceSets

List ServiceSets in your cluster:

```bash
kubectl get servicesets -A
```

Check a specific ServiceSet status:

```bash
kubectl get serviceset sample-cluster -n kcm-system -o yaml
```

View service states:

```bash
kubectl get serviceset sample-cluster -n kcm-system -o jsonpath='{.status.services[*].state}'
```

### Troubleshooting ServiceSets

**Service in Failed state:**

Check failure message:
```bash
kubectl get serviceset <name> -n <namespace> -o jsonpath='{.status.services[?(@.state=="Failed")].failureMessage}'
```

**Service stuck in Provisioning:**

1. Check provider status:
   ```bash
   kubectl describe serviceset <name> -n <namespace>
   ```

2. Check underlying provider objects (for built-in provider):
   ```bash
   kubectl get clusterprofile,profile -A
   kubectl get clustersummary -A
   ```

3. Check ServiceTemplate validity:
   ```bash
   kubectl get servicetemplate <template-name> -n <namespace>
   ```

**ServiceSet not being reconciled:**

1. Verify provider is ready:
   ```bash
   kubectl get statemanagementprovider -A
   ```

2. Check label matches provider selector:
   ```bash
   kubectl get serviceset <name> -n <namespace> -o jsonpath='{.metadata.labels}'
   ```

3. Check if ServiceSet is paused:
   ```bash
   kubectl get serviceset <name> -n <namespace> -o jsonpath='{.metadata.annotations}'
   ```
