# Build Your Own KSM Provider

> WARNING:
> Code examples provided below were not validated or compiled. They are provided to outline the idea
> of how to develop custom provider for the CD tool you prefer and how to integrate it with {{{ docsVersionInfo.k0rdentName }}}.

This guide walks you through creating a custom KSM (K0rdent Service Management) provider to reconcile k0rdent API resources. We'll use **FluxCD** as an example, but the same principles apply to any CD tool, such as ArgoCD, Rancher Fleet, or custom solutions.

## Overview

A KSM provider consists of three main components:

1. **CD Solution**: The underlying continuous delivery tool (e.g., FluxCD, ArgoCD)
2. **Adapter**: A Kubernetes controller that watches `ServiceSet` objects and translates them to CD-tool-specific resources
3. **StateManagementProvider**: A K0rdent resource that declares your provider and validates its readiness

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                     Management Cluster                 │
│                                                        │
│  ┌───────────────────┐      ┌─────────────────────┐    │
│  │ ClusterDeployment │      │ MultiClusterService │    │
│  │                   │      │                     │    │
│  └──────────┬────────┘      └───────────┬─────────┘    │
│             │                           │              │
│             └───────────┬───────────────┘              │
│                         │                              │
│                         ▼                              │ 
│                 ┌───────────────┐                      │
│                 │  ServiceSet   │◄────┐                │
│                 └───────┬───────┘     │                │
│                         │             │ wartches &     │
│                         ▼             │  updates       │
│              ┌────────────────────┐   │                │
│              │  Your Adapter      │───┘                │
│              │  Controller        │                    │
│              └──────────┬─────────┘                    │
│                         │ creates                      │
│                         ▼                              │
│              ┌────────────────────┐                    │
│              │  CD-Tool-Specific  │ (HelmRelease,      │
│              │  Resources         │ Kustomization,     │
│              └──────────┬─────────┘     etc.)          │
│                         │                              │
│                         ▼                              │
│           ┌───────────────────────────┐                │
│           │  Your CD Tool Controllers │                │
│           │  (e.g., flux-system)      │                │
│           └───────────────────────────┘                │
└────────────────────────────────────────────────────────┘
                          │
                          ▼  deploys to
                 ┌────────────────┐
                 │ Target Cluster │
                 └────────────────┘
```

## Prerequisites

Before you begin, you should have:

- Go 1.24+ installed
- Access to a Kubernetes cluster with K0rdent installed
- Familiarity with Kubernetes controllers and controller-runtime
- Understanding of your chosen CD tool's API

## Step 1: Deploy Your CD Solution

First, deploy your CD solution to the management cluster. For FluxCD:

```bash
# Install Flux
flux install --namespace=flux-system
```

Verify the installation:

```bash
kubectl get deployments -n flux-system
```

Expected output:
```
NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
helm-controller            1/1     1            1           1m
kustomize-controller       1/1     1            1           1m
notification-controller    1/1     1            1           1m
source-controller          1/1     1            1           1m
```

## Step 2: Design Your Provider Configuration

Define what configuration your provider needs. For FluxCD, we need:

```go
// internal/provider/flux/config.go
package flux

import (
	kustomizev1 "github.com/fluxcd/kustomize-controller/api/v1"
	helmv2 "github.com/fluxcd/helm-controller/api/v2"
)

// FluxProviderConfig defines configuration for the Flux provider
type FluxProviderConfig struct {
	// Interval for reconciliation (e.g., "5m", "1h")
	Interval string `json:"interval,omitempty"`

	// Prune enables garbage collection
	Prune bool `json:"prune,omitempty"`

	// Wait enables health checks
	Wait bool `json:"wait,omitempty"`

	// Timeout for operations
	Timeout string `json:"timeout,omitempty"`

	// TargetNamespace for all resources
	TargetNamespace string `json:"targetNamespace,omitempty"`

	// Suspend temporarily halts reconciliation
	Suspend bool `json:"suspend,omitempty"`

	// Priority for handling conflicts (not native to Flux)
	Priority int32 `json:"priority,omitempty"`
}
```

## Step 3: Implement the Adapter Controller

Create a controller that watches `ServiceSet` objects and creates Flux resources.

### Project Structure

```
your-flux-adapter/
├── cmd/
│   └── manager/
│       └── main.go
├── internal/
│   ├── controller/
│   │   ├── serviceset_controller.go
│   │   ├── status_collector.go
│   │   └── translator.go
│   └── provider/
│       └── flux/
│           ├── config.go
│           └── types.go
├── go.mod
└── go.sum
```

### Main Controller Implementation

```go
// internal/controller/serviceset_controller.go
package controller

