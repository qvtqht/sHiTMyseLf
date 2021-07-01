#!/usr/bin/perl
#
#
# groups items using nearby timestamps
# max interval is 1000 seconds
#
use strict;

use Digest::MD5 qw(md5_hex);

my $tims = `sqlite3 cache/b/index.sqlite3 "SELECT file_hash, add_timestamp FROM item_flat ORDER BY add_timestamp;"`;

my @timss = split("\n", $tims);

my $prevTim = 0;
my $items = '';
my $itemsCount = 0;
my $groupsCreatedCount = 0;

for my $tim (@timss) {
	#print $tim;
	my @timm = split('\|', $tim);
	my $item = $timm[0];
	my $tim = $timm[1];
	#my ($item, $tim) = split('|', $tim);

	if ($tim - $prevTim > 1000) {
		if ($items && $itemsCount > 1) {
			#my $newTag = '#' . substr(md5_hex($items), 0, 8);
			my $newTag = '#' . $tim;
			my $newText = $items . "\n\n#tims " .  $newTag;
			print $newText . "\n=====\n";
			$items = '';
			$itemsCount = 0;

			my $fileName = './html/txt/' . md5_hex($items) . ".txt";
			if (open(FH, '>', $fileName)) {
				print FH $newText;
				close(FH);
				system ("./index.pl $fileName");
				$groupsCreatedCount++;
			}
		}
	}

	$prevTim = $tim;
	$items .= ">>" . $item . "\n";
	$itemsCount++;
}

print "Done!";
print "\n";
print "=====";
print "\n";
print "Groups created: " . $groupsCreatedCount;