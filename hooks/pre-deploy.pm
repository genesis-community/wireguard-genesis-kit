package Genesis::Hook::PreDeploy::Wireguard v1.0.0;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook);

use Genesis qw/bail run load_json new_enough semver/;

# bpm releases older than this do not compile on the resolute stemcell.
my $RESOLUTE_MIN_BPM = '1.4.41';

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
	$self->_check_resolute_manifest if $self->want_feature('resolute');
	return $self->done(1);
}
# }}}

# _check_resolute_manifest - every stemcell is resolute, and bpm is new enough {{{
# The blueprint gate reads params only, so an ops file from the deployment
# repo can still override the stemcells or the bpm release.  The merged
# manifest is the last word, so check that.  The manifest holds secrets, so
# its conversion is redacted from the trace log.
sub _check_resolute_manifest {
	my ($self) = @_;
	my $file = $ENV{GENESIS_MANIFEST_FILE};
	bail(
		"The #c{resolute} feature is enabled, but Genesis did not pass the ".
		"manifest to the pre-deploy hook, so its stemcells cannot be checked."
	) unless defined($file) && -f $file && -r $file;

	my ($out, $rc, $err) = run({stderr => 0, redact_output => 1}, 'spruce json < "$1"', $file);
	my $manifest = $rc == 0 ? eval {load_json($out)} : undef;
	bail(
		"The #c{resolute} feature is enabled, but the manifest at #C{%s} could ".
		"not be read to check its stemcells: %s",
		$file, ($err // '') =~ s/\s+$//r || "spruce exited $rc"
	) unless ref($manifest) eq 'HASH';

	my $stemcells = $manifest->{stemcells};
	bail(
		"The #c{resolute} feature is enabled, but the manifest lists no stemcells."
	) unless ref($stemcells) eq 'ARRAY' && @$stemcells;

	my @wrong = map {
		ref($_) eq 'HASH'
			? sprintf("%s (#R{%s})", $_->{alias} // '?', $_->{os} // 'no os')
			: '#R{an entry that is not a stemcell}'
	} grep {
		ref($_) ne 'HASH' || ($_->{os} // '') ne 'ubuntu-resolute'
	} @$stemcells;
	bail(
		"The #c{resolute} feature is enabled, but the manifest deploys these ".
		"stemcells on another OS: %s.  Remove the override that sets them.",
		join(', ', @wrong)
	) if @wrong;

	my @bpm = grep {ref($_) eq 'HASH' && ($_->{name} // '') eq 'bpm'} @{$manifest->{releases} // []};
	for my $release (@bpm) {
		my $version = $release->{version} // '';
		bail(
			"The manifest deploys bpm #R{%s} on a resolute stemcell, which needs ".
			"bpm %s or newer.  Remove the override that sets the bpm release.",
			$version || 'without a version', $RESOLUTE_MIN_BPM
		) unless semver($version) && new_enough($version, $RESOLUTE_MIN_BPM);
	}
	return 1;
}
# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
