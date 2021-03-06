Geo::LibProj::cs2cs
===================

This distribution is a Perl [interprocess communication][]
interface to the [`cs2cs`][] utility, which is a part of the
[PROJ][] coordinate transformation library.

Unlike [Geo::Proj4][], this module is pure Perl. It does require the
PROJ library to be installed, but it does not use the PROJ API
via XS. Instead, it communicates with the `cs2cs` utility using
the standard input/output streams, just like you might do at a
command line. Data is formatted using `sprintf` and parsed using
regular expressions.

As a result, this module may be expected to work with many different
versions of the PROJ library, whereas [Geo::Proj4][] is limited to
version 4 (at time of this writing). However, this module is
definitely less efficient and possibly also less robust with regards
to potential changes to the `cs2cs` input/output format.

[interprocess communication]: https://perldoc.perl.org/perlipc.html
[`cs2cs`]: https://proj.org/apps/cs2cs.html
[PROJ]: https://proj.org/
[Geo::Proj4]: https://metacpan.org/pod/Geo::Proj4


Installation
------------

Released versions of [Geo::LibProj::cs2cs][] may be installed via CPAN:

	cpanm Geo::LibProj::cs2cs

[![CPAN distribution](https://badge.fury.io/pl/Geo-LibProj-cs2cs.svg)](https://badge.fury.io/pl/Geo-LibProj-cs2cs)

To install a development version from this repository, run the following steps:

 1. `git clone https://github.com/johannessen/cs2cs-perl && cd cs2cs-perl`
 1. `dzil build` (requires [Dist::Zilla][])
 1. `cpanm <archive>.tar.gz`

[Geo::LibProj::cs2cs]: https://metacpan.org/release/Geo-LibProj-cs2cs
[Dist::Zilla]: https://metacpan.org/release/Dist-Zilla
