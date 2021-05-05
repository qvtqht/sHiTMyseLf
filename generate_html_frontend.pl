#!/usr/bin/perl -T
#freebsd: #!/usr/local/bin/perl -T

use strict;
use 5.010;
use utf8;

require './pages.pl';
MakeSummaryPages();
BuildTouchedPages();

1;