import (
	"context"
	"fmt"
	"time"

	helmv2 "github.com/fluxcd/helm-controller/api/v2"
	kustomizev1 "github.com/fluxcd/kustomize-controller/api/v1"
	sourcev1 "github.com/fluxcd/source-controller/api/v1"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/json"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"

	kcmv1 "github.com/k0rdent/kcm/api/v1beta1"
	fluxprovider "your-org/flux-adapter/internal/provider/flux"
)

const (
	ServiceSetFinalizer = "flux.k0rdent.mirantis.com/serviceset"
	AdapterLabel        = "flux-adapter"
)

type ServiceSetReconciler struct {
	client.Client
	SystemNamespace string
}

func (r *ServiceSetReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := ctrl.LoggerFrom(ctx)
	log.Info("Reconciling ServiceSet")

	// Fetch the ServiceSet
	serviceSet := &kcmv1.ServiceSet{}
	if err := r.Get(ctx, req.NamespacedName, serviceSet); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	// Handle deletion
	if !serviceSet.DeletionTimestamp.IsZero() {
		return r.reconcileDelete(ctx, serviceSet)
	}

	// Add finalizer
	if !controllerutil.ContainsFinalizer(serviceSet, ServiceSetFinalizer) {
		controllerutil.AddFinalizer(serviceSet, ServiceSetFinalizer)
		return ctrl.Result{}, r.Update(ctx, serviceSet)
	}

	// Validate StateManagementProvider
	smp := &kcmv1.StateManagementProvider{}
	if err := r.Get(ctx, client.ObjectKey{Name: serviceSet.Spec.Provider.Name}, smp); err != nil {
		return ctrl.Result{}, fmt.Errorf("failed to get StateManagementProvider: %w", err)
	}

	// Check if this ServiceSet matches our adapter
	if !labelsMatchSelector(serviceSet.Labels, smp.Spec.Selector) {
		log.V(1).Info("ServiceSet labels don't match provider selector, skipping")
		return ctrl.Result{}, nil
	}

	// Update provider status in ServiceSet
	serviceSet.Status.Provider = kcmv1.ProviderState{
		Ready:     smp.Status.Ready,
		Suspended: smp.Spec.Suspend,
	}

	if !smp.Status.Ready {
		log.Info("StateManagementProvider not ready, skipping")
		return ctrl.Result{}, r.Status().Update(ctx, serviceSet)
	}

	if smp.Spec.Suspend {
		log.Info("StateManagementProvider suspended, skipping")
		return ctrl.Result{}, r.Status().Update(ctx, serviceSet)
	}

	// Parse provider configuration
	config := &fluxprovider.FluxProviderConfig{}
	if serviceSet.Spec.Provider.Config != nil {
		if err := json.Unmarshal(serviceSet.Spec.Provider.Config.Raw, config); err != nil {
			return ctrl.Result{}, fmt.Errorf("failed to parse provider config: %w", err)
		}
	}

	// Create or update Flux resources for each service
	if err := r.reconcileServices(ctx, serviceSet, config); err != nil {
		return ctrl.Result{}, err
	}

	// Collect status from Flux resources
	if err := r.collectServiceStatuses(ctx, serviceSet); err != nil {
		return ctrl.Result{}, err
	}

	// Update ServiceSet status
	return ctrl.Result{RequeueAfter: 30 * time.Second}, r.Status().Update(ctx, serviceSet)
}

