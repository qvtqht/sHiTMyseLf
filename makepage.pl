#!/usr/bin/perl -T

use strict;
use warnings;
use utf8;
use 5.010;

my @argsFound;
while (my $argFound = shift) {
	push @argsFound, $argFound;
}

#require('./utils.pl');
#require('./pages.pl');

sub GetGalleryPage {
	my $pageType = shift;

	my $boolLinkImage = 1;
	if ($pageType eq 'committee') {
		$boolLinkImage = 0;
	}

	#todo sanity

	my $html = '';

	if ($pageType =~ m/[^a-z]/) {
		WriteLog('MakePage: warning: sanity check failed, $pageType contains strange characters');
		return '';
	}

	my $title = GetString('menu/' . $pageType);

	$html = GetPageHeader($title, $title, $pageType);

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE ',' || tags_list || ',' LIKE '%," . $pageType . ",%'";
	$queryParams{'order_clause'} = "ORDER BY item_name";

	my $htmlImages = ''; # html with images

	my @items = DBGetItemList(\%queryParams);
	foreach my $item (@items) {
		if (length($item->{'item_title'}) > 48) {
			$item->{'item_title'} = substr($item->{'item_title'}, 0, 43) . '[...]';
		}
		my $itemImage = GetImageContainer($item->{'file_hash'}, $item->{'item_name'}, $boolLinkImage);
		$itemImage = AddAttributeToTag($itemImage, 'img', 'height', '100');
		$itemImage = GetWindowTemplate($itemImage, '');

		$htmlImages .= $itemImage;
		$htmlImages .= "<br><br><br>";
	}

	$htmlImages = '<center style="padding: 5pt">' . $htmlImages . '</center>';
	$html .= GetWindowTemplate('<tr><td>' . $htmlImages . '</td></tr>', GetString('menu/' . $pageType));

	$html .= GetPageFooter();
	$html = InjectJs($html, qw(settings utils));

	return $html;
}

sub MakeGalleryPage {
	my $pageType = shift;

	my $pageFile = $pageType . '.html';

	WriteLog('MakeGalleryPage: $pageType = ' . $pageType . '; $pageFile = ' . $pageFile);

	PutHtmlFile($pageType . '.html', GetGalleryPage($pageType));
}

