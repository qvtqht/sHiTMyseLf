#!/usr/bin/perl -T

use strict;
use warnings;
use utf8;
use 5.010;

my @foundArgs;
while (my $argFound = shift) {
	push @foundArgs, $argFound;
}

use lib qw(lib);
#use HTML::Entities qw(encode_entities);
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime ceil);
use Data::Dumper;
use File::Copy;
# use File::Copy qw(copy);
use Cwd qw(cwd);

#require './utils.pl';
#require './makepage.pl';

sub GetHtmlToolbox {
# 'toolbox' >toolbox<
	my $fileHashRef = shift;
	my %file;
	if ($fileHashRef) {
		%file = %{$fileHashRef};
	}

	my $htmlToolbox = '';

	my $urlParam = '';
	if ($file{'item_title'}) {
		$urlParam = $file{'item_title'};
		#$urlParam = uri_encode($urlParam);
		$urlParam = str_replace(' ', '+', $urlParam);
	}

	if ($urlParam && $urlParam ne 'Untitled') {
		$htmlToolbox .= '<b>Search:</b><br>';

		$htmlToolbox .=
			'<a href="http://www.google.com/search?q=' .
			$urlParam .
			'"' .
			'target=_blank' .
			'>' .
			'Google' .
			'</a><br>'
		;

		$htmlToolbox .=
			'<a href="http://html.duckduckgo.com/html?q=' .
			$urlParam .
			'">' .
			'DuckDuckGo' .
			'</a><br>'
		;
		$htmlToolbox .=
			'<a href="https://search.brave.com/search?q=' .
			$urlParam .
			'">' .
			'Brave' .
			'</a><br>'
		;
#			$htmlToolbox .=
#				'<a href="http://yandex.ru/yandsearch?text=' .
#				$urlParam .
#				'">' .
#				'Yandex' .
#				'</a><br>'
		;
		$htmlToolbox .=
			'<a href="https://teddit.net/r/all/search?q=' .
			$urlParam .
			'&nsfw=on' .
			'">' .
			'Teddit' .
			'</a><br>'
		;
		$htmlToolbox .=
			'<a href="http://www.google.com/search?q=' .
			$urlParam .
			'+teddit"' .
			'target=_blank' .
			'>' .
			'Google+Teddit' .
			'</a><br>'
		;
		$htmlToolbox .=
			'<a href="https://hn.algolia.com/?q=' .
			$urlParam .
			'">' .
			'A1go1ia' .
			'</a><noscript>*</noscript><br>'
		;
		$htmlToolbox .=
			'<a href="https://en.wikipedia.org/w/index.php?search=' .
			$urlParam .
			'">' .
			'Wikipedia EN' .
			'</a><br>'
		;
		$htmlToolbox .=
			'<a href="https://ru.wikipedia.org/w/index.php?search=' .
			$urlParam .
			'">' .
			'Wikipedia RU' .
			'</a><br>'
		;
		$htmlToolbox .=
			'<a href="https://tildes.net/search?q=' .
			$urlParam .
			'">' .
			'Tildes' .
			'</a><br>'
		;
		$htmlToolbox .=
			'<a href="https://lobste.rs/search?q=' .
			$urlParam .
			'&what=stories&order=relevance' .
			'">' .
			'Lobsters' .
			'</a><br>'
		;


		$htmlToolbox .= "<p>";
		$htmlToolbox .= "<b>Share:</b><br>";

		$htmlToolbox .=
			# http://twitter.com/share?text=text goes here&url=http://url goes here&hashtags=hashtag1,hashtag2,hashtag3
			# https://stackoverflow.com/questions/6208363/sharing-a-url-with-a-query-string-on-twitter

			'<a href="http://twitter.com/share?text=' .
			$urlParam .
			'">' .
			'Twitter' .
			'</a><br>'
		;

		$htmlToolbox .=
			# https://www.facebook.com/sharer/sharer.php?u=http://example.com?share=1&cup=blue&bowl=red&spoon=green
			# https://stackoverflow.com/questions/19100333/facebook-ignoring-part-of-my-query-string-in-share-url

			'<a href="https://www.facebook.com/sharer/sharer.php?u=' . # what does deprecated mean?
			$urlParam .
			'">' .
			'Facebook' .
			'</a><br>'
		;
	} # if ($file{'item_title'})


	my $urlParamFullText = '';
	if ($file{'file_path'} && $file{'item_type'} eq 'txt') {
		$urlParamFullText = $file{'file_path'};
		$urlParamFullText = GetFile($urlParamFullText);
		$urlParamFullText = uri_encode($urlParamFullText);
		$urlParamFullText = str_replace('+', '%2b', $urlParamFullText);
		$urlParamFullText = str_replace('#', '%23', $urlParamFullText);
		#todo other chars like ? & =
	}

	if (
		GetConfig('html/item_toolbox/show_publish_options') &&
		$urlParamFullText &&
		length($urlParamFullText) < 2048
	) {

		$htmlToolbox .= "<p>";
		$htmlToolbox .= '<b>Publish:</b><br>';

		#$htmlToolbox = GetPublishButton('localhost:2784', $file{'file_path'});

		$htmlToolbox .=
			'<a href="http://localhost:2784/post.html?comment=' .
			$urlParamFullText .
			'">' .
			'localhost:2784' .
			'</a><br>';

		$htmlToolbox .=
			'<a href="http://gitara.club/post.html?comment=' .
			$urlParamFullText .
			'">' .
			'gitara' .
			'</a><br>';

		$htmlToolbox .=
			'<a href="http://localhost:31337/post.html?comment=' .
			$urlParamFullText .
			'">' .
			'diary' .
			'</a><br>';

		$htmlToolbox .=
			'<a href="http://www.shitmyself.com/post.html?comment=' .
			$urlParamFullText .
			'">' .
			'sHiTMyseLf' .
			'</a><br>';

		$htmlToolbox .=
			'<a href="http://qdb.us/post.html?comment=' .
			$urlParamFullText .
			'">' .
			'qdb.us' .
			'</a><br>'
		;
	} else {
		$htmlToolbox .= "";
	}


	if ($htmlToolbox) {
		my $htmlToolboxWindow = '<span class=advanced>' . GetWindowTemplate($htmlToolbox, 'Tools') . '</span>';
		return $htmlToolboxWindow;
	}
} # GetHtmlToolbox()

