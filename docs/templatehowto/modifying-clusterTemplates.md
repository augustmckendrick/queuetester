# How to Build or Modify a {{{ docsVersionInfo.k0rdentName }}} Template

One of the most important benefits of {{{ docsVersionInfo.k0rdentName }}} is the ability to create your own `ServiceTemplate`, `ClusterTemplate`, and `ProviderTemplate` objects. The concepts are largely the same for all three, so we'll demonstrate the process with a `ClusterTemplate`.

## Anatomy of a ClusterTemplate

A `ClusterTemplate` in {{{ docsVersionInfo.k0rdentName }}} is a Kubernetes custom resource that points to a Helm chart. The chart itself contains all the CAPI objects required to define a cluster. A typical chart structure might look like this:

```
├── Chart.yaml
├── templates
│   ├── awscluster.yaml
│   ├── awsmachinetemplate-controlplane.yaml
│   ├── awsmachinetemplate-worker.yaml
│   ├── cluster.yaml
│   ├── k0scontrolplane.yaml
│   ├── k0sworkerconfigtemplate.yaml
│   └── machinedeployment.yaml
├── values.schema.json
└── values.yaml
```

- `Chart.yaml` contains metadata: chart name, version, and description.  
- `values.yaml` contains the default configuration parameters, such as cluster size, networking, and AMI IDs.  
- `values.schema.json` can restrict or validate the parameters that users supply.  
- The `templates/` directory contains Kubernetes manifests for CAPI objects, such as `Cluster`, `AWSCluster`, machine templates, and control plane definitions.  

By changing the values in `values.yaml`, you can produce many different clusters without modifying the underlying templates.

## Default values.yaml Example

The following snippet shows the default `values.yaml` for the AWS standalone control plane `ClusterTemplate`. This file is the main entry point for customization.

```yaml
controlPlaneNumber: 3
workersNumber: 2

clusterNetwork:
  pods:
    cidrBlocks:
      - "10.244.0.0/16"
  services:
    cidrBlocks:
      - "10.96.0.0/12"

clusterLabels: {}
clusterAnnotations: {}

region: ""
sshKeyName: ""
publicIP: false
bastion:
  enabled: false
  disableIngressRules: false
  allowedCIDRBlocks: []
  instanceType: t2.micro
  ami: ""
clusterIdentity:
  name: ""
  kind: "AWSClusterStaticIdentity"

controlPlane:
  amiID: ""
  iamInstanceProfile: control-plane.cluster-api-provider-aws.sigs.k8s.io
  instanceType: ""
  rootVolumeSize: 8
  imageLookup:
    format: "amzn2-ami-hvm*-gp2"
    org: "137112412989"
    baseOS: ""
  uncompressedUserData: false
  nonRootVolumes: []

worker:
  amiID: ""
  iamInstanceProfile: control-plane.cluster-api-provider-aws.sigs.k8s.io
  instanceType: ""
  rootVolumeSize: 8
  imageLookup:
    format: "amzn2-ami-hvm*-gp2"
    org: "137112412989"
    baseOS: ""
  uncompressedUserData: false
  nonRootVolumes: []

k0s:
  version: v1.32.6+k0s.0
  arch: amd64
  cpArgs: []
  workerArgs: []
  api:
    extraArgs: {}
  files: []
```

## Building a ClusterTemplate: Step by Step

Follow these steps to create a custom `ClusterTemplate`.

### 1. Obtain or create a Helm chart

