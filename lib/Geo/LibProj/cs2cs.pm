use 5.014;
use strict;
use warnings;

package Geo::LibProj::cs2cs;
# ABSTRACT: Perl IPC interface to PROJ cs2cs


use Carp qw(croak);
use File::Basename qw(basename);
use File::Spec;
use Scalar::Util 1.10 qw(looks_like_number);

use IPC::Run3 qw(run3);


our $CMD = 'cs2cs';
our @PATH = ();
eval {
	require # optional module; try to hide from static analysers
		Alien::proj;
	unshift @PATH, File::Spec->catdir(Alien::proj->dist_dir, 'bin');
};

# default stringification formats for cs2cs stdin and stdout
our $FORMAT_IN  = '%.15g';
our $FORMAT_OUT = '%.12g';

our %PARAMS = (
	-f => $FORMAT_OUT,
);


sub new {
	my $class = shift;
	
	my ($source_crs, $target_crs, $user_params);
	if ( ref($_[0]) eq 'HASH' ) {
		($user_params, $source_crs, $target_crs) = @_;
	}
	else {
		($source_crs, $target_crs, $user_params) = @_;
	}
	
	my $self = bless {}, $class;
	
	my $params = { %PARAMS, defined $user_params ? %$user_params : () };
	$self->_special_params($params);
	$self->{format_in} = $FORMAT_IN;
	
	# assemble cs2cs call line
	for my $key (keys %$params) {
		delete $params->{$key} unless defined $params->{$key};
	}
	$self->{cmd} = $self->_cmd();
	$self->{call} = [$self->{cmd}, %$params, $source_crs, '+to', $target_crs, '-'];
	
	return $self;
}


sub _special_params {
	my (undef, $params) = @_;
	
	# support -d even for older cs2cs versions
	if (defined $params->{-d} && defined $params->{-f}) {
		$params->{-f} = '%.' . (0 + $params->{-d}) . 'f';
		delete $params->{-d};
	}
	
	croak "-E is unsupported" if defined $params->{'-E'};
	croak "-t is unsupported" if defined $params->{'-t'};
	croak "-v is unsupported" if defined $params->{'-v'};
	
	# -w3 must be supplied as a single parameter to cs2cs
	if (defined $params->{-w}) {
		$params->{"-w$params->{-w}"} = '';
		delete $params->{-w};
	}
	if (defined $params->{-W}) {
		$params->{"-W$params->{-W}"} = '';
		delete $params->{-W};
	}
	
	delete $params->{XS};
}


sub _cmd {
	# try to find the cs2cs binary
	foreach my $path (@PATH) {
		if (defined $path) {
			my $cmd = File::Spec->catfile($path, $CMD);
			return $cmd if -e $cmd;
		}
		else {
			# when the @PATH element is undefined, try the env PATH
			eval { run3 [$CMD, '-lp'], \undef, \undef, \undef };
			return $CMD if ! $@ && $? == 0;
		}
	}
	
	# no luck; let's just hope it'll be on the PATH somewhere
	return $CMD;
}


sub _ipc_error_check {
	my ($self, $eval_err, $os_err, $code, $stderr) = @_;
	
	my $cmd = $CMD;
	if (ref $self) {
		$self->{stderr} = $stderr;
		$self->{status} = $code >> 8;
	}
	
	$stderr =~ s/^(.*\S)\s*\z/: $1/s if length $stderr;
	croak "`$cmd` failed to execute: $os_err" if $code == -1;
	croak "`$cmd` died with signal " . ($code & 0x7f) . $stderr if $code & 0x7f;
	croak "`$cmd` exited with status " . ($code >> 8) . $stderr if $code;
	croak $eval_err =~ s/\s+\z//r if $eval_err;
}


sub _format {
	my ($self, $value) = @_;
	
	return sprintf $self->{format_in}, $value if looks_like_number $value;
	return $value;
}


sub transform {
	my ($self, @source_points) = @_;
	
	my @in = ();
	foreach my $i (0 .. $#source_points) {
		my $p = $source_points[$i];
		push @in,   $self->_format($p->[0] || 0) . " "
		          . $self->_format($p->[1] || 0) . " "
		          . $self->_format($p->[2] || 0) . " $i";
	}
	my $in = join "\n", @in;
	
	my @out = ();
	my $err = '';
	eval {
		local $/ = "\n";
		run3 $self->{call}, \$in, \@out, \$err;
	};
	$self->_ipc_error_check($@, $!, $?, $err);
	
	my @target_points = ();
	foreach my $line (@out) {
		next unless $line =~ m{\s(\d+)\s*$}xa;
		my $aux = $source_points[$1]->[3];
		next unless $line =~ m{^\s* (\S+) \s+ (\S+) \s+ (\S+) \s}xa;
		my @p = defined $aux ? ($1, $2, $3, $aux) : ($1, $2, $3);
		
		foreach my $j (0..2) {
			$p[$j] = 0 + $p[$j] if looks_like_number $p[$j];
		}
		
		push @target_points, \@p;
	}
	
	if ( (my $s = @source_points) != (my $t = @target_points) ) {
		croak "Source/target point count doesn't match ($s/$t): Assertion failed";
	}
	
	return @target_points if wantarray;
	return $target_points[0] if @target_points < 2;
	croak "transform() with list argument prohibited in scalar context";
}


