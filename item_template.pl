use strict;

sub GetItemTemplateBody {
	my %file = %{shift @_};
	my $itemTemplateBody = '';
	my $itemText = '';

	WriteLog('GetItemTemplateBody() BEGIN');

	if ($file{'item_type'} eq 'txt') {
		my $isTextart = 0;
		if (-1 != index(','.$file{'tags_list'}.',', ',textart,')) {
			$isTextart = 1;
		}

		my $isTooLong = 0;
		my $itemLongThreshold = GetConfig('html/item_long_threshold') || 1024;
		if (length($itemText) > $itemLongThreshold && exists($file{'trim_long_text'}) && $file{'trim_long_text'}) {
			$isTooLong = 1;
		}

		if ($isTextart) {
			$itemText = TextartForWeb(GetCache('message/' . $file{'file_hash'} . '_gpg'));
			if (!$itemText) {
				$itemText = '.'.TextartForWeb(GetFile($file{'file_path'}));
			}
		} else {
			$itemText = GetItemDetokenedMessage($file{'file_hash'}, $file{'file_path'});

			$itemText =~ s/\r//g;

			if ($file{'remove_token'}) {
				# if remove_token is specified, remove it from the message
				WriteLog('GetItemTemplateBody: ' . $file{'file_hash'} . ': $file{remove_token} = ' . $file{'remove_token'});

				$itemText = str_replace($file{'remove_token'}, '', $itemText);
				$itemText = trim($itemText);

				#todo there is a #bug here, but it is less significant than the majority of cases
				#  the bug is that it removes the token even if it is not by itself on a single line
				#  this could potentially be mis-used to join together two pieces of a forbidden string
				#todo make it so that post does not need to be trimmed, but extra \n\n after the token is removed
			} else {
				WriteLog('GetItemTemplateBody: ' . $file{'file_hash'} . ': $file{remove_token} is not set');
			}

			if ($isTooLong) {
				if (length($itemText) > $itemLongThreshold) {
					$itemText = substr($itemText, 0, $itemLongThreshold) . "\n" . '[...]';
					# if item is long, trim it
				}
			}

			$itemText = FormatForWeb($itemText);

			if (GetConfig('html/hide_dashdash_signatures')) { # -- \n
				if (index($itemText, "<br>-- <br>") != -1) {
					$itemText =~ s/(.+)<br>-- <br>(.+)/$1<span class=admin><br>\n-- <br>\n$2<\/span>/smi;
					# /s = single-line (changes behavior of . metacharacter to match newlines)
					# /m = multi-line (changes behavior of ^ and $ to work on lines instead of entire file)
					# /i = case-insensitive
				}
			}

			if ($file{'format_avatars'}) {
				$itemText =~ s/([A-F0-9]{16})/GetHtmlAvatar($1)/eg;
			}
		}
	}

	$itemTemplateBody = GetTemplate('html/item/item.template'); # GetItemTemplate()
	$itemTemplateBody = str_replace('$itemText', $itemText, $itemTemplateBody);
    #$windowBody =~ s/\$itemName/$itemName/g;

	return $itemTemplateBody;
} # GetItemTemplateBody()

