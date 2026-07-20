package Genesis::Hook::PostDeploy::Wireguard v1.0.0;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::PostDeploy);

use Genesis qw/info/;

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

	unless ($ENV{GENESIS_DEPLOY_RC} == 0) {
		info("#R{Deployment failed} - skipping post-deploy actions");
		return $self->done(1);
	}

	info("");
	info("#M{$ENV{GENESIS_ENVIRONMENT}} WireGuard deployed successfully!");
	info("");
	info("Verify the endpoint with:");
	info("  #G{genesis do $ENV{GENESIS_ENVIRONMENT} -- smoke}");
	info("");
	info("Manage peers with:");
	info("  #G{genesis do $ENV{GENESIS_ENVIRONMENT} -- add-peer <name>}");
	info("  #G{genesis do $ENV{GENESIS_ENVIRONMENT} -- generate-wg-config <name>}");
	info("");
	info("Peer changes take effect on the next #C{genesis deploy} (applied");
	info("via wg syncconf - established sessions are not interrupted).");

	return $self->done(1);
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
