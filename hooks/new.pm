package Genesis::Hook::New::Wireguard v1.0.0;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook);

use Genesis qw/bail/;
use Genesis::UI qw/prompt_for_boolean prompt_for_line prompt_for_list/;

# init - Initialize the hook {{{
sub init {
	my ($class, %ops) = @_;
	my $obj = $class->SUPER::init(%ops);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}
# }}}

# perform - Main hook execution {{{
sub perform {
	my ($self) = @_;

	# Tunnel network
	my $cidr = prompt_for_line(
		'What network should WireGuard clients use? (CIDR format)',
		{ default => '10.20.30.0/24', validation => qr{^\d+\.\d+\.\d+\.\d+/\d+$} }
	);
	my ($net_base) = $cidr =~ m{^(\d+\.\d+\.\d+)\.};
	my $server_address = "$net_base.1/" . ($cidr =~ m{/(\d+)$})[0];

	my $port = prompt_for_line(
		'What UDP port should WireGuard listen on?',
		{ default => '51820', validation => qr/^\d+$/ }
	);

	# Routed networks -> conntrack FORWARD rules
	my @routed_networks = @{prompt_for_list('line',
		'What networks should be reachable through the VPN? (CIDR format, e.g. 10.4.0.0/16)',
		'network'
	)};

	my @dns = @{prompt_for_list('line',
		'What DNS servers should clients use over the VPN?',
		'DNS server'
	)};

	my $endpoint = prompt_for_line(
		'What public endpoint (host or host:port) will clients dial? (leave empty to derive from BOSH)',
		{ default => '' }
	);

	# Build environment file content
	my $file_content = "kit:\n";
	$file_content .= "  name:    $ENV{GENESIS_KIT_NAME}\n";
	$file_content .= "  version: $ENV{GENESIS_KIT_VERSION}\n";
	$file_content .= "\n";
	$file_content .= $self->env->genesis_config_block;

	my $params_content = "";
	$params_content .= "  wireguard_cidr: $cidr\n";
	$params_content .= "  wireguard_server_address: $server_address\n";
	$params_content .= "  wireguard_port: $port\n" if $port ne '51820';
	$params_content .= "  wireguard_endpoint: $endpoint\n" if $endpoint;

	if (@routed_networks) {
		$params_content .= "  wireguard_routed_networks:\n";
		for my $net (@routed_networks) {
			$params_content .= "    - $net\n";
		}
	}

	$params_content .= "  wireguard_iptables_forward:\n";
	for my $net (@routed_networks) {
		$params_content .= "    - -s $cidr -d $net -m conntrack --ctstate NEW -j ACCEPT -m comment --comment 'wg -> lan'\n";
		$params_content .= "    - -s $net -d $cidr -m conntrack --ctstate NEW -j ACCEPT -m comment --comment 'lan -> wg'\n";
	}
	$params_content .= "    - -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT\n";

	if (@dns) {
		$params_content .= "  wireguard_dns:\n";
		for my $dns (@dns) {
			$params_content .= "    - $dns\n";
		}
	}

	$file_content .= "params:\n";
	$file_content .= $params_content;

	# Write the environment file
	$self->env->write_manifest($file_content);

	return $self->done();
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
