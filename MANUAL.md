# WireGuard Genesis Kit Manual

Deploys a single-instance WireGuard VPN endpoint. Peers (clients) are
managed through vault-backed addons; peer changes take effect on
redeploy via `wg syncconf`, which never interrupts established
sessions.

## Base parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| wireguard_cidr | 10.20.30.0/24 | Tunnel network for clients |
| wireguard_server_address | 10.20.30.1/24 | Server's in-tunnel CIDR (keep it the .1 of wireguard_cidr) |
| wireguard_interface | wg0 | Interface name |
| wireguard_port | 51820 | UDP listen port |
| wireguard_endpoint | "" | Public host or host:port clients dial; falls back to the VM IP |
| wireguard_routed_networks | [] | Networks advertised to clients (AllowedIPs in client configs) |
| wireguard_iptables_forward | conntrack rule | FORWARD rules for the colocated iptables job |
| wireguard_dns | [] | DNS servers written into client configs |
| wireguard_network | wireguard | BOSH network name |
| wireguard_vm_type | wireguard | BOSH vm_type name |
| availability_zones | [z1] | AZs for the instance group |
| stemcell_os | ubuntu-noble | The stemcell needs the in-kernel WireGuard module; use the `resolute` feature instead of setting this to ubuntu-resolute |

`genesis new` prompts for the CIDR, port, routed networks, DNS, and
endpoint, and derives the conntrack FORWARD rules for you.

## Keys and secrets

WireGuard uses base64 Curve25519 keypairs — not x509 — so `kit.yml`
declares no credentials. Instead:

- Server keypair
  `<secrets-base>server:{private,public}`, ensured idempotently by the
  blueprint hook (generated with `wg genkey`, or openssl X25519 when
  wireguard-tools is not installed locally)

- Peer registry
  `<secrets-base>peers/<name>:{private,public,psk,address,allowed_ips,created}`

- Revoked peers
  `safe mv` to `<secrets-base>revoked/<name>-<epoch>`; the next deploy
  drops them from the interface

The blueprint enumerates the registry into `manifests/peers.dynamic.yml`
as `(( vault ... ))` references — literal key material never lands in
manifests or repos.

## Features

| Feature | Purpose |
|---------|---------|
| ocfp | OCFP topology: static IP from `net.subnets` reserved-ips key `wireguard_ip`, generated network fragment, ocfp naming for network/vm_type |
| resolute | Deploys the endpoint on the `ubuntu-resolute` stemcell instead of the default `ubuntu-noble`, and is still experimental. See [Ubuntu Resolute Stemcells](#ubuntu-resolute-stemcells). |

## Ubuntu Resolute Stemcells

The kit deploys the endpoint on an ubuntu-noble stemcell unless we ask for something else. Adding the `resolute` feature moves the endpoint onto ubuntu-resolute.

```yaml
kit:
  features:
  - resolute

params:
  stemcell_version: "0.184"
```

The feature is experimental, so we recommend trying it on a canary deployment before we point anything real at it. We have not deployed this kit on ubuntu-resolute yet. The jumpbox kit's `wireguard` feature runs the same wireguard, bpm, and networking releases, and it ran live on ubuntu-resolute 0.184, which tells us the in-kernel WireGuard module is present on that stemcell. The kit renders the right stemcell and the right releases with the feature on its own and together with the `ocfp` feature.

The feature sets the stemcell `os` to `ubuntu-resolute`, and `stemcell_version` still selects the version, which defaults to `latest`. We recommend pinning it to a resolute version such as `"0.184"`. A `latest` version resolves among the stemcells of that one operating system, so when someone uploads a newer resolute stemcell, the next deploy moves the endpoint onto it. A pinned `stemcell_version` has to be a resolute version, because the kit does not check that the number belongs to resolute. The director complains only at deploy time, and only when it has no such stemcell.

Because the feature owns the stemcell os, the kit refuses an environment that sets `params.stemcell_os` to anything else. It also refuses an environment that sets `params.stemcell_os` to `ubuntu-resolute` without turning the feature on, so an environment that used to rely on that parameter alone needs to add the feature and drop the parameter.

Before the first deploy, we upload the resolute stemcell to the director that deploys the endpoint. The director's runtime config must also carry bosh-dns 1.39.31 or later, because earlier bosh-dns releases do not run on resolute.

The kit always runs wireguard under bpm, and bpm releases older than 1.4.41 do not compile on resolute. When the `resolute` feature is on, the kit pins bpm to 1.4.41, and otherwise it leaves the bpm version alone. Resolute also ships without runit, so the `chpst` command is missing, and a job whose start script drops privileges with `chpst` hangs there. The wireguard release does not use `chpst`, and the networking release ran on resolute under the jumpbox kit, but we should check any other release we add to the deployment before we move it to resolute.

## Addons

| Addon | Alias | Usage |
|-------|-------|-------|
| add-peer | ap | `genesis <env> do add-peer <name> [extra-cidr ...]` |
| remove-peer | rp | `genesis <env> do remove-peer <name>` |
| list-peers | lp | `genesis <env> do list-peers` |
| generate-wg-config | gw | `genesis <env> do generate-wg-config [-q] <name>` |
| smoke | s | `genesis <env> do smoke` |

`generate-wg-config -q` renders the config as a terminal QR code
(requires `qrencode`) for direct import into mobile clients.

## Firewall / security groups (UDP ingress)

The kit opens nothing for you — UDP `wireguard_port` (51820) must be
reachable from clients:

- aws
  Security group via OCFP terraform

- azure
  NSG inbound rule

- gcp
  VPC firewall rule

- openstack, stackit
  Dedicated security group (the generated cloud config currently
  attaches `ocfp`/`default` SGs; extend when terraform provides a
  `wireguard` SG)

- pve, vsphere
  Host-level firewall (no SG layer)

Public IP / DNS provisioning is likewise terraform's job — carry the
result in `params.wireguard_endpoint`.

## Verification

After deploy:

```sh
genesis <env> do smoke        # colocated errand: interface, port, peers
genesis <env> do add-peer laptop
genesis deploy <env>
genesis <env> do generate-wg-config laptop
```

On the client, `wg show` should report a handshake within seconds of
first traffic.
