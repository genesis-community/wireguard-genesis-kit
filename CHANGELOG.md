# Changelog

## Unreleased

- We added an opt-in `resolute` feature that deploys the endpoint on the `ubuntu-resolute` stemcell and pins bpm to 1.4.41, because older bpm releases do not compile on resolute. The kit refuses an environment that turns the feature on while setting `params.stemcell_os` to another os, and it refuses one that sets `params.stemcell_os` to `ubuntu-resolute` without the feature.
- We added a pre-deploy hook that checks the merged manifest when the `resolute` feature is on. It refuses the deploy when an ops file from the deployment repo puts any stemcell on another OS or deploys bpm older than 1.4.41, because the blueprint gate only reads params.
- The peer addons now hand private keys and preshared keys to `safe`, `wg`, and `base64` through files that only the operator can read, so the keys never appear in a process's arguments.

- Initial kit: standalone WireGuard endpoint (wireguard + bpm +
  networking releases), vault-backed peer registry with add/remove/
  list/generate-wg-config/smoke addons, OCFP support with generated
  cloud config, azure/stackit overrides, testkit spec suite.