sub version {
	my ($self) = @_;
	
	my $out = '';
	eval {
		run3 [ $self->_cmd ], \undef, \$out, \$out;
	};
	$self->_ipc_error_check($@, $!, $?, '');
	
	return $1 if $out =~ m/\b(\d+\.\d+(?:\.\d\w*)?)\b/;
	return $out;
}


1;

__END__

=head1 SYNOPSIS

 use Geo::LibProj::cs2cs;
 
 $cs2cs = Geo::LibProj::cs2cs->new("EPSG:25833" => "EPSG:4326");
 $point = $cs2cs->transform( [500_000, 6094_800] );  # UTM 33U
 # result geographic lat, lon: [55.0, 15.0]
 
 @points_utm = ([500_000, 6094_800], [504_760, 6093_880]);
 @points_geo = $cs2cs->transform( @points_geo );
 
 $params = {-r => 1};  # control parameter -r: reverse input coords
 $cs2cs = Geo::LibProj::cs2cs->new("EPSG:4326" => "EPSG:25833", $params);
 $point = $cs2cs->transform( [q(15d4'28"E), q(54d59'30"N)] );
 # result easting, northing: [504763.08827, 6093866.63099]
 
 # old PROJ string syntax
 $source_crs = '+init=epsg:4326';
 $target_crs = '+proj=merc +lon_0=110';
 $cs2cs = Geo::LibProj::cs2cs->new($source_crs => $target_crs);
 ...

=head1 DESCRIPTION

This module is a Perl L<interprocess communication|perlipc> interface
to the L<cs2cs(1)|https://proj.org/apps/cs2cs.html> utility, which
is a part of the L<PROJ|https://proj.org/> coordinate transformation
library.

Unlike L<Geo::Proj4>, this module is pure Perl. It does require the
PROJ library to be installed, but it does not use the PROJ API
S<via XS>. Instead, it communicates with the C<cs2cs> utility using
the standard input/output streams, just like you might do at a
command line. Data is formatted using C<sprintf> and parsed using
regular expressions.

As a result, this module may be expected to work with many different
versions of the PROJ library, whereas L<Geo::Proj4> is limited to
S<version 4> (at time of this writing). However, this module is
definitely less efficient and possibly also less robust with regards
to potential changes to the C<cs2cs> input/output format.

This software has pre-release quality.
There is no schedule for further development.

=head1 METHODS

L<Geo::LibProj::cs2cs> implements the following methods.

=head2 new

 $cs2cs = Geo::LibProj::cs2cs->new($source_crs => $target_crs);

Construct a new L<Geo::LibProj::cs2cs> object that can transform
points from the specified source CRS to the target CRS (coordinate
reference system).

Each CRS may be specified using any method the PROJ version installed
on your system supports for the C<cs2cs> utility. The legacy "PROJ
string" format is currently supported on all PROJ versions:

 $source_crs = '+init=epsg:4326';
 $target_crs = '+proj=merc +lon_0=110';
 $cs2cs = Geo::LibProj::cs2cs->new($source_crs => $target_crs);

S<PROJ 6> and newer support additional formats to express a CRS,
such as a WKT string or an AUTHORITY:CODE. Note that the axis order
might differ between some of these choices. See your PROJ version's
L<cs2cs(1)|https://proj.org/apps/cs2cs.html> documentation for
details.

Control parameters may optionally be supplied to C<cs2cs> in a
hash ref using one of the following forms:

 $cs2cs = Geo::LibProj::cs2cs->new(\%params, $source_crs => $target_crs);
 $cs2cs = Geo::LibProj::cs2cs->new($source_crs => $target_crs, \%params);

Each of the C<%params> hash's keys represents a single control
parameter. Parameters are supplied exactly like in a C<cs2cs>
call on a command line, with a leading C<->. The value must be a
C<defined> value; a value of C<undef> will unset the parameter.

 %params = (
   -I => '',      # inverse ON (switch $source_crs and $target_crs)
   -f => '%.5f',  # output format (5 decimal digits)
   -r => undef,   # reverse coord input OFF (the default)
 );

See the L</"CONTROL PARAMETERS"> section below for implementation
details of specific control parameters.

=head2 transform

 $point_1 = [$x1, $y1];
 $point_2 = [$x2, $y2, $z2, $aux];
 @input_points  = ( $point_1, $point_2, ... );
 @output_points = $cs2cs->transform( @input_points );
 
 # transforming coordinates of just a single point:
 $output_point = $cs2cs->transform( [$x3, $y3, $z3] );

Execute C<cs2cs> to perform a CRS transformation of the specified
point or points. At least two coordinates (x/y) are required, a third
(z) may optionally be supplied.

Additionally, auxiliary data may be included in a fourth array
element. Just like C<cs2cs>, this value is simply passed through from
the input point to the output point. L<Geo::LibProj::cs2cs> doesn't
stringify this value for C<cs2cs>, so you can safely use Perl
references as auxiliary data, even blessed ones.

Coordinates are stringified for C<cs2cs> as numbers with I<at least>
the same precision as specified in the C<-f> control parameter.

Each point in a list is a simple unblessed array reference. When just
a single input point is given, C<transform()> may be called in scalar
context to directly obtain a reference to the output point. For lists
of multiple input points, calling in scalar context is prohibited.

=head2 version

 $version = Geo::LibProj::cs2cs->version;

Attempt to determine the version of PROJ installed on your system.

=head1 CONTROL PARAMETERS

L<Geo::LibProj::cs2cs> implements special handling for the following
control parameters. Parameters not mentioned here are passed on to
C<cs2cs> as-is. See your PROJ version's
L<cs2cs(1)|https://proj.org/apps/cs2cs.html> documentation for a
full list of supported options.

=head2 -d

 Geo::LibProj::cs2cs->new({-d => 7}, ...);

Fully supported shorthand to C<-f %f>. Specifies the number of
decimals in the output.

=head2 -f

 Geo::LibProj::cs2cs->new({-f => '%.7f'}, ...);

Fully supported (albeit with the limitations inherent in C<cs2cs>).
Specifies a printf format string to control the output values.

For L<Geo::LibProj::cs2cs>, the default value is currently C<'%.12g'>,
which allows easy further processing with Perl while keeping loss of
floating point precision low enough for any cartographic use case.
To enable the C<cs2cs> DMS string format (C<54d59'30.43"N>), you
need to explicitly unset this parameter by supplying C<undef>. This
will make C<cs2cs> use its built-in default format.

=head2 Unsupported parameters

 Geo::LibProj::cs2cs->new({-E => '' }, ...);  # fails
 Geo::LibProj::cs2cs->new({-t => '#'}, ...);  # fails
 Geo::LibProj::cs2cs->new({-v => '' }, ...);  # fails

The C<-E>, C<-t>, and C<-v> parameters disrupt parsing of the
transformation result and are unsupported.

=head2 XS

 Geo::LibProj::cs2cs->new({XS => 0}, ...);

There is a small chance that future versions of L<Geo::LibProj::cs2cs>
might automatically switch to an XS implementation if a suitable
third-party module is installed (such as L<Geo::Proj4>). This might
improve speed dramatically, but it might also change some of the
semantics of this module's interface in certain edge cases. If this
matters to you, you can already now opt out of this behaviour by
setting the internal parameter C<XS> to a defined non-truthy value.

=head1 ENVIRONMENT

The C<cs2cs> binary is expected to be on the environment's C<PATH>.
However, if L<Alien::proj> is available, its C<share> install will
be preferred.

If this doesn't suit you, can control the selection of the C<cs2cs>
binary by modifying the value of C<@Geo::LibProj::cs2cs::PATH>. The
directories listed will be tried in order, and the first match will
be used. An explicit value of C<undef> in the list will cause the
environment's C<PATH> to be used at that position in the search.
Note that these semantics are not yet finalised; they may change in
future.

=head1 DIAGNOSTICS

When C<cs2cs> detects data errors (such as an input value of
S<C<91dN> latitude>), it returns an error string in place of
the result coordinates. The error string can be controlled
by the S<C<-e> parameter> as described in the
L<cs2cs(1)|https://proj.org/apps/cs2cs.html> documentation.

L<Geo::LibProj::cs2cs> dies as soon as any other error condition is
discovered. Use C<eval>, L<Try::Tiny> or similar to catch this.

=head1 BUGS

To communicate with C<cs2cs>, this software uses L<IPC::Run3>.
Instead of directly interacting with the C<cs2cs> process, temp
files are created for every call to C<transform()>. This is probably
reliable, but slow.

The C<-l...> list parameters have not yet been implemented.

Please report new issues on GitHub.

=head1 SEE ALSO

L<Alien::proj>

=cut
