#!perl
use strict;
use warnings;
use lib qw(lib);

use Geo::Proj5::cs2cs;
my $proj_available;


use Test::More 0.96 tests => 6 + 1;
use Test::Exception;
use Test::Warnings;


my ($c, $p, @p);


$Geo::Proj5::cs2cs::CMD = 'true';
@Geo::Proj5::cs2cs::PATH = ('/does/not/exist?', undef);
lives_ok { $p = 0; $p = Geo::Proj5::cs2cs->_cmd; } 'cmd lives (undef)';
like $p, qr/true/, 'cmd found (undef)';

@Geo::Proj5::cs2cs::PATH = ('/does/not/exist?', '/bin', '/usr/bin');
lives_ok { $p = 0; $p = Geo::Proj5::cs2cs->_cmd; } 'cmd lives (path)';
like $p, qr/true/, 'cmd found (path)';

$Geo::Proj5::cs2cs::CMD = 'cat';
@Geo::Proj5::cs2cs::PATH = (undef);
lives_ok { $p = 0; $p = Geo::Proj5::cs2cs->_cmd; } 'cmd lives (cat)';
like $p, qr/cat/, 'cmd found (cat)';


done_testing;