func (r *ServiceSetReconciler) reconcileServices(
	ctx context.Context,
	serviceSet *kcmv1.ServiceSet,
	config *fluxprovider.FluxProviderConfig,
) error {
	log := ctrl.LoggerFrom(ctx)

	for _, svc := range serviceSet.Spec.Services {
		// Get the ServiceTemplate
		template := &kcmv1.ServiceTemplate{}
		key := client.ObjectKey{Name: svc.Template, Namespace: serviceSet.Namespace}
		if err := r.Get(ctx, key, template); err != nil {
			return fmt.Errorf("failed to get ServiceTemplate %s: %w", key, err)
		}

		// Skip if template is not valid
		if !template.Status.Valid {
			log.Info("ServiceTemplate not valid, skipping", "template", svc.Template)
			continue
		}

		// Create Flux resources based on template type
		switch {
		case template.Spec.Helm != nil:
			if err := r.createHelmRelease(ctx, serviceSet, svc, template, config); err != nil {
				return fmt.Errorf("failed to create HelmRelease for %s: %w", svc.Name, err)
			}
		case template.Spec.Kustomize != nil:
			if err := r.createKustomization(ctx, serviceSet, svc, template, config); err != nil {
				return fmt.Errorf("failed to create Kustomization for %s: %w", svc.Name, err)
			}
		case template.Spec.Resources != nil:
			if err := r.createKustomization(ctx, serviceSet, svc, template, config); err != nil {
				return fmt.Errorf("failed to create Kustomization for resources %s: %w", svc.Name, err)
			}
		}
	}

	return nil
}

func (r *ServiceSetReconciler) createHelmRelease(
	ctx context.Context,
	serviceSet *kcmv1.ServiceSet,
	svc kcmv1.ServiceWithValues,
	template *kcmv1.ServiceTemplate,
	config *fluxprovider.FluxProviderConfig,
) error {
	// Build HelmRelease name
	name := fmt.Sprintf("%s-%s", serviceSet.Name, svc.Name)
	namespace := serviceSet.Namespace

	helmRelease := &helmv2.HelmRelease{}
	helmRelease.Name = name
	helmRelease.Namespace = namespace

	// Set owner reference
	if err := controllerutil.SetControllerReference(serviceSet, helmRelease, r.Scheme()); err != nil {
		return err
	}

	// Create or update
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, helmRelease, func() error {
		// Set labels
		if helmRelease.Labels == nil {
			helmRelease.Labels = make(map[string]string)
		}
		helmRelease.Labels["ksm.k0rdent.mirantis.com/managed"] = "true"
		helmRelease.Labels["ksm.k0rdent.mirantis.com/serviceset"] = serviceSet.Name
		helmRelease.Labels["ksm.k0rdent.mirantis.com/service"] = svc.Name

		// Configure HelmRelease spec
		helmRelease.Spec.ReleaseName = svc.Name
		helmRelease.Spec.TargetNamespace = svc.Namespace
		if helmRelease.Spec.TargetNamespace == "" {
			helmRelease.Spec.TargetNamespace = svc.Name
		}

		// Set interval
		interval := metav1.Duration{Duration: 10 * time.Minute}
		if config.Interval != "" {
			if d, err := time.ParseDuration(config.Interval); err == nil {
				interval.Duration = d
			}
		}
		helmRelease.Spec.Interval = interval

		// Set timeout
		timeout := metav1.Duration{Duration: 5 * time.Minute}
		if config.Timeout != "" {
			if d, err := time.ParseDuration(config.Timeout); err == nil {
				timeout.Duration = d
			}
		}
		helmRelease.Spec.Timeout = &timeout

		// Configure chart source from ServiceTemplate status
		if template.Status.SourceStatus != nil {
			helmRelease.Spec.Chart = helmv2.HelmChartTemplate{
				Spec: helmv2.HelmChartTemplateSpec{
					SourceRef: helmv2.CrossNamespaceObjectReference{
						Kind:      template.Status.SourceStatus.Kind,
						Name:      template.Status.SourceStatus.Name,
						Namespace: template.Status.SourceStatus.Namespace,
					},
				},
			}
		}

		// Set values
		if svc.Values != "" {
			helmRelease.Spec.Values = &apiextensionsv1.JSON{Raw: []byte(svc.Values)}
		}

		// Apply provider configuration
		helmRelease.Spec.Suspend = config.Suspend

		return nil
	})

	return err
}

