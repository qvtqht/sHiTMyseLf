#!/usr/bin/perl -T
#freebsd: #!/usr/local/bin/perl -T

use strict;
use utf8;
use Cwd qw(cwd);

sub BuildMessage { # prints timestamped message to output
	print ' ';
	print "\n";
	print time();
	print ': ';
	print shift;
	print "\n";
} # BuildMessage()

BuildMessage "Require ./utils.pl...";
require './gpgpg.pl';
require './utils.pl';

#EnsureDirsThatShouldExist();

#CheckForInstalledVersionChange();

#CheckForRootAdminChange();

require './index.pl';


{ # build the sqlite db if not available
	# BuildMessage "SqliteUnlinkDB()...";
	# SqliteUnlinkDb();
	#
	BuildMessage "SqliteConnect()...";
	SqliteConnect();

	BuildMessage "SqliteMakeTables()...";
	SqliteMakeTables();
#
#	BuildMessage "Remove cache/indexed/*";
#	system('rm cache/*/indexed/*');
}


my $SCRIPTDIR = cwd();
my $HTMLDIR = $SCRIPTDIR . '/html';
my $TXTDIR = $HTMLDIR . '/txt';
my $IMAGEDIR = $HTMLDIR . '/txt';

BuildMessage "Ensure there's $HTMLDIR and something inside...";
if (!-e $TXTDIR) {
	# create $TXTDIR directory if it doesn't exist
	mkdir($TXTDIR);
}

if (!-e $IMAGEDIR) {
	# create $IMAGEDIR directory if it doesn't exist
	mkdir($IMAGEDIR);
}

BuildMessage "Looking for files...";

#BuildMessage "MakeChainIndex()...";
#MakeChainIndex();

BuildMessage "DBAddPageTouch('summary')...";
DBAddPageTouch('system');

BuildMessage("UpdateUpdateTime()...");
UpdateUpdateTime();

#BuildMessage "require('./pages.pl')...";
#require './pages.pl';

#BuildMessage "Calling MakeSystemPages()...";

#PutHtmlFile("/index.html", '<a href="/write.html">write.html</a>');
#MakeSystemPages();
#PutHtmlFile("/index.html", GetFile('html/help.html'));

PutFile('config/admin/build_end', GetTime());

if (!GetConfig('admin/secret')) {
	PutConfig('admin/secret', md5_hex(time()));
}

if (GetConfig('admin/dev/launch_browser_after_build')) {
	WriteLog('build.pl: xdg-open http://localhost:2784/ &');
	WriteLog(`xdg-open http://localhost:2784/ &`);
}

if (GetConfig('admin/ssi/enable') && GetConfig('admin/php/enable')) {
	BuildMessage('build.pl: warning: ssi/enable and php/enable are both true');
}

BuildMessage("===============");
BuildMessage("Build finished!");
BuildMessage("===============");
WriteLog("Finished!");

if (GetConfig('admin/lighttpd/enable')) {
	system('screen -d -m -S perl ./server_local_lighttpd.pl');
}

1;
