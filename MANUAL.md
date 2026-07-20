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
| stemcell_os | ubuntu-noble | Required — the release needs the in-kernel WireGuard module |

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
