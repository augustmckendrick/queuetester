# Deploying Clusters in Region

The process of creating a `ClusterDeployment` does not change when targeting a `Region`. If the `Credential` object
defined in the `spec.credential` field of the `ClusterDeployment` specifies a region, all cluster resources will be deployed to the corresponding regional
cluster.

See:

* [Creating Credential in Region](creating-credential-in-region.md) for details about regional credential setup.
* [Deploying a Cluster](../clusters/deploy-cluster.md) for cluster deployment instruction.