sub GetItemTemplate { # \%file ; returns HTML for outputting one item WITH WINDOW FRAME
	WriteLog("GetItemTemplate() begin");

	# %file(hash for each file)
	# file_path = file path including filename
	# file_hash = git's hash of the file's contents
	# author_key = gpg key of author (if any)
	# add_timestamp = time file was added as unix_time
	# child_count = number of replies
	# display_full_hash = display full hash for file
	# template_name = item/item.template by default
	# remove_token = token to remove (for reply tokens)
	# show_vote_summary = shows item's list and count of tags
	# show_quick_vote = displays quick vote buttons
	# item_title = override title
	# item_statusbar = override statusbar
	# tags_list = comma-separated list of tags the item has
	# is_textart = set <tt><code> tags for the message itself
	# no_permalink = do not link to item's permalink page

	# show_easyfind = show/hide easyfind words
	# item_type = 'txt' or 'image'
	# vote_return_to = page to redirect user to after voting, either item hash or url
	# trim_long_text = trim text if it is longer than config/html/item_long_threshold

	# get %file hash from supplied parameters
	my %file = %{shift @_};

	my $sourceFileHasGoneAway = 0;

	# verify that referenced file path exists
	if (-e $file{'file_path'}) {
		#cool
	}
	else {
		WriteLog('GetItemTemplate: warning: -e $file{file_path} was FALSE; $file{file_path} = ' . $file{'file_path'});
		$sourceFileHasGoneAway = 1;
	}

	if (1) {
		my $itemHash = $file{'file_hash'}; # file hash/item identifier
		my $gpgKey = $file{'author_key'}; # author's fingerprint

		my $alias; # stores author's alias / name
		my $isAdmin = 0; # author is admin? (needs extra styles)

		my $itemType = '';

		my $isSigned = 0; # is signed by user (also if it's a pubkey)
		if ($gpgKey) { # if there's a gpg key, it's signed
			$isSigned = 1;
		} else {
			$isSigned = 0;
		}

		#my $message = '';
		if (
			$isSigned
				&&
			IsAdmin($gpgKey)
		) {
			# if item is signed, and the signer is an admin, set $isAdmin = 1
			$isAdmin = 1;
		}


		# escape the alias name for outputting to page
		$alias = HtmlEscape($alias);
		my $fileHash = GetFileHash($file{'file_path'}); # get file's hash

		# initialize $itemTemplate for storing item output
		my $itemTemplate = '';
		{ ### this is the item template itself, including the window

			##########################################################
			### this is the item template itself, including the window
			### this is the item template itself, including the window
			### this is the item template itself, including the window
			### this is the item template itself, including the window
			### this is the item template itself, including the window
			##########################################################

			#return GetWindowTemplate ($param{'body'}, $param{'title'}, $param{'headings'}, $param{'status'}, $param{'menu'});
			my %windowParams;

			{
				# WINDOW BODY / ITEM CONTENT
				# WINDOW BODY / ITEM CONTENT


				my $windowBody = '';
				$windowBody = GetItemTemplateBody(\%file);
				$windowParams{'body'} = $windowBody;
				#$windowParams{'body'} = htmlspecialchars($windowBody);
				#$windowParams{'body'} = $windowBody;
				#$windowParams{'body'} = 'fuck you';
			}

			# TITLE
			# TITLE
			if (GetConfig('admin/expo_site_mode')) { #todo #debug #expo
				$windowParams{'title'} = HtmlEscape($file{'item_name'});
			} else {
				$windowParams{'title'} = HtmlEscape($file{'item_title'});
			}

			# GUID
			$windowParams{'guid'} = substr(sha1_hex($file{'file_hash'}), 0, 8);


			# TAGS LIST AKA HEADING
			# TAGS LIST AKA HEADING
			# TAGS LIST AKA HEADING
			if ($file{'tags_list'}) {
				my $headings = GetTagsListAsHtmlWithLinks($file{'tags_list'});
				$windowParams{'headings'} = $headings;
				#$windowParams{'headings'} = '<a>#' . join('</a> <a>#', split(',', $file{'tags_list'})) . '</a>';
			} # $file{'tags_list'}


			# STATUS BAR
			# STATUS BAR
			# STATUS BAR
			my $statusBar = '';
			if (GetConfig('admin/expo_site_mode') && !GetConfig('admin/expo_site_edit')) { #expo
				WriteLog('GetItemTemplate: $statusBar expo_site_mode override activated');
				if ($file{'item_title'} =~ m/^http/) {
					my $permalinkHtml = $file{'item_title'};
					$statusBar =~ s/\$permalinkHtml/$permalinkHtml/g;
				}

				if ($file{'no_permalink'}) {
					$statusBar = $file{'item_title'};
				}
			} else {
				$statusBar = GetTemplate('html/item/status_bar.template');

				my $fileHashShort = substr($fileHash, 0, 8);
				$statusBar = str_replace('<span class=fileHashShort></span>', "<span class=fileHashShort>" . $fileHashShort . "</span>", $statusBar);
				#$statusBar =~ s/\$fileHashShort/$fileHashShort/g;

				if ($gpgKey) {
					# get author link for this gpg key
					my $authorLink = trim(GetAuthorLink($gpgKey));
					$statusBar =~ s/\$authorLink/$authorLink/g;
				} else {
					# if no author, no $authorLink
					$statusBar =~ s/\$authorLink;//g;
				}
				WriteLog('$statusBar 1.5 = ' . $statusBar);
			}

			if ($file{'item_statusbar'}) {
				$statusBar = $file{'item_statusbar'};
			}

			if (GetConfig('admin/expo_site_mode') && $file{'tags_list'} && index($file{'tags_list'}, 'sponsor') != -1) {
				$statusBar = '<a href="' . $file{'item_title'} . '" target=_blank>' . $file{'item_title'} . '</a>';
			}

#			if (!$statusBar && index($file{'tags_list'}, 'speaker') != -1) {
#				#$statusBar = $file{'item_title'};
#			}
			WriteLog('$statusBar 2 = ' . $statusBar);
			if ($itemType eq 'image') {
				$windowParams{'status'} = $statusBar;
				#$windowParams{'status'} = $statusBar . '<hr>' . GetQuickVoteButtonGroup($file{'file_hash'}, $file{'vote_return_to'});
			} else {
				$windowParams{'status'} = $statusBar;
			}

			#$windowParams{'status'} = GetQuickVoteButtonGroup($file{'file_hash'}, $file{'vote_return_to'});


#			if (GetConfig('admin/expo_site_mode') && !GetConfig('admin/expo_site_edit')) {
#				#todo
#				if ($file{'item_name'} eq 'Information') {
#					WriteLog('GetItemTemplate: expo_site_mode: setting window status to blank');
#					$windowParams{'status'} = '';
#				}
#			}

			if (defined($file{'show_quick_vote'})) {
				$windowParams{'menu'} = GetQuickVoteButtonGroup($file{'file_hash'}, $file{'vote_return_to'});
			}

			$windowParams{'id'} = substr($file{'file_hash'}, 0, 7);

			$itemTemplate = GetWindowTemplate2(\%windowParams);
			$itemTemplate .= '<replies></replies>';
		} ### this is the item template itself, including the window

		# $itemTemplate = str_replace(
		# 	'<span class=more></span>',
		# 	GetWidgetExpand(2, '#'),
		# 	$itemTemplate
		# );#todo fix broken
#
#		my $widgetExpandPlaceholder = '<span class=expand></span>';
#		if (index($itemTemplate, $widgetExpandPlaceholder) != -1) {
#			WriteLog('GetItemTemplate: $widgetExpandPlaceholder found in item: ' . $widgetExpandPlaceholder);
#
#			if (GetConfig('admin/js/enable')) {
#				# js on, insert widget
#
#				my $widgetExpand = GetWidgetExpand(5, GetHtmlFilename($itemHash));
#				$itemTemplate = str_replace(
#					'<span class=expand></span>',
#					'<span class=expand>' .	$widgetExpand .	'</span>',
#					$itemTemplate
#				);
#
#				# $itemTemplate = AddAttributeToTag(
#				# 	$itemTemplate,
#				# 	'a href="/etc.html"', #todo this should link to item itself
#				# 	'onclick',
#				# 	"if (window.ShowAll && this.removeAttribute) { this.removeAttribute('onclick'); return ShowAll(this, this.parentElement.parentElement.parentElement.parentElement.parentElement); } else { return true; }"
#				# );
#			} else {
#				# js off, remove placeholder for widget
#				$itemTemplate = str_replace($widgetExpandPlaceholder, '', $itemTemplate);
#			}
#		} # $widgetExpandPlaceholder

		my $authorUrl; # author's profile url
		my $authorAvatar; # author's avatar
		my $permalinkTxt = $file{'file_path'};

		{
		    #todo still does not work perfectly, this
			# set up $permalinkTxt, which links to the .txt version of the file

			# strip the 'html/' prefix on the file's path, replace with /
			#todo relative links
            my $HTMLDIR = GetDir('html');
			$permalinkTxt =~ s/$HTMLDIR\//\//;
			$permalinkTxt =~ s/^html\//\//;
		}

		# set up $permalinkHtml, which links to the html page for the item
		my $permalinkHtml = '/' . GetHtmlFilename($itemHash);
		#		my $permalinkHtml = '/' . substr($itemHash, 0, 2) . '/' . substr($itemHash, 2) . ".html";
		#		$permalinkTxt =~ s/^\.//;

		my $itemAnchor = substr($fileHash, 0, 8);
		my $itemName; # item's 'name'

		if ($file{'display_full_hash'} && $file{'display_full_hash'} != 0) {
			# if display_full_hash is set, display the item's entire hash for name
			$itemName = $fileHash;
		} else {
			# if display_full_hash is not set, truncate the hash to 8 characters
			#$itemName = substr($fileHash, 0, 8) . '..';
			$itemName = $file{'item_name'};
		}

		my $replyCount = $file{'child_count'};
		my $borderColor = '#' . substr($fileHash, 0, 6); # item's border color
		my $addedTime = DBGetAddedTime($fileHash);
		if (!$addedTime) {
			WriteLog('GetItemTemplate: warning: $addedTime was FALSE');
			$addedTime = 0;
		}
		$addedTime = ceil($addedTime);
		my $addedTimeWidget = GetTimestampWidget($addedTime); #todo optimize
		my $itemTitle = $file{'item_title'};

		{ #todo refactor this to not have title in the template
			if ($file{'item_title'}) {
				my $itemTitle = HtmlEscape($file{'item_title'});
				$itemTemplate =~ s/\$itemTitle/$itemTitle/g;
			} else {
				$itemTemplate =~ s/\$itemTitle/Untitled/g;
			}
		}

		my $replyLink = $permalinkHtml . '#reply'; #todo this doesn't need the url before #reply if it is on the item's page
#
#		if (GetConfig('admin/expo_site_mode')) {
#			# do nothing
#		} else {
#			if (index($itemText, '$') > -1) {
#				# this is a kludge, should be a better solution
#				#$itemText = '<code>item text contained disallowed character</code>';
#				$itemText =~ s/\$/%/g;
#			}
#		}

		#my $itemClass = 'foobar';


		$itemTemplate =~ s/\$borderColor/$borderColor/g;
		#$itemTemplate =~ s/\$itemClass/$itemClass/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;
		$itemTemplate =~ s/\$addedTime/$addedTimeWidget/g;
		$itemTemplate =~ s/\$replyLink/$replyLink/g;
		$itemTemplate =~ s/\$itemAnchor/$itemAnchor/g;

		if ($replyCount) {
			$itemTemplate =~ s/\$replyCount/$replyCount/g;
		} else {
			$itemTemplate =~ s/\$replyCount/0/g;
		}

		# if show_vote_summary is set, show a count of all the tags the item has
		if ($file{'show_vote_summary'}) {
			#this displays the vote summary (tags applied and counts)
			my %voteTotals = DBGetItemVoteTotals($file{'file_hash'});
			my $votesSummary = '';
			foreach my $voteTag (keys %voteTotals) {
				#todo templatize this
				$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";
			}
			if ($votesSummary) {
				$votesSummary .= '<br>';
				#todo templatize
			}
			$itemTemplate =~ s/\$votesSummary/$votesSummary/g;
		} else {
			$itemTemplate =~ s/\$votesSummary//g;
		}

		my $itemFlagButton = '';
		if (defined($file{'vote_return_to'}) && $file{'vote_return_to'}) {
			WriteLog('GetItemTemplate: $file{\'vote_return_to\'} = ' . $file{'vote_return_to'});

			$itemFlagButton = GetItemTagButtons($file{'file_hash'}, 'all', $file{'vote_return_to'}); #todo refactor to take vote totals directly
		} else {
			# WriteLog('GetItemTemplate: $file{\'vote_return_to\'} = ' . $file{'vote_return_to'});

			$itemFlagButton = GetItemTagButtons($file{'file_hash'}, 'all'); #todo refactor to take vote totals directly
		}

		$itemTemplate =~ s/\$itemFlagButton/$itemFlagButton/g;

		WriteLog('GetItemTemplate: return $itemTemplate = ' . length($itemTemplate));

		return $itemTemplate;
	} # (1)

	WriteLog('GetItemTemplate: warning: unreachable reached!');
	return '';
} # GetItemTemplate()

1;