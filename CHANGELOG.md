# Changelog

## Unreleased

- We added an opt-in `resolute` feature that deploys the endpoint on the `ubuntu-resolute` stemcell and pins bpm to 1.4.41, because older bpm releases do not compile on resolute. The kit refuses an environment that turns the feature on while setting `params.stemcell_os` to another os, and it refuses one that sets `params.stemcell_os` to `ubuntu-resolute` without the feature.
- We added a pre-deploy hook that checks the merged manifest when the `resolute` feature is on. It refuses the deploy when an ops file from the deployment repo puts any stemcell on another OS or deploys bpm older than 1.4.41, because the blueprint gate only reads params.
- The peer addons now hand private keys and preshared keys to `safe`, `wg`, and `base64` through files that only the operator can read, so the keys never appear in a process's arguments.
- `remove-peer` now destroys the peer's registry entry after moving it to `revoked/`. On a KV v2 mount the move only marked the entry deleted, so `list-peers` still showed the peer with no data and the blueprint refused every later deploy. The peer listing now skips entries like that, which the addon left behind before this fix.
- The peer listing now stops with an error that names the peer when the vault fails to answer whether that peer exists. Before, it read the failure as a missing peer, so the next deploy dropped the peer and `add-peer` could hand its address to another peer. `add-peer`, `remove-peer`, and `generate-wg-config` make the same distinction when they check a single peer. It also stops when the vault can't list the registry at all, instead of carrying on as if there were no peers.
- `remove-peer` now warns when it cannot destroy a revoked peer's registry entry, explains that a soft-deleted version may remain for an undelete to restore, and prints the `safe delete --force --destroy --all` command to run by hand. When the name is listed in the registry but holds no data, as an older `remove-peer` left it, the addon destroys that empty entry and reports the cleanup instead of refusing the name as unregistered.
- `generate-wg-config -q` now hands the client config to `qrencode` through a file that only the operator can read, so the private key and preshared key no longer appear in a process's arguments.
- We now keep generated private keys, preshared keys, and the keys the addons read back from the vault out of the Genesis trace log. The temporary files that carry a private key to the public key derivation are removed as soon as the derivation finishes, and we refuse a temporary directory whose path contains `=`, because `safe` would store such a path as a literal value instead of reading the file.
- The pre-deploy hook now treats a stemcell as resolute when its `os` is `ubuntu-resolute`, or when it has no `os` and its `name` contains `ubuntu-resolute`. It checks the bpm release whenever any stemcell in the merged manifest is resolute, even with the `resolute` feature off, and it gives a bpm release pinned to `latest` or deployed without a version its own message. It resolves `((name))` placeholders from the BOSH variables file and refuses one that no variable resolves.
- A deployment repo's `ops/resolute.yml` still applies when the `resolute` feature is on. It loads after the kit's resolute files, so it can still adjust the stemcell or the bpm release.

- Initial kit: standalone WireGuard endpoint (wireguard + bpm +
  networking releases), vault-backed peer registry with add/remove/
  list/generate-wg-config/smoke addons, OCFP support with generated
  cloud config, azure/stackit overrides, testkit spec suite.