func (r *ServiceSetReconciler) createKustomization(
	ctx context.Context,
	serviceSet *kcmv1.ServiceSet,
	svc kcmv1.ServiceWithValues,
	template *kcmv1.ServiceTemplate,
	config *fluxprovider.FluxProviderConfig,
) error {
	name := fmt.Sprintf("%s-%s", serviceSet.Name, svc.Name)
	namespace := serviceSet.Namespace

	kustomization := &kustomizev1.Kustomization{}
	kustomization.Name = name
	kustomization.Namespace = namespace

	if err := controllerutil.SetControllerReference(serviceSet, kustomization, r.Scheme()); err != nil {
		return err
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, kustomization, func() error {
		// Set labels
		if kustomization.Labels == nil {
			kustomization.Labels = make(map[string]string)
		}
		kustomization.Labels["ksm.k0rdent.mirantis.com/managed"] = "true"
		kustomization.Labels["ksm.k0rdent.mirantis.com/serviceset"] = serviceSet.Name
		kustomization.Labels["ksm.k0rdent.mirantis.com/service"] = svc.Name

		// Configure Kustomization spec
		interval := metav1.Duration{Duration: 10 * time.Minute}
		if config.Interval != "" {
			if d, err := time.ParseDuration(config.Interval); err == nil {
				interval.Duration = d
			}
		}
		kustomization.Spec.Interval = interval

		// Set source reference from ServiceTemplate
		if template.Status.SourceStatus != nil {
			kustomization.Spec.SourceRef = kustomizev1.CrossNamespaceSourceReference{
				Kind:      template.Status.SourceStatus.Kind,
				Name:      template.Status.SourceStatus.Name,
				Namespace: template.Status.SourceStatus.Namespace,
			}

			// Set path
			if template.Spec.Kustomize != nil {
				kustomization.Spec.Path = template.Spec.Kustomize.Path
			} else if template.Spec.Resources != nil {
				kustomization.Spec.Path = template.Spec.Resources.Path
			}
		}

		// Set target namespace
		if svc.Namespace != "" {
			kustomization.Spec.TargetNamespace = svc.Namespace
		}

		// Apply provider configuration
		kustomization.Spec.Prune = config.Prune
		kustomization.Spec.Wait = config.Wait
		kustomization.Spec.Suspend = config.Suspend

		if config.Timeout != "" {
			if d, err := time.ParseDuration(config.Timeout); err == nil {
				kustomization.Spec.Timeout = &metav1.Duration{Duration: d}
			}
		}

		return nil
	})

	return err
}

