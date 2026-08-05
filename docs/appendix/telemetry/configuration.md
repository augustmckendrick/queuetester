# Configuring telemetry

{{{ docsVersionInfo.k0rdentName}}} enables you to configure telemetry either by using the `--set` flag to set helm values during installation
or by editing the [Management](../../reference/crds/index.md#management) object for an existing management cluster, as
shown in the [Extended Management Configuration](../appendix-extend-mgmt.md#configuring-telemetry).

## Main settings block

Telemetry is configured under the `telemetry` block of the `kcm-regional` chart (see [Components segregation](../../admin/regional-clusters/components-segregation.md)).

In a `managements` object set the following:

```yaml
regional:
  telemetry:
    mode: online            # disabled | local | online (default: online)
    concurrency: 5          # scrape N clusters in parallel (1..100)
    interval: 1h            # scrape cadence
    jitter: 10              # % jitter (1..99)
```

* `mode` controls the collection and storage mechanism. `online` sends to Segment;
  `local` writes files; `disabled` turns it off. *(Default: `online`)*
* `concurrency` is how many child clusters are scraped in parallel.
* `interval` is the scrape frequency.
* `jitter` spreads scrapes across time to avoid thundering herds.

In a corresponding `regions` object set the following:

```yaml
telemetry:
  mode: online            # disabled | local | online (default: online)
  concurrency: 5          # scrape N clusters in parallel (1..100)
  interval: 1h            # scrape cadence
  jitter: 10              # % jitter (1..99)
```

Note, that the only change is the absence of the `regional` subpath.

> NOTE:
> Here and after all of the examples are given **without** the `regional`
> top subpath. Set or remove it accordingly depending what resource
> is being edited: **add** it if a `managements` object is being edited,
> do **not add** it if a `regions` object is being edited.

## Local mode storage settings

When `telemetry.mode` is set to `local`, you can configure where and how files are stored:

```yaml
telemetry:
  mode: local
  local:
    baseDir: /var/lib/telemetry
    volume:
      source: hostPath     # pvc | existing | hostPath (default)
      # For source: pvc (dynamic provisioning)
      pvc:
        storageClassName: ""        # default StorageClass if empty
        accessModes: [ReadWriteOnce]
        volumeMode: Filesystem
        size: 200Mi
        annotations: {}
      # For source: existing (use pre-created PVC)
      existingClaim: ""
      # For source: hostPath (static PV + matching PVC)
      hostPath:
        name: ""                    # defaults to <fullname>-telemetry-data
        reclaimPolicy: Retain
        storageClassName: "manual"
        accessModes: [ReadWriteOnce]
        volumeMode: Filesystem
        size: 200Mi
        annotations: {}
        labels: {}
        nodeAffinity: {}            # pin PV to a node if needed
```

* `baseDir` is the directory inside the pod where telemetry files appear;
  when `source: hostPath`, the host path **on the node** is the same `baseDir`.
* `volume.source` chooses between:
  
    - `pvc` — the chart **creates a PVC** (dynamic PV provisioning
      **must be configured** prior).
    - `existing` — the chart **uses an existing PVC** you name in `existingClaim`.
    - `hostPath` *(default)* — the chart **creates a static hostPath PV +
      matching PVC** mounted at `baseDir`.
      Default PV settings include `persistentVolumeReclaimPolicy: Retain`
      and `storageClassName: manual`; optional `nodeAffinity` ties
      the PV to a specific node.

> HINT: **Recommendation**
>
> Prefer dynamically-provisioned PVCs (`source: pvc`) or existing PVCs
> (`source: existing`) over `hostPath`.
> HostPath ties data to one node and is generally less stable/portable
> for controller pods that may reschedule.

## How the chart wires this up

* **Only** in `local` mode, an init container (`telemetry-data-permissions`)
  runs as root (only the `CHOWN` capability)
  to `chown -R 65532:65532 <baseDir>` so the main controller
  (running as non-root) can write files.
  The main pod runs with `runAsNonRoot: true`.
* When `source: hostPath`, the chart **creates**:

    - a **PersistentVolume** with `hostPath.path: <baseDir>`,
      `type: DirectoryOrCreate`, reclaim policy **Retain** (*default*),
      optional `nodeAffinity`.
    - a **matching PVC** bound by name.

> NOTE: **Note on a legacy flag**
>
> `controller.enableTelemetry` is **deprecated in 1.4.0
> and removed in 1.5.0 version in favor of the `telemetry`
> block**. It may still appear as a container arg for backward compatibility,
> but you should configure telemetry via the `telemetry` values going forward.

## Configuration examples

> NOTE:
>
> Replace only the snippets you need; all other values keep their defaults.

### Disable telemetry entirely

```yaml
telemetry:
  mode: disabled
```

No data is collected or stored.

### Online telemetry (defaults)

```yaml
telemetry:
  mode: online      # default
  concurrency: 5    # default
  interval: 1h      # default
  jitter: 10        # default
```

Sends data to Segment.io CDP.

### Local telemetry with dynamic provisioning

> WARNING: Ensure dynamic PV provisioning is configured prior.

```yaml
telemetry:
  mode: local
  local:
    baseDir: /var/lib/telemetry
    volume:
      source: pvc
      pvc:
        storageClassName: gp2
        accessModes: [ReadWriteOnce]
        size: 5Gi
```

Chart creates a PVC; files appear under `/var/lib/telemetry`
in the pod, rotated daily.

### Local telemetry with an existing PVC

```yaml
telemetry:
  mode: local
  local:
    baseDir: /var/lib/telemetry
    volume:
      source: existing
      existingClaim: kcm-telemetry-pvc
```

Chart uses your PVC; no PV/PVC objects are created by the chart.

### Local telemetry with hostPath (single-node / pinned-node)

```yaml
telemetry:
  mode: local
  local:
    baseDir: /var/lib/telemetry
    volume:
      source: hostPath
      hostPath:
        name: kcm-telemetry-hostpath
        reclaimPolicy: Retain
        storageClassName: manual
        size: 10Gi
        nodeAffinity:
          required:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values: ["worker-01"]
```

Chart creates a hostPath PV at `/var/lib/telemetry` and a matching PVC;
prefer PVC-backed options in HA clusters.

## Controller settings

> NOTE:
> Added in 1.5.0 version.

There are numerions settings to customize the dedicated telemetry controller.
The list of default settings is as follows:

```yaml
telemetry:
  # Telemetry runner configuration
  controller:
    # Number of replicas
    replicas: 1
    # Image configuration
    image:
      # Name of the image
      repository: ghcr.io/k0rdent/kcm/telemetry
      # Tag of the image
      tag: latest
      # Image pull policy, one of [IfNotPresent, Always, Never]
      pullPolicy: IfNotPresent
    # Container resources
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 64Mi
    # Node selector to constrain the pod to run on specific nodes
    nodeSelector: {}
    # Affinity rules for pod scheduling
    affinity: {}
    # Tolerations to allow the pod to schedule on tainted nodes
    tolerations: []
    # Global runner's logger settings
    logger:
      # Development defaults to (encoder=console,logLevel=debug,stackTraceLevel=warn) Production defaults to (encoder=json,logLevel=info,stackTraceLevel=error)
      devel: false
      # Encoder type, one of [json, console]
      encoder: ""
      # Log level, one of [info, debug, error]
      log-level: ""
      # Level on which to produce stacktraces, one of [info, error, panic]
      stacktrace-level: ""
      # Type of time encoding, one of [epoch, millis, nano, iso8601, rfc3339, rfc3339nano]
      time-encoding: rfc3339
```

## Troubleshooting

* **Settings are not applied**:
  make sure that the correct `regional` subpath is either added (if `managements` object)
  or is absent (if `regions` object).
* **No local files appear**:
  ensure `telemetry.mode: local` and that a volume source is configured.
  Check the init container `telemetry-data-permissions` completed successfully.
* **Pod unschedulable with hostPath**:
  if the pod moves to a different node, the hostPath PV won’t be there;
  either pin the PV with `nodeAffinity` or switch to a PVC-backed option.
* **Conflicting settings**:
  if you previously set `controller.enableTelemetry`, migrate to the
  `telemetry` block; the old flag is deprecated and is removed in the 1.5.0 version.