sub GetItemPage { # %file ; returns html for individual item page. %file as parameter
	# %file {
	#		file_hash = git's file hash
	#		file_path = path where text file is stored
	#		item_title = title, if any
	#		author_key = author's fingerprint
	#		vote_buttons = 1 to display vote buttons
	#		display_full_hash = 1 to display full hash for permalink (otherwise shortened)
	#		show_vote_summary = 1 to display all votes recieved separately from vote buttons
	#		show_quick_vote = 1 to display quick vote buttons
	#		format_avatars = 1 to format fingerprint-looking strings into avatars
	#		child_count = number of child items for this item
	#		template_name = name of template to use (item.template is default)
	#		remove_token = reply token to remove from message (used for displaying replies)
	#	}

	# we're expecting a reference to a hash as the first parameter
	#todo sanity checks here, it will probably break if anything else is supplied
	# keyword: ItemInfo {
	my %file = %{shift @_};

	# create $fileHash and $filePath variables, since we'll be using them a lot
	my $fileHash = $file{'file_hash'};
	my $filePath = $file{'file_path'};

	WriteLog("GetItemPage(file_hash = " . $file{'file_hash'} . ', file_path = ' . $file{'file_path'} . ")");

	# initialize variable which will contain page html
	my $txtIndex = "";

	my $title = '';     # title for <title>
	my $titleHtml = ''; # title for <h1>

	{
		my $debugOut = '';
		foreach my $key (keys (%file)) {
			$debugOut .= '$file{' . $key . '} = ' . ($file{$key} ? $file{$key} : 'FALSE');
			$debugOut .= "\n";
		}
		WriteLog('GetItemPage: ' . $debugOut);
	}

	if (defined($file{'item_name'}) && $file{'item_name'}) {
		WriteLog("GetItemPage: defined(item_name) = true!");
		$title = HtmlEscape($file{'item_name'});
		$titleHtml = HtmlEscape($file{'item_name'});
		#$title .= ' (' . substr($file{'item_name'}, 0, 8) . '..)';
	}
	elsif (defined($file{'item_title'}) && $file{'item_title'}) {
		WriteLog("GetItemPage: defined(item_title) = true!");
		$title = HtmlEscape($file{'item_title'});
		$titleHtml = HtmlEscape($file{'item_title'});
		#$title .= ' (' . substr($file{'file_hash'}, 0, 8) . '..)';
	}
	else {
		WriteLog("GetItemPage: defined(item_title) = false!");
		$title = $file{'file_hash'};
		$titleHtml = $file{'file_hash'};
	}

	if (defined($file{'author_key'}) && $file{'author_key'}) {
		#todo the .txt extension should not be hard-coded
		my $alias = GetAlias($file{'author_key'});
		if ($alias) {
			$alias = HtmlEscape($alias);
			$title .= " by $alias";
		} else {
			WriteLog('GetItemPage: warning: author_key was defined, but $alias is FALSE');
			#$alias = '...';
			#$title .= ' by ...'; #guest...
			$alias = 'Guest';
			$title .= ' by Guest';
		}
	}

	$file{'display_full_hash'} = 1;
	$file{'show_vote_summary'} = 1;
	# $file{'show_quick_vote'} = 1;
	$file{'vote_buttons'} = 1;
	$file{'format_avatars'} = 1;
	if (!$file{'item_title'}) {
		$file{'item_title'} = 'Untitled';
	}
	$file{'show_easyfind'} = 0;
	$file{'image_large'} = 1;

	##########################
	## HTML MAKING BEGINS

	# Get the HTML page template
	my $htmlStart = GetPageHeader($title, $titleHtml, 'item');
	$txtIndex .= $htmlStart;
	if (GetConfig('admin/expo_site_mode')) {
		#$txtIndex .= GetMenuTemplate(); # menu at the top on item page
	}
	$txtIndex .= GetTemplate('html/maincontent.template');




	# ITEM TEMPLATE
	my $itemTemplate = GetItemTemplate(\%file); # GetItemPage()
	WriteLog('GetItemPage: child_count: ' . $file{'file_hash'} . ' = ' . $file{'child_count'});

	# EASY FIND
	if ($file{'show_easyfind'}) {
		#todo remove this, unused?
		my $itemEasyFind = GetItemEasyFind($fileHash);
		#$itemTemplate =~ s/\$itemEasyFind/EasyFind: $itemEasyFind/g;
		$itemTemplate .= $itemEasyFind;
	} else {
		#$itemTemplate =~ s/\$itemEasyFind//g;
	}


	# ITEM TEMPLATE
	if ($itemTemplate) {
		$txtIndex .= $itemTemplate;
	} else {
		WriteLog('GetItemPage: warning: $itemTemplate was FALSE');
		$itemTemplate = '';
	}

	if (index($file{'tags_list'}, 'pubkey') != -1) {
		$txtIndex .= GetWindowTemplate('This is a special item, a "public key".<br>A public key allows for reusing the profile and signing messages.', 'Information');
		#todo templatify + use GetString()
	}

	my @result = SqliteQueryHashRef(
		"SELECT attribute, value FROM item_attribute WHERE attribute IN('http', 'https') AND file_hash = '$fileHash'"
	);
	#todo move to default/query
	if (scalar(@result) > 1) { # urls
		my %flags;
		$flags{'no_headers'} = 1;
		$txtIndex .= GetResultSetAsDialog(\@result, 'Links', 'value', \%flags);
	}


	# TOOLBOX
	if (GetConfig('html/item_toolbox/enable')) {
		my $htmlToolbox = GetHtmlToolbox(\%file);
		$txtIndex .= $htmlToolbox;
	} # GetConfig('html/item_toolbox/enable')

#	$txtIndex .= '<hr>';


	##
	##
	##
	###############
	### /REPLY DEPENDENT FEATURES BELOW##########

	$txtIndex .= '<br>';

	#VOTE BUTTONS are below, inside replies


	if (GetConfig('reply/enable')) {
		my $voteButtons = '';
		if (GetConfig('admin/expo_site_mode')) {
			if (GetConfig('admin/expo_site_edit')) {
				#$txtIndex .= GetReplyForm($file{'file_hash'});
			}
			# do nothing
		} else { # additional dialogs on items page
			# REPLY FORM
			$txtIndex .= GetReplyForm($file{'file_hash'});

#
#			# VOTE  BUTTONS
#			# Vote buttons depend on reply functionality, so they are also in here
#			$voteButtons .=
#				GetItemTagButtons($file{'file_hash'}) .
#				'<hr>' .
#				GetTagsListAsHtmlWithLinks($file{'tags_list'}) .
#				'<hr>' .
#				GetString('item_attribute/item_score') . $file{'item_score'}
#			;

			my $classifyForm = GetTemplate('html/item/classify.template');
			$classifyForm = str_replace(
			 	'<span id=itemTagsList></span>',
			 	'<span id=itemTagsList>' . GetTagsListAsHtmlWithLinks($file{'tags_list'}) . '</span>',
			 	$classifyForm
			);

			$classifyForm = str_replace(
			 	'<span id=itemAddTagButtons></span>',
			 	'<span id=itemAddTagButtons>' . GetItemTagButtons($file{'file_hash'}) . '</span>',
			 	$classifyForm
			);

			$classifyForm = str_replace(
			 	'<span id=itemScore></span>',
			 	'<span id=itemScore>' . $file{'item_score'} . '</span>',
			 	$classifyForm
			);



			# CLASSIFY BOX
			$txtIndex .= '<span class=advanced>'.GetWindowTemplate($classifyForm, 'Classify').'</span>';
		}

		#my @itemReplies = DBGetItemReplies($fileHash);
		my @itemReplies = DBGetItemReplies($fileHash);


#
#		my $query = '';
#		if (ConfigKeyValid("query/related")) {
#			$query = GetConfig("query/related");
#			$query =~ s/\?/'$fileHash'/;
#			$query =~ s/\?/'$fileHash'/;
#			$query =~ s/\?/'$fileHash'/;
#		}
#
#		my @itemReplies = SqliteQueryHashRef($query);


		WriteLog('GetItemPage: scalar(@itemReplies) = ' . scalar(@itemReplies));
		foreach my $itemReply (@itemReplies) {
			WriteLog('GetItemPage: $itemReply = ' . $itemReply);
			if ($itemReply->{'tags_list'} && index($itemReply->{'tags_list'}, 'hastext') != -1) {
				my $itemReplyTemplate = GetItemTemplate($itemReply); # GetItemPage reply #hastext
				$txtIndex .= $itemReplyTemplate;
			} else {
				my $itemReplyTemplate = GetItemTemplate($itemReply); # GetItemPage reply not #hastext
				$itemReplyTemplate = '<span class=advanced>' . $itemReplyTemplate . '</span>';
				$txtIndex .= $itemReplyTemplate;
			}
		}

		# REPLIES LIST
		#$txtIndex .= GetReplyListing($file{'file_hash'});

		# RELATED LIST
		$txtIndex .= GetRelatedListing($file{'file_hash'});


	}

	## FINISHED REPLIES
	## FINISHED REPLIES
	## FINISHED REPLIES

	if (GetConfig('admin/expo_site_mode')) { # item attributes dialog on items page
		if (GetConfig('admin/expo_site_edit')) {
			$txtIndex .= GetItemAttributesWindow(\%file);
		}
	} else {
		$txtIndex .= GetItemAttributesWindow(\%file);
		#$txtIndex .= GetMenuTemplate(); # bottom of item page
	}

	# end page with footer
	$txtIndex .= GetPageFooter();

	if (GetConfig('reply/enable')) {
		# if replies is on, include write.js and write_buttons.js
		my @js = qw(settings avatar voting utils profile translit write write_buttons timestamp);
		if (GetConfig('admin/php/enable')) {
			push @js, 'write_php';
		}
		$txtIndex = InjectJs($txtIndex, @js);

	} else {
		$txtIndex = InjectJs($txtIndex, qw(settings avatar voting utils profile translit timestamp));
	}

	#	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto2.js"></script>';
#	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	return $txtIndex;
} # GetItemPage()

