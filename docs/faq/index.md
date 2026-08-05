# Frequently Asked Questions

**Q: What is the best way to upgrade the Kubernetes version of a {{{ docsVersionInfo.k0rdentName }}} child cluster?**

A: The simplest way to change the Kubernetes version of a specific child cluster is by updating the `ClusterDeployment` object. Where to updated it depends on the `ClusterTemplate` on which the `ClusterDeployment` is based.  For example, for built-in AWS, Azure, GCP, OpenStack, and Vsphere cluster templates (both standalone and hosted) you set the `spec.config.k0s.version` value to the desired Kubernetes version. For EKS, and AKS, you set `kubernetes.version`, and for GKE you set the `version` value. Note that this applies to built-in templates only; Custom templates may have another parameter exposed to represent the Kubernetes version.

You can also [create a new `ClusterTemplate`](../templatehowto/index.md) that will set the version for new clusters created based on that template.

**Q: Is it possible to control the version of the provider in the KCM Management object? For example, what if {{{ docsVersionInfo.k0rdentName }}} is using the Kubernetes Cluster API for OpenStack (CAPO) v0.12.4 but I want to use v0.12.2?**

A: You can change the Kubernetes Cluster API version by [creating a new `ProviderTemplate`](../templatehowto/index.md) that references a Helm chart with the appropriate provider components (with either the desired version hardcoded or configurable via `values.yaml`), then updating the `Management` object to reference that template. For example, you could [update the `Management` object](../appendix/appendix-extend-mgmt.md) to specify a new template for the OpenStack provider:

```yaml
spec:
  providers:
  - name: cluster-api-provider-openstack
    template: new-capo-provider-template-name
```