func (r *ServiceSetReconciler) collectServiceStatuses(ctx context.Context, serviceSet *kcmv1.ServiceSet) error {
	states := make([]kcmv1.ServiceState, 0, len(serviceSet.Spec.Services))

	for _, svc := range serviceSet.Spec.Services {
		state := kcmv1.ServiceState{
			Name:                    svc.Name,
			Namespace:               svc.Namespace,
			Template:                svc.Template,
			Version:                 svc.Template,
			State:                   kcmv1.ServiceStateProvisioning,
			LastStateTransitionTime: &metav1.Time{Time: time.Now()},
		}

		// Try to get HelmRelease
		helmName := fmt.Sprintf("%s-%s", serviceSet.Name, svc.Name)
		helmRelease := &helmv2.HelmRelease{}
		helmErr := r.Get(ctx, client.ObjectKey{Name: helmName, Namespace: serviceSet.Namespace}, helmRelease)

		if helmErr == nil {
			state.Type = kcmv1.ServiceTypeHelm
			// Check HelmRelease conditions
			for _, cond := range helmRelease.Status.Conditions {
				if cond.Type == "Ready" {
					if cond.Status == metav1.ConditionTrue {
						state.State = kcmv1.ServiceStateDeployed
					} else if cond.Reason == "InstallFailed" || cond.Reason == "UpgradeFailed" {
						state.State = kcmv1.ServiceStateFailed
						state.FailureMessage = cond.Message
					}
					break
				}
			}
		} else if !apierrors.IsNotFound(helmErr) {
			return helmErr
		}

		// Try to get Kustomization
		kustomName := fmt.Sprintf("%s-%s", serviceSet.Name, svc.Name)
		kustomization := &kustomizev1.Kustomization{}
		kustomErr := r.Get(ctx, client.ObjectKey{Name: kustomName, Namespace: serviceSet.Namespace}, kustomization)

		if kustomErr == nil {
			state.Type = kcmv1.ServiceTypeKustomize
			// Check Kustomization conditions
			for _, cond := range kustomization.Status.Conditions {
				if cond.Type == "Ready" {
					if cond.Status == metav1.ConditionTrue {
						state.State = kcmv1.ServiceStateDeployed
					} else if cond.Reason == "ReconciliationFailed" || cond.Reason == "BuildFailed" {
						state.State = kcmv1.ServiceStateFailed
						state.FailureMessage = cond.Message
					}
					break
				}
			}
		} else if !apierrors.IsNotFound(kustomErr) {
			return kustomErr
		}

		states = append(states, state)
	}

	serviceSet.Status.Services = states
	serviceSet.Status.Deployed = true
	for _, state := range states {
		if state.State != kcmv1.ServiceStateDeployed {
			serviceSet.Status.Deployed = false
			break
		}
	}

	return nil
}

func (r *ServiceSetReconciler) reconcileDelete(ctx context.Context, serviceSet *kcmv1.ServiceSet) (ctrl.Result, error) {
	log := ctrl.LoggerFrom(ctx)
	log.Info("Reconciling ServiceSet deletion")

	// Update service states to Deleting
	for i := range serviceSet.Status.Services {
		serviceSet.Status.Services[i].State = kcmv1.ServiceStateDeleting
		serviceSet.Status.Services[i].LastStateTransitionTime = &metav1.Time{Time: time.Now()}
	}
	if err := r.Status().Update(ctx, serviceSet); err != nil {
		return ctrl.Result{}, err
	}

	// Remove finalizer (Flux resources will be deleted by owner reference)
	controllerutil.RemoveFinalizer(serviceSet, ServiceSetFinalizer)
	return ctrl.Result{}, r.Update(ctx, serviceSet)
}

func (r *ServiceSetReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&kcmv1.ServiceSet{}).
		Owns(&helmv2.HelmRelease{}).
		Owns(&kustomizev1.Kustomization{}).
		Complete(r)
}

func labelsMatchSelector(labels map[string]string, selector *metav1.LabelSelector) bool {
	if selector == nil {
		return true
	}
	for key, value := range selector.MatchLabels {
		if labels[key] != value {
			return false
		}
	}
	return true
}
```

### Main Entry Point

```go
// cmd/manager/main.go
package main

import (
	"flag"
	"os"

	helmv2 "github.com/fluxcd/helm-controller/api/v2"
	kustomizev1 "github.com/fluxcd/kustomize-controller/api/v1"
	sourcev1 "github.com/fluxcd/source-controller/api/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"

	kcmv1 "github.com/k0rdent/kcm/api/v1beta1"
	"your-org/flux-adapter/internal/controller"
)

var (
	scheme = runtime.NewScheme()
)

func init() {
	_ = kcmv1.AddToScheme(scheme)
	_ = helmv2.AddToScheme(scheme)
	_ = kustomizev1.AddToScheme(scheme)
	_ = sourcev1.AddToScheme(scheme)
}

