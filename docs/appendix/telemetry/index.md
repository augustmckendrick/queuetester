# Telemetry introduction

This document explains how **{{{ docsVersionInfo.k0rdentName }}}** collects
telemetry from *child* (managed) clusters, what data is gathered, where it
is stored for each mode, and how to configure the feature through either
Helm values or the [Management](../../reference/crds/index.md#management) object.

> **Why telemetry?**
> Telemetry helps the {{{ docsVersionInfo.k0rdentName }}} team understand
> real-world environments (cluster sizes, versions, GPU usage, etc.)
> to improve reliability and guide roadmap priorities. Data is
> scoped to operational characteristics and includes no application payloads.
>
> **Default behavior**
> Telemetry is **enabled by default** with mode `online`, which sends
> metrics to [Segment.io CDP](https://segment.com/) workspace owned by our team.
