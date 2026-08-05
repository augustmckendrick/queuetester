# Modifying and Creating {{{ docsVersionInfo.k0rdentName }}} Templates

In {{{ docsVersionInfo.k0rdentName }}}, almost everything you deploy or extend is expressed through **templates**. Templates provide a standardized way to describe complex Kubernetes resources and workflows so they can be reused, versioned, and shared. Whether you are adding services to a cluster, provisioning the cluster itself, or integrating a new infrastructure provider on which to run that cluster, you interact with {{{ docsVersionInfo.k0rdentName }}} through one of three template types:

- **ServiceTemplates**: `ServiceTemplate` objects define services and applications that run on clusters, such as workloads, networking, monitoring, or data platforms.  
- **ClusterTemplates**: `ClusterTemplate` objects define clusters, packaging all the infrastructure, control plane, and machine objects needed to stand up a Kubernetes environment.  
- **ProviderTemplates**: `ProviderTemplate` objects define CAPI infrastructure or bootstrap providers themselves, making them available to clusters.  

Although their use cases differ, these templates share the same architectural foundations.

## The Role of Helm, Flux, and CAPI

All {{{ docsVersionInfo.k0rdentName }}} templates ultimately reference **Helm charts**, which bundle Kubernetes manifests into reusable, versioned packages. They are retrieved and managed by **FluxCD**, which acts as the continuous delivery engine inside {{{ docsVersionInfo.k0rdentName }}}, and reconciled by **Cluster API (CAPI)** providers and other controllers, which take the rendered manifests and turn them into running infrastructure and services.  

- **Helm** provides the packaging format. A Helm chart is essentially a directory containing Kubernetes manifests (in the `templates/` folder), a metadata file (`Chart.yaml`), a values file (`values.yaml`), and optionally a schema file (`values.schema.json`). Helm’s templating engine replaces placeholders in manifests with values supplied by the user.  

- **FluxCD** provides the source management and installation mechanism. Flux fetches Helm charts from Git repositories, OCI registries, or buckets, and ensures that the correct version is available to {{{ docsVersionInfo.k0rdentName }}}. Flux also runs the Helm Controller, which is responsible for rendering and installing charts into clusters.  

- **Cluster API (CAPI)** provides the reconciliation logic. Once the chart is rendered into Kubernetes manifests, CAPI controllers reconcile the resources and create real infrastructure. For example, the CAPI AWS provider reconciles `AWSCluster` and `AWSMachine` objects into EC2 instances, while the k0smotron controller reconciles `K0sControlPlane` objects into running control plane nodes.  

These three components work together so that templates can create actual resources, such as a single `ClusterTemplate` reference that ultimately produces a fully functioning Kubernetes cluster.

Understanding this architectural pattern is essential before diving into specific template types, because once you know how templating works in {{{ docsVersionInfo.k0rdentName }}}, you can apply the same mental model to service and provider definitions as well.

## Why Templates Matter

- **Reusability:** Templates can be shared across many deployments, ensuring consistent architecture.  
- **Configuration management:** Parameters are centralized in a `values.yaml` file, which acts like a set of variables.  
- **Upgradeability:** Because templates are based on versioned charts, you can move between releases safely and predictably.  
- **Governance and validation:** Templates can include schemas that enforce correct usage and prevent invalid settings.  

In {{{ docsVersionInfo.k0rdentName }}}, templates are not just convenience wrappers, they're the backbone of how infrastructure and services are declared, standardized, and delivered.

- [The Templating System – Common Threads](the-templating-system-common-threads.md)
- [Creating and Modifying Templates](modifying-clusterTemplates.md)
- [Helm Values Overrides](helm-values-overrides.md)