func main() {
	var metricsAddr string
	var enableLeaderElection bool
	var systemNamespace string

	flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "The address the metric endpoint binds to.")
	flag.BoolVar(&enableLeaderElection, "leader-elect", false, "Enable leader election for controller manager.")
	flag.StringVar(&systemNamespace, "system-namespace", "kcm-system", "The namespace where KCM is installed.")
	flag.Parse()

	ctrl.SetLogger(zap.New(zap.UseDevMode(true)))

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:             scheme,
		MetricsBindAddress: metricsAddr,
		LeaderElection:     enableLeaderElection,
		LeaderElectionID:   "flux-adapter.k0rdent.mirantis.com",
	})
	if err != nil {
		ctrl.Log.Error(err, "unable to start manager")
		os.Exit(1)
	}

	if err = (&controller.ServiceSetReconciler{
		Client:          mgr.GetClient(),
		SystemNamespace: systemNamespace,
	}).SetupWithManager(mgr); err != nil {
		ctrl.Log.Error(err, "unable to create controller", "controller", "ServiceSet")
		os.Exit(1)
	}

	ctrl.Log.Info("starting manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		ctrl.Log.Error(err, "problem running manager")
		os.Exit(1)
	}
}
```

## Step 4: Build and Deploy the Adapter

### Create Dockerfile

```dockerfile
FROM golang:1.24 as builder

WORKDIR /workspace
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -o manager cmd/manager/main.go

FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /workspace/manager .
USER 65532:65532

ENTRYPOINT ["/manager"]
```

### Build and push the image

```bash
docker build -t your-registry/flux-adapter:v0.1.0 .
docker push your-registry/flux-adapter:v0.1.0
```

### Deploy the adapter

```yaml
# deploy/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flux-adapter
  namespace: kcm-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flux-adapter
  template:
    metadata:
      labels:
        app: flux-adapter
    spec:
      serviceAccountName: flux-adapter
      containers:
      - name: manager
        image: your-registry/flux-adapter:v0.1.0
        args:
        - --leader-elect
        - --system-namespace=kcm-system
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flux-adapter
  namespace: kcm-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: flux-adapter
