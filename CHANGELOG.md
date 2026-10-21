# Changelog

## Unreleased

- We added an opt-in `resolute` feature that deploys the endpoint on the `ubuntu-resolute` stemcell and pins bpm to 1.4.41, because older bpm releases do not compile on resolute. The kit refuses an environment that turns the feature on while setting `params.stemcell_os` to another os, and it refuses one that sets `params.stemcell_os` to `ubuntu-resolute` without the feature.

- Initial kit: standalone WireGuard endpoint (wireguard + bpm +
  networking releases), vault-backed peer registry with add/remove/
  list/generate-wg-config/smoke addons, OCFP support with generated
  cloud config, azure/stackit overrides, testkit spec suite.
