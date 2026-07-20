package Genesis::Hook::CloudConfig::Wireguard v1.0.0;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw//;
use JSON::PP;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub perform {
	my ($self) = @_;
	return 1 if $self->completed;

	# NOTE: WireGuard needs UDP wireguard_port (51820 default) reachable
	# from clients. Security groups / firewall rules are provisioned
	# outside BOSH:
	#   aws        - SG via OCFP terraform
	#   azure      - NSG rule
	#   gcp        - firewall rule
	#   openstack/ - dedicated SG (extend get_sgs_by_names when terraform
	#   stackit      provides a 'wireguard' SG)
	#   pve/vsphere- host-level firewall
	my $config = $self->build_cloud_config({
		'networks' => [
			$self->network_definition('wireguard', strategy => 'ocfp',
				dynamic_subnets => {
					allocation => {
						# Static IPs come from the ocfp reserved-ips (one
						# wireguard_ip per subnet), not a pre-sized block.
						size => 0,
						statics => 0,
					},
					cloud_properties_for_iaas => {
						aws => {
							'subnet' => $self->subnet_reference('id'),
						},
						openstack => {
							'net_id' => $self->network_reference('id'),
							'security_groups' => ['default']
						},
						pve => {
							'bridge' => $self->_pve_network_bridge,
						},
						stackit => {
							'net_id' => $self->network_reference('id'),
							'security_groups' => $self->network_reference('sgs', 'get_sgs_by_names', 'ocfp', 'default'),
						},
					},
				}
			)
		],
		'vm_types' => [
			$self->vm_type_definition('wireguard',
				cloud_properties_for_iaas => {
					aws => {
						'instance_type' => $self->for_scale({
							dev => 't3.micro',
							prod => 't3.small'
						}, 't3.micro'),
						'ephemeral_disk' => {
							'encrypted' => $self->TRUE,
							'size' => 4096,
							'type' => 'gp3'
						},
						'metadata_options' => {
							'http_tokens' => 'required'
						},
					},
					azure => {
						'instance_type' => 'Standard_B2s',
					},
					gcp => {
						'machine_type' => 'e2-small',
					},
					openstack => {
						'instance_type' => 'm1.1',
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 16
						},
					},
					pve => {
						'cpu'            => scalar($self->env->lookup('bosh-configs.cpi.pve_wireguard_cpu', 2)),
						'ram'            => scalar($self->env->lookup('bosh-configs.cpi.pve_wireguard_ram', 2048)),
						'disk'           => scalar($self->env->lookup('bosh-configs.cpi.pve_wireguard_disk', 16384)),
						'network_bridge' => $self->_pve_network_bridge,
					},
					stackit => {
						'instance_type' => 'm1a.1d',
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 16
						},
					},
					vsphere => {
						'cpu'  => 2,
						'ram'  => 2048,
						'disk' => 16384,
					},
				},
			),
		],
		# No disk_types: the wireguard instance is stateless — all state
		# (keys, peer registry) lives in vault.
	});

	$self->done($config);

	return 1;
}

# Bridge resolution order: explicit env override, then the bridge the
# ocfp CLI recorded when configuring the CPI, then the legacy default.
sub _pve_network_bridge {
	my ($self) = @_;
	return scalar($self->env->lookup('bosh-configs.cpi.pve_network_bridge',
		scalar($self->env->ocfp_config_lookup('cpi.pve.network_bridge')) // 'lvnet001'
	));
}

sub get_sgs_by_names {
	my ($self, $subnet_data, $ref, @names) = @_;
	my @ids = map {$subnet_data->{$ref}{$_}{id}} @names;
	return \@ids
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