rules:
- apiGroups: ["k0rdent.mirantis.com"]
  resources: ["servicesets", "servicetemplates", "statemanagementproviders"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: ["k0rdent.mirantis.com"]
  resources: ["servicesets/status"]
  verbs: ["get", "update", "patch"]
- apiGroups: ["helm.toolkit.fluxcd.io"]
  resources: ["helmreleases"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["kustomize.toolkit.fluxcd.io"]
  resources: ["kustomizations"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["source.toolkit.fluxcd.io"]
  resources: ["gitrepositories", "helmrepositories", "buckets", "ocirepositories"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: flux-adapter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flux-adapter
subjects:
- kind: ServiceAccount
  name: flux-adapter
  namespace: kcm-system
```

Apply the deployment:

```bash
kubectl apply -f deploy/deployment.yaml
```

## Step 5: Create StateManagementProvider

Create a `StateManagementProvider` resource that registers your provider:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: StateManagementProvider
metadata:
  name: ksm-flux
spec:
  adapter:
    apiVersion: apps/v1
    kind: Deployment
    name: flux-adapter
    namespace: kcm-system
    readinessRule: |-
      self.status.availableReplicas == self.status.replicas &&
      self.status.availableReplicas == self.status.updatedReplicas &&
      self.status.availableReplicas == self.status.readyReplicas
  provisioner:
  - apiVersion: apps/v1
    kind: Deployment
    name: helm-controller
    namespace: flux-system
    readinessRule: |-
      self.status.availableReplicas > 0 &&
      self.status.readyReplicas > 0
  - apiVersion: apps/v1
    kind: Deployment
    name: kustomize-controller
    namespace: flux-system
    readinessRule: |-
      self.status.availableReplicas > 0 &&
      self.status.readyReplicas > 0
  - apiVersion: apps/v1
    kind: Deployment
    name: source-controller
    namespace: flux-system
    readinessRule: |-
      self.status.availableReplicas > 0 &&
      self.status.readyReplicas > 0
  provisionerCRDs:
  - group: helm.toolkit.fluxcd.io
    version: v2
    resources:
    - helmreleases
  - group: kustomize.toolkit.fluxcd.io
    version: v1
    resources:
    - kustomizations
  - group: source.toolkit.fluxcd.io
    version: v1
    resources:
    - gitrepositories
    - helmrepositories
    - ocirepositories
    - buckets
  selector:
    matchLabels:
      ksm.k0rdent.mirantis.com/adapter: flux-adapter
  suspend: false
```

Apply it:

```bash
kubectl apply -f statemanagementprovider.yaml
```

## Step 6: Test Your Provider

### Create a test ClusterDeployment

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ClusterDeployment
metadata:
  name: test-cluster
  namespace: default
spec:
  template: aws-standalone-cp-0-0-4
  credential: aws-cred
  serviceSpec:
    provider:
      name: ksm-flux
      config:
        interval: "5m"
        prune: true
        wait: true
        timeout: "5m"
    services:
    - template: ingress-nginx-4-11-3
      name: ingress-nginx
      namespace: ingress-nginx
```

### Verify the provider is working

```bash
# Check StateManagementProvider status
kubectl get statemanagementprovider ksm-flux -o yaml

# Check ServiceSet was created
kubectl get serviceset -A

# Check Flux resources were created
kubectl get helmrelease -A
kubectl get kustomization -A

# Check service status
kubectl get clusterdeployment test-cluster -o jsonpath='{.status.services}'
```

## Best Practices

### 1. Error Handling

Always provide clear error messages in service states:

```go
state.State = kcmv1.ServiceStateFailed
state.FailureMessage = fmt.Sprintf("HelmRelease failed: %s", condition.Message)
```

### 2. Status Updates

Update ServiceSet status frequently to give users visibility:

```go
// Update service state immediately when detected
if oldState != newState {
    state.LastStateTransitionTime = &metav1.Time{Time: time.Now()}
}
```

### 3. Label Management

Use consistent labels for tracking resources:

```go
labels := map[string]string{
    "ksm.k0rdent.mirantis.com/managed":    "true",
    "ksm.k0rdent.mirantis.com/serviceset": serviceSet.Name,
    "ksm.k0rdent.mirantis.com/service":    svc.Name,
}
```

### 4. Owner References

Set owner references for automatic cleanup:

```go
if err := controllerutil.SetControllerReference(serviceSet, resource, r.Scheme()); err != nil {
    return err
}
```

### 5. Configuration Validation

Validate provider configuration early:

```go
config := &FluxProviderConfig{}
if err := json.Unmarshal(serviceSet.Spec.Provider.Config.Raw, config); err != nil {
    return fmt.Errorf("invalid provider config: %w", err)
}

if config.Interval != "" {
    if _, err := time.ParseDuration(config.Interval); err != nil {
        return fmt.Errorf("invalid interval: %w", err)
    }
}
```

## Advanced Topics

### Handling Multiple Clusters

If your CD tool doesn't natively support multi-cluster, you can:

1. Use remote kubeconfig secrets
2. Create CD resources per target cluster
3. Implement cluster discovery logic

### Priority and Conflict Resolution

Implement priority handling if needed:

```go
// Store priority in labels
labels["ksm.k0rdent.mirantis.com/priority"] = fmt.Sprintf("%d", config.Priority)

// Check for conflicts before creating resources
existingRelease := &helmv2.HelmRelease{}
err := r.Get(ctx, key, existingRelease)
if err == nil {
    existingPriority := getPriority(existingRelease)
    if existingPriority > config.Priority {
        return fmt.Errorf("higher priority resource exists")
    }
}
```

### Health Checks

Implement comprehensive health checks:

```go
func isHealthy(helmRelease *helmv2.HelmRelease) bool {
    for _, cond := range helmRelease.Status.Conditions {
        if cond.Type == "Ready" && cond.Status == metav1.ConditionTrue {
            return true
        }
        if cond.Type == "TestSuccess" && cond.Status == metav1.ConditionTrue {
            return true
        }
    }
    return false
}
```

The same pattern can be applied to any CD tool. The key is translating ServiceSet specifications into your CD tool's native resources and reporting status back to K0rdent.
