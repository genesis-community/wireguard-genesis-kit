package Genesis::Hook::Info::Wireguard v1.0.0;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook);

use Genesis qw/bail info run read_json_from/;

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

	my $endpoint = $self->env->exodus_lookup('endpoint', '');
	my $port     = $self->env->exodus_lookup('port', '51820');
	my $ip       = $self->env->exodus_lookup('ip', '');
	my $pubkey   = $self->env->exodus_lookup('public_key', '');

	info("WireGuard Endpoint:");
	info("  address:    %s:%s", ($endpoint || $ip || 'unknown'), $port);
	info("  public key: %s", $pubkey || 'unknown');
	info("");
	info("Manage peers with:");
	info("  #G{genesis $ENV{GENESIS_ENVIRONMENT} do list-peers}");
	info("  #G{genesis $ENV{GENESIS_ENVIRONMENT} do add-peer <name>}");
	info("  #G{genesis $ENV{GENESIS_ENVIRONMENT} do generate-wg-config <name>}");

	return $self->done(1);
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
