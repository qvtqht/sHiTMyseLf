SHITMYSELF
==========
Message board which aims to please.
At least 30 times slower than Hugo.

   * * *

SUPPORTED ENVIRONMENTS
======================
As stated above, sHiTMyseLf aims to please, and make do with whatever you got.

Frontend Tested With:
=====================
Mozilla Firefox
Chrome
Chromium
Bromite (Android)
Samsung Browser (Android)
qutebrowser
Links
Lynx
w3m
Mosaic 1*, 2*, 3*
Opera 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
Netscape 2*, 3, 4
Internet Explorer 2*, 3, 4, 5.5, 6, 7, 8, 9, 10, 11
curl
wget
NetSurf
OffByOne
Safari (iOS) 7, 8, 9, 10, 11, 12, 13
Safari (Mac)
Safari (Windows) 1, 2, 3, 4, 5
Some kind of in-TV browser with no monospace font!

Frontend Notes:
===============
Some browsers, marked with *, require special accommodations.
Not every feature is supported by every browser.
Not every minor version was tested.
Many browsers support very few features.
However, with prior knowledge of system,
Reading, writing, voting was done successfully.

   * * *

Frontend Testers Wanted:
========================
WorldWideWeb
Amaya
Telnet
iOS Safari older than 7.x
Android Browser
any other browsers not mentioned

Building/Backend Tested With:
=============================
Fedora
Mint
Ubuntu
Debian
DreamHost
Mac OS X
macOS
FreeBSD

Installation Testers Wanted:
============================
OpenBSD
NetBSD
Windows
Cloud services

   * * *

STACK DESCRIPTION
=================
Hopefully this is reasonably easy to acquire.

Client
======
Web browser or HTML viewer
Text editor

Server
======
POSIX/GNU/*nix
Perl 5.010+
git
sqlite3

Perl Modules
============
URI::Encode
URI::Escape
HTML::Parser
Digest::MD5
Digest::SHA1
File::Spec
DBI
DBD::SQLite

Optional Components
===================
* Web Server
* access.log
* tar
* gzip
* zip
* gpg
* ImageMagick
* SSI
* PHP

   * * *

PACKAGE INSTALLATION
====================
No third-party package manager should be necessary.

Ubuntu, Debian, Mint, Trisquel, Ubuntu, and other apt-based
==========================================================================
# apt-get install liburi-encode-perl libany-uri-escape-perl libhtml-parser-perl libdbd-sqlite3-perl libdigest-sha-perl sqlite3 gnupg gnupg2 imagemagick php-cgi zip

Redhat, CentOS, Fedora, and other yum-based
============================================================
# yum install perl-Digest-MD5 perl-Digest-SHA perl-HTML-Parser perl-DBD-SQLite perl-URI-Encode perl-Digest-SHA1 sqlite gnupg gnupg2 perl-Devel-StackTrace perl-Digest-SHA perl-HTML-Parser perl-DBD-SQLite lighttpd-fastcgi ImageMagick php-cgi

FreeBSD
=======
# pkg install lighttpd sqlite3 perl

   * * *

INSTALLATION FOR LOCAL TESTING
==============================
$ cd ~
$ git clone https://www.github.com/qvthqt/shitmyself hike
$ cd ~/hike
$ ./install.pl
$ ./build.pl

TROUBLESHOOTING
===============
If you get an error about the version of SQLite library during build, do this:
   $ cd ~/hike
   $ rm -rvf ./lib/

LOCAL ADMINISTRATION
====================
Publish an item with some text:
   $ echo "hello, world" > html/txt/hello.txt
   $ ./update.pl

Publish profile:
   $ gpg --armor --export > ./html/txt/my_profile.txt
   $ ./update.pl

Sign and publish some text:
   $ echo "hello, world" > my_post.txt
   $ gpg --clearsign my_post.txt > ./html/txt/my_post.txt

Rebuild frontend if you changed a setting:
   $ ./generate.pl

View the page generation queue:
   $ ./query/page_touch.sh

Archive all the content and start afresh:
   $ ./archive.pl


DEPLOYMENT USING APACHE, LIGHTTPD, OR NGINX
===========================================
WARNING: THESE INSTRUCTIONS ASSUME YOU KNOW WHAT YOU'RE DOING.
   Do not deploy unless you know what you're doing.
   This code has not been audited, nor thoroughly tested.

Other Asumptions
================
Assuming you already installed as instructed above.
Assuming "." is project directory
Assuming "access.log" is NCSA standard
Assuming platform is GNU/Linux

If you're using the access.log update methods
=============================================
1. Symlink log/access.log to wherever your access log lives:

   $ ln -s ./log/access.log /var/log/www/access.log

   Access log is read non-destructively, and should be rotated.
   Hashed lines are stored in log/processed.log after done.

2. Symlink html root to html/

   $ rmdir /var/www/html
   $ ln -s ./html /var/www/html

3. Depending which modules are you are planning to use, set the following settings.

   Each setting is its own plaintext file containing 0 or 1.
   Other values may resolve unpredictably.
   Removing the file will result in it being reset to default.
   Defaults live in similar structure under ./default/ directory.
   Note: PHP and SSI may not work together.

   PHP module: ./config/admin/php/enable
   SSI module: ./config/admin/ssi/enable
   Frontend JavaScript module: ./config/admin/js/enable
   Images module: ./config/admin/image/enable

4. If you are using neither PHP, nor SSI, updating site requires running update.pl

   You can add it to your crontab if you like.
   You can limit the script's runtime:
      ./config/admin/update/limit_time
      contains a limit on how long this script will run, in seconds

Note
====
Not using PHP and SSI can lower the attack surface of your installation.
   The tradeoff is convenience and usability:
      Users won't see their actions take effect right away.

UPGRADING
=========
Upgrade process duration is proportionate to the amount of data already stored.
New versions may introduce incompatibilities, but system should remain operable.
Eventually, faster and more efficient upgrading should be possible.

Upgrade the code, keep the data and config, and rebuild everything else:

$ git pull --all
$ ./clean.sh          # remove html files, cache, index
$ ./build.pl          # after this, site should be up and accessible
$ ./update.pl --all   # re-import everything and rebuild site

ROLLBACK
========
Installing a version different from most recent:

$ git checkout 0123abcd
$ ./clean.sh
$ ./build.pl
$ ./update.pl --all

repl.it development
===================
In testing, largely working except for the lack of DBD::DBSQLite library

KNOWN ISSUES
============
See known.txt

CONFIG and TEMPLATES
====================
Both configuration and various templates are stored in...

./config/
	Edit configuration here
	Only values looked up at least once appear here
	If this is empty, run ./build.pl

./default/
	Do NOT edit this for configuring
	May be overwritten during upgrade
	Part of the repository
	This is for developer
	Provides defaults
	Same structure as config above

Most values are 0/1 boolean or one-liners
Config is handled using one file per setting.
To change a setting, edit the file in config/
config/admin/debug is special, delete file to 0













































































































































































































































































































