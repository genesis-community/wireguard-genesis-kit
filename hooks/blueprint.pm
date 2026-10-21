package Genesis::Hook::Blueprint::Wireguard v1.0.0;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail info warning error mkfile_or_fail count_nouns/;

# Include WireGuard key/peer helpers from mixin
BEGIN {
	require File::Basename;
	my $mixin_file = File::Basename::dirname(__FILE__) . '/lib/_wireguard_keys.pm';
	do $mixin_file or die "Failed to include hook mixin $mixin_file: $!";
}

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub perform {
	my ($self) = @_;
	return 1 if $self->completed;

	$self->add_files(qw(
		manifests/wireguard.yml
		manifests/releases/wireguard.yml
		manifests/releases/bpm.yml
		manifests/releases/networking.yml
	));

	# Server keypair: the credentials DSL cannot generate Curve25519, so
	# ensure it here (no-op when the pair already exists in vault).
	$self->_ensure_server_keys;

	my $ips = $self->env->lookup('params.ips', []);

	my $dynamic_static_fragment = '';
	if ($self->want_feature('ocfp')) {
		# Determine IP and AZ from ocfp config — a VPN endpoint is a single
		# instance, so only the first subnet with a reserved wireguard_ip
		# is used.
		my $subnets = $self->env->ocfp_config_lookup('net.subnets');
		my $prefix  = $self->env->ocfp_subnet_prefix;
		my $az_map  = $self->env->director_exodus_lookup('/network')->{azs};

		my (@ips, @azs) = ();
		for my $subnet (sort grep {/^$prefix/} keys %$subnets) {
			my $ip = $subnets->{$subnet}{'reserved-ips'}{'wireguard_ip'};
			next unless $ip;
			push @ips, $ip;

			my $az = $subnets->{$subnet}{az};
			if (!$az) {
				warning("No AZ found for subnet %s", $subnet);
				push @azs, undef;
			} else {
				push @azs, $az_map->{$az}{name} || undef;
			}
		}

		bail(
			"No subnet with a reserved 'wireguard_ip' found in the OCFP config"
		) unless @ips;

		@ips = ($ips[0]);
		@azs = ($azs[0]);
		my @valid_azs = grep { defined $_ } @azs;
		bail("No valid availability zones found for WireGuard instances")
			unless @valid_azs;

		my $network_name = "$ENV{GENESIS_ENVIRONMENT}.$ENV{GENESIS_TYPE}.net-wireguard";

		$dynamic_static_fragment = <<"EOF";
instance_groups:
- name: wireguard
  azs:${\(join "\n  - ", '', @valid_azs)}
  instances: 1
  networks:
  - (( replace ))
  - name: $network_name
    static_ips:${\(join "\n    - ", '', @ips)}
EOF

	} elsif (my $instances = @$ips) {
		my @ips = ($ips->[0]);
		$dynamic_static_fragment = <<"EOF";
instance_groups:
- name: wireguard
  instances: 1
  networks:
  - name: (( grab params.wireguard_network || "wireguard" ))
    static_ips:${\(join "\n    - ", '', @ips)}
EOF
	}

	if ($dynamic_static_fragment) {
		my $statics_file = "manifests/network.dynamic.yml";
		mkfile_or_fail($self->env->kit->path($statics_file), 0644, $dynamic_static_fragment);
		$self->add_files($statics_file);
	}

	# Peer registry: enumerate vault peers into a manifest fragment with
	# (( vault )) references. Absent when there are no peers yet.
	if (my $peers_fragment = $self->_render_peers_fragment('wireguard')) {
		my $peers_file = "manifests/peers.dynamic.yml";
		mkfile_or_fail($self->env->kit->path($peers_file), 0644, $peers_fragment);
		$self->add_files($peers_file);
	}

	$self->add_files('manifests/azure.yml')   if ($self->iaas eq 'azure');
	$self->add_files('manifests/stackit.yml') if ($self->iaas eq 'stackit');

	my @invalid = ();
	for my $feature ($self->features) {
		if ($feature eq 'ocfp') {
			$self->add_files('manifests/ocfp.yml');
		} elsif ($feature eq 'resolute') {
			# Handled after the loop so that it overrides every other fragment.
		} elsif (-f "$ENV{GENESIS_ROOT}/ops/${feature}.yml") {
			$self->add_files("$ENV{GENESIS_ROOT}/ops/${feature}.yml");
		} else {
			push @invalid, $feature;
		}
	}

	$self->_process_resolute;

	bail(
		"Invalid %s encountered: %s",
		count_nouns(scalar(@invalid), 'feature', suppress_count => 1),
		join(', ', @invalid)
	) if @invalid;

	return $self->done(1);
}

# _process_resolute - Opt-in ubuntu-resolute stemcell support {{{
# Called after every other fragment is added so that it overrides the
# stemcell os default (ubuntu-noble) and the bpm release pin.  A deployment
# repo's ops/resolute.yml is added last, so it can still adjust either.
sub _process_resolute {
	my ($self) = @_;

	if ($self->want_feature('resolute')) {
		my $stemcell_os = $self->env->lookup('params.stemcell_os', 'ubuntu-resolute');
		bail(
			"The #c{resolute} feature sets the stemcell os to ubuntu-resolute, but " .
			"the environment sets #c{params.stemcell_os} to #R{%s}.  " .
			"Remove that parameter.", $stemcell_os
		) if $stemcell_os ne 'ubuntu-resolute';
		$self->add_files('manifests/resolute.yml');
		# bpm releases older than 1.4.41 do not compile on resolute, and this
		# kit always runs wireguard under bpm.
		$self->add_files('manifests/releases/bpm-resolute.yml');
		# A deployment repo's ops/resolute.yml still applies, over the kit's files.
		$self->add_files("$ENV{GENESIS_ROOT}/ops/resolute.yml") if -f "$ENV{GENESIS_ROOT}/ops/resolute.yml";
	} elsif ($self->env->lookup('params.stemcell_os', 'ubuntu-noble') eq 'ubuntu-resolute') {
		bail(
			"The environment sets #c{params.stemcell_os} to ubuntu-resolute " .
			"without the #c{resolute} feature.  Enable the feature and remove " .
			"that parameter."
		);
	}
	return;
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