sub MakePage { # $pageType, $pageParam, $htmlRoot ; make a page and write it into $HTMLDIR directory; $pageType, $pageParam
# supported page types so far:
# tag, #hashtag
# author, ABCDEF01234567890
# item, 0123456789abcdef0123456789abcdef01234567
# authors
# read
# prefix
# summary (deprecated)
# tags
# stats
# index
# compost

	state $HTMLDIR;
	if (!$HTMLDIR) {
		$HTMLDIR = GetDir('html');
	}

	# $pageType = author, item, tags, etc.
	# $pageParam = author_id, item_hash, etc.
	my $pageType = shift;
	my $pageParam = shift;
	my $htmlRoot = shift;

	if ($htmlRoot) {
		$HTMLDIR = $htmlRoot;
	}

	#todo sanity checks

	if (!defined($pageParam)) {
		$pageParam = 0;
	}

	WriteMessage('MakePage(' . $pageType . ', ' . $pageParam . ')');

	# tag page, get the tag name from $pageParam
	if ($pageType eq 'tag') {
		my $tagName = $pageParam;
		my $targetPath = "top/$tagName.html";

		WriteLog("MakePage: tag: $tagName");
		my $tagPage = GetReadPage('tag', $tagName);
		PutHtmlFile($targetPath, $tagPage);
	}

	elsif ($pageType eq 'academic') {
		MakeGalleryPage('academic');
	} #academic

	elsif ($pageType eq 'media') {
		MakeGalleryPage('media');
	} #media

	elsif ($pageType eq 'speakers') {
		my $speakersPage = '';
		$speakersPage = GetPageHeader('Speakers', 'Speakers', 'speakers');

		my %queryParams;
		$queryParams{'where_clause'} = "WHERE tags_list LIKE '%speaker%'";
		$queryParams{'order_clause'} = "ORDER BY file_name";
#		$queryParams{'where_clause'} = "WHERE tags_list LIKE '%speaker%'";

		my @itemSpeakers = DBGetItemList(\%queryParams);
		foreach my $itemSpeaker (@itemSpeakers) {
			#$itemSpeaker->{'item_title'} = $itemSpeaker->{'item_name'};
			if (length($itemSpeaker->{'item_title'}) > 48) {
				$itemSpeaker->{'item_title'} = substr($itemSpeaker->{'item_title'}, 0, 45) . '[...]';

			}
			$itemSpeaker->{'item_statusbar'} = GetItemHtmlLink($itemSpeaker->{'file_hash'}, $itemSpeaker->{'item_title'});
			my $itemSpeakerTemplate = GetItemTemplate($itemSpeaker);
			$speakersPage .= $itemSpeakerTemplate;
		}

		$speakersPage .= GetPageFooter();
		$speakersPage = InjectJs($speakersPage, qw(settings utils));
		PutHtmlFile('speakers.html', $speakersPage);
	}

	elsif ($pageType eq 'links') {
		MakeSimplePage('links');
#		my $linksPage = '';
#		$linksPage = GetPageHeader('Links', 'Links', 'links');
#
#		my %queryParams;
#		$queryParams{'where_clause'} = "WHERE file_hash IN ( SELECT file_hash FROM item_attribute WHERE attribute = 'url' )";
#
#		my @itemLinks = DBGetItemList(\%queryParams);
##		foreach my $itemLink (@itemLinks) {
##			my $itemLinkTemplate = GetItemTemplate($itemLink);
##			$linksPage .= $itemLinkTemplate;
##		}
#		$linksPage .= GetQueryAsDialog("Select item_title from item_flat where tags_list like '%url%'");
#
#		$linksPage .= GetPageFooter();
#		$linksPage = InjectJs($linksPage, qw(settings utils));
#		PutHtmlFile('links.html', $linksPage);
	}
	elsif ($pageType eq 'committee') {
		my $committeePage = '';
		$committeePage = GetPageHeader('Committee', 'Committee', 'committee');

		my %queryParams;
		$queryParams{'where_clause'} = "WHERE tags_list LIKE '%committee%'";
		$queryParams{'order_clause'} = "ORDER BY item_order";

		my @itemCommittee = DBGetItemList(\%queryParams);
		foreach my $itemCommittee (@itemCommittee) {
			if (GetConfig('admin/mit_expo_mode')) {
				if ($itemCommittee->{'item_name'} eq 'Manish Kumar') {
					#expo mode #todo #bandaid
					$itemCommittee->{'item_title'} = 'Hackathon Co-Chair';
				}
			}
			if (length($itemCommittee->{'item_title'}) > 48) {
				$itemCommittee->{'item_title'} = substr($itemCommittee->{'item_title'}, 0, 43) . '[...]';
			}
			if (!GetConfig('admin/expo_site_edit')) {
				$itemCommittee->{'no_permalink'} = 1;
			}
			my $itemCommitteeTemplate = GetItemTemplate($itemCommittee);
			$committeePage .= $itemCommitteeTemplate;
		}

		$committeePage .= GetPageFooter();
		$committeePage = InjectJs($committeePage, qw(settings utils));
		PutHtmlFile('committee.html', $committeePage);
	}
	elsif ($pageType eq 'sponsors') {
		my $sponsorsPage = '';
		$sponsorsPage = GetPageHeader('Sponsors', 'Sponsor', 'sponsors');

		foreach my $sponsorLevel (qw(gold silver)) {
			my %queryParams;
			$queryParams{'where_clause'} = "WHERE tags_list LIKE '%sponsor%' AND tags_list like '%$sponsorLevel%'";
			$queryParams{'order_clause'} = "ORDER BY file_name";

			my $sponsorsImages = '';

			my @itemSponsors = DBGetItemList(\%queryParams);
			foreach my $itemSponsor (@itemSponsors) {
				if (length($itemSponsor->{'item_title'}) > 48) {
					$itemSponsor->{'item_title'} = substr($itemSponsor->{'item_title'}, 0, 43) . '[...]';
				}
				my $sponsorImage = GetImageContainer($itemSponsor->{'file_hash'}, $itemSponsor->{'item_name'});
				$sponsorImage = AddAttributeToTag($sponsorImage, 'img', 'height', '100');
				$sponsorImage = GetWindowTemplate($sponsorImage, '');
				$sponsorsImages .= $sponsorImage;
				$sponsorsImages .= "<br><br><br>";
				#my $itemSponsorTemplate = GetItemTemplate($itemSponsor);
				#$sponsorsPage .= $itemSponsorTemplate;
			}

			$sponsorsImages = '<center style="padding: 5pt">' . $sponsorsImages . '</center>';
			$sponsorsPage .= GetWindowTemplate('<tr><td>' . $sponsorsImages . '</td></tr>', ucfirst($sponsorLevel) . ' Sponsors');

			$sponsorsPage .= "<br><br>";
		}

		$sponsorsPage .= GetPageFooter();
		$sponsorsPage = InjectJs($sponsorsPage, qw(settings utils));

		PutHtmlFile('sponsors.html', $sponsorsPage);
	} #sponsors
	#
	# author page, get author's id from $pageParam
	elsif ($pageType eq 'author') {
		if ($pageParam =~ m/^([0-9A-F]{16})$/) {
			$pageParam = $1;
		} else {
			WriteLog('MakePage: author: warning: $pageParam sanity check failed. returning');
			return '';
		}

		my $authorKey = $pageParam;
		my $targetPath = "author/$authorKey/index.html";

		WriteLog('MakePage: author: ' . $authorKey);

		my $authorPage = GetReadPage('author', $authorKey);
		if (!-e "$HTMLDIR/author/$authorKey") {
			mkdir ("$HTMLDIR/author/$authorKey");
		}
		PutHtmlFile($targetPath, $authorPage);

		if (IsAdmin($authorKey) == 2) {
			MakeSummaryPages();
		}
	}
	#
	# if $pageType eq item, generate that item's page
	elsif ($pageType eq 'item') {
		# get the item's hash from the param field
		my $fileHash = $pageParam;

		# get item page's path #todo refactor this into a function
		#my $targetPath = $HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2) . '.html';
		my $targetPath = GetHtmlFilename($fileHash);

		# get item list using DBGetItemList()
		# #todo clean this up a little, perhaps crete DBGetItem()
		my @files = DBGetItemList({'where_clause' => "WHERE file_hash LIKE '$fileHash%'"});

		if (scalar(@files)) {
			my $file = $files[0];
			if ($HTMLDIR =~ m/^(^\s+)$/) { #security #taint #todo
				$HTMLDIR = $1; # untaint
				# create a subdir for the first 2 characters of its hash if it doesn't exist already
				if (!-e ($HTMLDIR . '/' . substr($fileHash, 0, 2))) {
					mkdir(($HTMLDIR . '/' . substr($fileHash, 0, 2)));
				}
				if (!-e ($HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2))) {
					mkdir(($HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2)));
				}
			}

			# get the page for this item and write it
			WriteLog('MakePage: my $filePage = GetItemPage($file = "' . $file . '")');
			my $filePage = GetItemPage($file);
			WriteLog('PutHtmlFile($targetPath = ' . $targetPath . ', $filePage = ' . $filePage . ')');
			PutHtmlFile($targetPath, $filePage);
		} else {
			WriteLog("pages.pl: item page: warning: Asked to index file $fileHash, but it is not in the database! Returning.");
		}
	} #item page

	elsif ($pageType eq 'tags') { #tags page
#		my $tagsPage = GetTagsPage('Tags', 'Tags', '');
		my $tagsPage = GetQueryPage('tags');
		PutHtmlFile("tags.html", $tagsPage);

		my $votesPage = GetTagsPage('Votes', 'Votes', 'ORDER BY vote_value');
		PutHtmlFile("votes.html", $votesPage);

		my $tagsHorizontal = GetTagLinks();
		PutHtmlFile('tags-horizontal.html', $tagsHorizontal);
	}