Most users start from an existing template. Mirantis maintains a set of baseline `ClusterTemplates` in the [k0rdent GitHub repository](https://github.com/k0rdent/kcm/tree/main/templates/cluster). You can download these as tarballs from an OCI registry or clone them directly from GitHub. Alternatively, you can create your own chart with `helm create`.

### 2. Inspect the chart

Unpack the chart and look through the `templates/` directory. Each file maps to a CAPI object. Look at how values are referenced, usually with syntax like `.Values.controlPlaneNumber`. This tells you which parameters you can customize in `values.yaml`.

### 3. Modify configuration

Edit `values.yaml` to set the cluster size, networking ranges, AMIs, or k0s configuration. If you are creating a custom template, update `Chart.yaml` with your own name and version to distinguish it from the default. You may also extend `values.schema.json` to validate new parameters.

For example, to adjust Calico settings you might add:

```yaml
k0s:
  version: v1.32.6+k0s.0
  cpArgs:
    - "--enable-worker"
    - "--enable-calico" 
  workerArgs:
    - "--labels=network=calico"
```

### 4. Package and upload

Once modified, package the chart:

```bash
helm package ./my-custom-template
```

Then push it to your OCI registry:

```bash
helm push my-custom-template-0.1.0.tgz oci://registry.example.com/templates
```

You may also need to make the chart public.

## Connecting the Chart to {{{ docsVersionInfo.k0rdentName }}}

{{{ docsVersionInfo.k0rdentName }}} does not fetch charts directly. Instead, it relies on FluxCD Source objects. You must define a `HelmRepository`, `GitRepository`, or `Bucket` that points to your chart location, and you must label it so that {{{ docsVersionInfo.k0rdentName }}} will recognize it.

For example:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: custom-repo
  namespace: project-ottowa
  labels:
    k0rdent.mirantis.com/managed: "true"
spec:
  url: oci://registry.example.com/templates
  type: oci
  interval: 10m
```

Make sure the repository object is in the same namespace in which you will be creating the `ClusterTemplate` and `ClusterDeployment`.

## Creating the ClusterTemplate Resource

With the source in place, you can now define a `ClusterTemplate` that references your Helm chart:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ClusterTemplate
metadata:
  name: custom-aws-standalone
  namespace: project-ottowa
spec:
  helm:
    chartSpec:
      chart: my-custom-template
      version: 0.1.0
      interval: 10m
      sourceRef:
        kind: HelmRepository
        name: custom-repo
```

At this point, the {{{ docsVersionInfo.k0rdentName }}} controller validates the chart, reads the default values, and checks any annotations in `Chart.yaml` that declare required providers. For example, an AWS template might require `infrastructure-aws`, `control-plane-k0sproject-k0smotron`, and `bootstrap-k0sproject-k0smotron`. The template will only be marked "ready" if those providers are present.

## Deploying with a ClusterTemplate

Creating a `ClusterTemplate` does not deploy a cluster. Actual clusters are instantiated through **`ClusterDeployment`** objects, which reference `ClusterTemplates` and may override their default values. For example:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ClusterDeployment
metadata:
  name: my-cluster
  namespace: project-ottowa
spec:
  template: custom-aws-standalone
  credential: aws-cluster-identity-cred
  config:
    clusterLabels: {}
    region: us-west-2
    controlPlane:
      instanceType: t3.small
      rootVolumeSize: 32
    worker:
      instanceType: t3.small
      rootVolumeSize: 32
```

When this object is applied, Flux installs the chart, CAPI providers reconcile their objects, and controllers like k0smotron configure k0s. Eventually, the `ClusterDeployment` is marked ready.

## Customizing Templates

> WARNING:
> k0rdent automatically overrides some cluster and provider values depending on a global configuration or
> `ClusterDeployment` spec parameters. For example, all clusters are automatically configured with the reference
> to the cluster identity resource containing infrastructure credential (`clusterIdentity` section).
> See [Helm Values Overrides](./helm-values-overrides.md) for details on which values are overridden and how to work
> with them.

Customization is usually as simple as editing `values.yaml`. The key is to understand which variables are exposed. You can determine this by inspecting the `templates/` directory and seeing where `.Values` are used. For example, if a manifest contains:

```yaml
metadata:
  name: {{ .Values.clusterName }}
```

Then you know that adding `clusterName: "my-new-cluster"` to your values file will set the name.

Because Helm supports hierarchies and conditionals, values files can become quite expressive. Over time, organizations often create their own libraries of values files tailored for different environments — dev, staging, production — while reusing the same underlying templates.

## Troubleshooting and Validation

The most common issues when building `ClusterTemplates` involve:

- **Missing providers:** If the template references providers not installed in your management cluster, it will fail validation.  
- **Schema violations:** If you supply a value of the wrong type, Helm will reject it if a schema is defined.  
- **Flux sync errors:** If Flux cannot reach your repository or chart, the template will not resolve.  

Debugging usually involves checking Flux logs (`kubectl logs -n flux-system deployment/helm-controller`), verifying that sources are labeled correctly, and ensuring that provider CRDs are installed.

## Next Steps

Building a `ClusterTemplate` is often the first step toward customizing {{{ docsVersionInfo.k0rdentName }}} for your environment. Once you understand how charts, values, and templates work together, you can extend the same model to **ServiceTemplates** for application add-ons and **ProviderTemplates** for new infrastructure backends.  

By embracing templating as the core abstraction, {{{ docsVersionInfo.k0rdentName }}} gives you a powerful system: clusters, services, and providers all managed through the same consistent pattern, with strong validation, automation, and reuse built in.