sub GetReplyListingEmpty {
	my $html = '<p>No replies found.</p>';
	$html = GetWindowTemplate($html, 'No replies');
	return $html;
}

sub GetReplyListing {
	# if this item has a child_count, we want to print all the child items below
	# keywords: reply replies subitems child parent
	# REPLIES #replies #reply GetItemPage()
	######################################

	if (my $fileHash = shift) {
		my @itemReplies = DBGetItemReplies($fileHash);

		if (@itemReplies) {
			return GetItemListing($fileHash);
		} else {
			#return GetReplyListingEmpty($fileHash);
			return '';
		}
	} else {
		#return GetReplyListingEmpty($fileHash);
		return '';
	}

	WriteLog('GetReplyListing: warning: unreachable reached');
	return '';
} # GetReplyListing()

sub GetRelatedListing {
	# if this item has a child_count, we want to print all the child items below
	# keywords: reply replies subitems child parent
	# REPLIES #replies #reply GetItemPage()
	######################################


	if (my $fileHash = shift) {
		my $query = GetConfig("query/related");
		$query =~ s/\?/'$fileHash'/;
		return GetQueryAsDialog($query, 'Related');
	}

	WriteLog('GetRelatedListing: warning: unreachable reached');
	return '';
} # GetReplyListing()