#	#
#	# events page
#	elsif ($pageType eq 'events') {
#		my $eventsPage = GetEventsPage();
#		PutHtmlFile("events.html", $eventsPage);
#	}
	#
	# authors page
	elsif ($pageType eq 'authors') {
		#my $authorsPage = GetAuthorsPage();
		my $authorsPage = GetQueryPage('authors');
		PutHtmlFile("authors.html", $authorsPage);
	}
	#
	# topitems page
	elsif ($pageType eq 'read') {
		my $topItemsPage = GetQueryPage('read', 'Top Threads', 'item_title,author_key,add_timestamp');
#		my $topItemsPage = GetTopItemsPage();
		PutHtmlFile("read.html", $topItemsPage);
	}
	elsif ($pageType eq 'compost') {
		my $compostPage = GetQueryPage('compost');
#		my $compostPage = GetQueryPage('compost', 'Compost', 'item_title,author_key,add_timestamp');
#		my $topItemsPage = GetTopItemsPage();
		PutHtmlFile("compost.html", $compostPage);
	}
	elsif ($pageType eq 'agenda') {
		my $agendaPage = '';
		$agendaPage .= GetPageHeader('agenda', 'agenda', 'agenda');
		$agendaPage .= GetWindowTemplate(GetTemplate('html/page/agenda_saturday.template'), 'Saturday');
		$agendaPage .= GetWindowTemplate(GetTemplate('html/page/agenda_sunday.template'), 'Sunday');
		$agendaPage .= GetPageFooter();
		PutHtmlFile('agenda.html', $agendaPage);
#		MakeGalleryPage('agenda-saturday');
#		MakeGalleryPage('agenda-sunday');

#		PutHtmlFile("agenda.html", $agendaPage);
#		PutHtmlFile("agenda-saturday.html", GetQueryPage('agenda_saturday'));
#		PutHtmlFile("agenda-sunday.html", GetQueryPage('agenda_sunday'));
	}
	elsif ($pageType eq 'deleted') {
		my $agendaPage = GetQueryPage('deleted');
		PutHtmlFile("deleted.html", $agendaPage);
	}
	elsif ($pageType eq 'settings') {
		# Settings page
		my $settingsPage = GetSettingsPage();
		PutHtmlFile("settings.html", $settingsPage);
	}
	#
	# stats page
	elsif ($pageType eq 'stats') {
		PutStatsPages();
	}
	#
	# index pages (queue)
	elsif ($pageType eq 'index') {
		my $touchIndexPages = GetCache('touch/index_pages');
		if (!$touchIndexPages) {
			$touchIndexPages = 0;
		}
		if ((time() - $touchIndexPages) > 1) {
			#do nothing
		} else {
			WriteIndexPages();
			PutCache('touch/index_pages', time());
		}
	}
	#
	# item prefix page
	elsif ($pageType eq 'prefix') {
		my $itemPrefix = $pageParam;
		my $itemsPage = GetItemPrefixPage($itemPrefix);
		PutHtmlFile(substr($itemPrefix, 0, 2) . '/' . substr($itemPrefix, 2, 2) . '/index.html', $itemsPage);
	}
	#
	# profile
	elsif ($pageType eq 'profile') {
		# Profile page
		my $profilePage = GetProfilePage();
		PutHtmlFile("profile.html", $profilePage);
	}
	#
	# rss feed
	elsif ($pageType eq 'rss') {
		#todo break out into own module and/or auto-generate rss for all relevant pages

		my %queryParams;

		$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';
		$queryParams{'limit_clause'} = 'LIMIT 200';
		my @rssFiles = DBGetItemList(\%queryParams);

		PutFile("$HTMLDIR/rss.xml", GetRssFile(@rssFiles));
	}
	#
	# summary pages
	elsif ($pageType eq 'summary') {
		MakeSummaryPages();
	}

	WriteLog("MakePage: finished, calling DBDeletePageTouch($pageType, $pageParam)");
	DBDeletePageTouch($pageType, $pageParam);
} # MakePage()

1;