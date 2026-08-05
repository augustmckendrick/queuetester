# Generating KCM CRD Documentation

To generate `/docs/reference/crds/index.md` follow these steps:

```
cd <docs home>/crdgen/api-docs
make api-docs
```

To specify a particular version of KCM:

```
cd <docs home>/crdgen/api-docs
KCM_REF=v1.6.0 make api-docs
```