# Azure machine parameters

## SSH

The SSH public key can be passed to `.spec.config.sshPublicKey`
parameter (in the case of a hosted control plane) or `.spec.config.controlPlane.sshPublicKey` and
`.spec.config.worker.sshPublicKey` parameters (in the case of a standalone control plane)
of the `ClusterDeployment` object.

It should be encoded in **base64** format.

## VM size

Azure supports various VM sizes which can be retrieved with the following
command:

```bash
az vm list-sizes --location "<location>" -o table
```

Then desired VM size could be passed to the:

* `.spec.config.vmSize` - for hosted CP deployment.
* `.spec.config.controlPlane.vmSize` - for control plane nodes in the standalone
  deployment.
* `.spec.config.worker.vmSize` - for worker nodes in the standalone deployment.

*Example: Standard_A4_v2*

## Root Volume size

Root volume size of the VM (in GB) can be changed through the following
parameters:

* `.spec.config.rootVolumeSize` - for hosted CP deployment.
* `.spec.config.controlPlane.rootVolumeSize` - for control plane nodes in the
  standalone deployment.
* `.spec.config.worker.rootVolumeSize` - for worker nodes in the standalone
  deployment.

*Default value: 30*

Please note that this value can't be less than size of the root volume
defined in your image.

## VM Image

You can define the image which will be used for your machine using the following
parameters:

*`.spec.config.image` - for hosted CP deployment.

* `.spec.config.controlPlane.image` - for control plane nodes in the standalone
  deployment.
* `.spec.config.worker.image` - for worker nodes in the standalone deployment.

There are multiple self-excluding ways to define the image source (for example Azure
Compute Gallery, Azure Marketplace, and so on).

If `image` is not specified, the default will be the `ubuntu-2204` image from the Azure Marketplace.

Only one of the following image sources can be configured at a time:

* image.id
* image.computeGallery
* image.marketplace

If multiple sources are specified, the precedence is as follows:

1. `id`
2. `computeGallery`
3. `marketplace`

Example:

```yaml
spec:
  config:
    image:
      computeGallery:
        gallery: aksazurelinux-f7c7cda5-1c9a-4bdc-a222-9614c968580b
        name: V2gen2arm64
        version: 202501.05.0
```

Detailed information regarding image can be found in [CAPZ documentation](https://capz.sigs.k8s.io/self-managed/custom-images)

By default, the latest official CAPZ Ubuntu based image is used.

## Configuring k0s, k0smotron parameters

* `k0s.arch` (string): Defines the K0s Arch in its download URL. Available if [global.k0sURL](../../appendix/appendix-extend-mgmt.md#configuring-a-global-k0s-url)
   is set. Possible values: `"amd64"` (default), `"arm64"`, `"arm"`.
* `k0s.cpArgs` <sup>only standalone</sup> (array of strings): A list of extra arguments to be passed to k0s controller.
   See: <https://docs.k0sproject.io/stable/cli/k0s_controller>.
* `k0s.workerArgs` (array of strings): A list of extra arguments for configuring the k0s worker node. See: <https://docs.k0sproject.io/stable/cli/k0s_worker>.
* `k0smotron.controllerPlaneFlags` <sup>only hosted</sup> (array of strings): The `controllerPlaneFlags` parameter enables you to configure additional flags for the k0s control plane
   and to override existing flags. The default flags are kept unless they are explicitly overriden. Flags with arguments must be specified as a single
   string, such as `--some-flag=argument`.

## Etcd encryption at rest for hosted and standalone templates

{%
  include-markdown "../../../includes/template-encryption-at-rest.md"
%}
