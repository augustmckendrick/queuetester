# Modes

| Mode | What happens | Where it goes |
| ---- | ------------ | ------------- |
| `disabled` | Collection is off | — |
| `online` *(default)* | Events are batched and sent to **Segment.io** with the default context fields listed [below](#privacy-and-identity-in-online-mode) | [Segment.io CDP](https://segment.com/) |
| `local` | Events are written to **files** and rotated **daily** | Files on a **PersistentVolume** mounted at the **base directory** |

Local files resemble:

```json
{
  "clusters": [
    {
      "counters": { "...": "..." },
      "labels": {
        "cluster": "ns/name",
        "clusterDeploymentID": "uid",
        "clusterID": "kube-system:uuid"
      }
    }
  ]
}
```

## Privacy and identity in `online` mode

When operating in `online` mode, each event includes a Segment context built
from the running KCM controller and environment
(build commit/name/version, system namespace, runtime OS/arch, timezone),
and uses the Management UID as an *AnonymousId* to bind events to
a management cluster — but not to an individual user.
