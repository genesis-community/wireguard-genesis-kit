package Genesis::Hook::Addon::Wireguard::Smoke v1.0.0;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
use Genesis qw/bail info/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub cmd_details {
	return
	"Run the colocated smoke-tests errand against the WireGuard endpoint.\n".
	"Usage: genesis <env> do smoke\n";
}

sub perform {
	my ($self) = @_;

	info("Running smoke-tests errand on #C{%s}...", $self->env->bosh->deployment);
	my $rc = $self->env->bosh->execute(
		{interactive => 1},
		'run-errand', 'smoke-tests'
	);

	return $self->done();
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
