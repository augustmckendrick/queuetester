# Maintaining KOF

## Backup Requirements

Backing up KOF requires backing up the following:

* Grafana configurations (if enabled)
* Alert definitions
* Custom dashboards
* Retention policies

## Health Monitoring

To implement health monitoring
apply the steps in the [Verification](./kof-verification.md) section.

## Uninstallation

To remove the demo clusters created in this section:

> WARNING:
> Make sure these are just your demo clusters and do not contain important data.

```bash
kubectl delete --wait --cascade=foreground -f child-cluster.yaml
kubectl delete --wait --cascade=foreground -f regional-cluster.yaml
```

To remove KOF from the management cluster:

```bash
helm uninstall --wait --cascade foreground -n kof kof
kubectl delete helmrelease --wait --cascade=foreground -n kof kof-collectors
kubectl delete helmrelease --wait --cascade=foreground -n kof kof-storage
kubectl delete helmrelease --wait --cascade=foreground -n kof kof-child
kubectl delete helmrelease --wait --cascade=foreground -n kof kof-regional
kubectl delete helmrelease --wait --cascade=foreground -n kof kof-mothership
kubectl delete helmrelease --wait --cascade=foreground -n kof victoria-metrics-operator
kubectl delete helmrelease --wait --cascade=foreground -n kof kof-operators
kubectl delete namespace kof --wait --cascade=foreground
```
