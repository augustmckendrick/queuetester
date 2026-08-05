# Running K0rdent on ARM64: Known Limitations

K0rdent can be deployed on ARM64-based infrastructure, but there are some current limitations to be aware of.

## Infoblox CAPI Provider Compatibility

The [Infoblox Cluster API IPAM provider](https://github.com/telekom/cluster-api-ipam-provider-infoblox) does
**not currently support the ARM64 architecture**. See the upstream issue for
details: [Multi-arch support](https://github.com/telekom/cluster-api-ipam-provider-infoblox/issues/92).

As a result, the Infoblox provider will fail to start during the installation process, and the
**management object will remain in a non-ready state**. This blocks the successful deployment of K0rdent on
ARM64 platforms.

### Workaround

To install K0rdent without the Infoblox provider you should use a **custom management configuration** that excludes
`cluster-api-provider-infoblox` from the list of enabled providers. Follow the official configuration guide
here: [Extended Management Configuration Guide](appendix-extend-mgmt.md#configuration-guide).

This will allow K0rdent to be deployed successfully on ARM64 infrastructure without relying on unsupported components.