sub GetItemAttributesWindow {
# GetItemAttributesDialog {
	#my $itemInfoTemplate = GetTemplate('html/item_info.template');
	my $itemInfoTemplate;
	WriteLog('GetItemAttributesWindow: my $itemInfoTemplate; ');

	my $fileRef = shift;
	my %file = %{$fileRef};
#	my %file = %{shift @_};

	my $fileHash = trim($file{'file_hash'});

	#todo sanity checks

	#WriteLog('GetItemAttributesWindow: %file = ' . Dumper(%file));
	#WriteLog('GetItemAttributesWindow: $fileHash = ' . $fileHash);

	my $itemAttributes = DBGetItemAttribute($fileHash);
	$itemAttributes = trim($itemAttributes);

	my $itemAttributesTable = '';
	{ # arrange into table nicely
		foreach my $itemAttribute (split("\n", $itemAttributes)) {
			if ($itemAttribute) {
				my ($iaName, $iaValue) = split('\|', $itemAttribute);

				{
					# this part formats some values for output
					if ($iaName =~ m/_timestamp/) {
						# timestamps
						$iaValue = $iaValue . ' (' . GetTimestampWidget($iaValue) . ')';
					}
					if ($iaName =~ m/file_size/) {
						# timestamps
						$iaValue = $iaValue . ' (' . GetFileSizeWidget($iaValue) . ')';
					}
					if ($iaName eq 'author_key' || $iaName eq 'cookie_id' || $iaName eq 'gpg_id') {
						# turn author key into avatar
						$iaValue = '<tt>' . $iaValue . '</tt>' . ' (' . trim(GetAuthorLink($iaValue)) . ')';
					}
					if ($iaName eq 'title') {
						# title needs to be escaped
						$iaValue = HtmlEscape($iaValue);
					}
					if ($iaName eq 'gpg_alias') {
						# aka signature / username, needs to be escaped
						$iaValue = HtmlEscape($iaValue);
					}
					if ($iaName eq 'file_path') {
						# link file path to file
						my $HTMLDIR = GetDir('html'); #todo
						WriteLog('attr: $HTMLDIR = ' . $HTMLDIR); #todo
						#problem here is GetDir() returns full path, but here we already have relative path
						#currently we assume html dir is 'html'

						WriteLog('attr: $iaValue = ' . $iaValue); #todo
						if (GetConfig('html/relativize_urls')) {
							$iaValue =~ s/^html\//.\//;
						} else {
							$iaValue =~ s/^html\//\//;
						}
						WriteLog('attr: $iaValue = ' . $iaValue); #todo

						$iaValue = HtmlEscape($iaValue);
						$iaValue = '<a href="' . $iaValue . '">' . $iaValue . '</a>';
						#todo sanitizing #security
					}
					if ($iaName eq 'git_hash_object' || $iaName eq 'normalized_hash' || $iaName eq 'sha1' || $iaName eq 'md5') { #todo make it match on _hash and use _hash on the names
						$iaValue = '<tt>' . $iaValue . '</tt>';
					}
					if ($iaName eq 'chain_previous') {
						$iaValue = GetItemHtmlLink($iaValue, DBGetItemTitle($iaValue, 32));

					}
				}

				$itemAttributesTable .= '<tr><td>';
				$itemAttributesTable .= GetString("item_attribute/$iaName") . ':';
				$itemAttributesTable .= '</td><td>';
				$itemAttributesTable .= $iaValue;
				$itemAttributesTable .= '</td></tr>';
			}
		}



		if (defined($file{'tags_list'})) { # bolt on tags list as an attribute
			$itemAttributesTable .= '<tr><td>';
			$itemAttributesTable .= GetString('item_attribute/tags_list');
			$itemAttributesTable .= '</td><td>';
			$itemAttributesTable .= $file{'tags_list'};
			$itemAttributesTable .= '</td></tr>';
		}

		if (defined($file{'item_score'})) { # bolt on item score
			$itemAttributesTable .= '<tr><td>';
			$itemAttributesTable .= GetString('item_attribute/item_score');
			$itemAttributesTable .= '</td><td>';
			$itemAttributesTable .= $file{'item_score'};
			$itemAttributesTable .= '</td></tr>';
		}

		$itemAttributesTable = '<tbody class=content>' . $itemAttributesTable . '</tbody>';

		my $itemAttributesWindow = GetWindowTemplate($itemAttributesTable, 'Item Attributes', 'attribute,value');
		$itemAttributesWindow = '<span class=advanced>' . $itemAttributesWindow . '</span>';

		my $accessKey = GetAccessKey('Item Attributes');
		if ($accessKey) {
			$itemAttributesWindow = AddAttributeToTag($itemAttributesWindow, 'a href=#', 'accesskey', $accessKey);
			$itemAttributesWindow = AddAttributeToTag($itemAttributesWindow, 'a href=#', 'name', 'ia');
		}

		return $itemAttributesWindow;
	}
} # GetItemAttributesWindow()

sub GetPublishForm {
	my $template = GetTemplate('html/form/publish.template');

	my $textEncoded = 'abc';

	$template =~ str_replace('?comment=', '?comment=' . $textEncoded);

	return $template;
}

1;