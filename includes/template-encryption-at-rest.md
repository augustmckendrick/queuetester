To enable Kubernetes API encryption at rest, configure these parameters under `.spec.config.encryption`:

* `automaticReload` (boolean): Enables `kube-apiserver` automatic reload for
  the encryption provider config (default: `true`).
* `configSecret.name` (string): Name of the Secret containing
  `EncryptionConfiguration`.
* `configSecret.key` (string): Secret data key with `EncryptionConfiguration`
  YAML (default: `config`).
* `configSecret.hash` (string): Optional hash suffix for the mounted file name.
  If empty, it is calculated automatically from the Secret data using Helm
  `lookup`.

The controller configures `kube-apiserver` with:

* `--encryption-provider-config=<path>`
* `--encryption-provider-config-automatic-reload=true` (when `automaticReload=true`)

Hash calculation behavior:

* If `configSecret.hash` is set, that value is used.
* If `configSecret.hash` is empty, the chart tries to calculate a hash from
  `Secret.data[configSecret.key]` in the `ClusterDeployment` namespace.
* If lookup cannot read the Secret during rendering, the chart falls back to
  `config.yaml`.

Secret placement rules:

* The Secret must exist in the same namespace as the `ClusterDeployment`.
* If `Credential.spec.region` is not set, create the Secret in the management
  cluster.
* If `Credential.spec.region` is set, create the Secret in the regional cluster.
* The encryption Secret is not copied automatically between management and
  regional clusters.

> NOTE:
> Enabling encryption at rest affects newly written data. Existing etcd objects
> are not re-encrypted automatically and require a rewrite/migration procedure.
