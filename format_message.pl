sub FormatMessage { # $message, \%file
	my $message = shift;
	my %file = %{shift @_}; #todo should be better formatted
	#todo sanity checks

	if ($file{'remove_token'}) {
		my $removeToken = $file{'remove_token'};
		$message =~ s/$removeToken//g;
		$message = trim($message);
	}

	my $isTextart = 0;
	my $isSurvey = 0;
	my $isTooLong = 0;

	if ($file{'tags_list'}) {
		# if there is a list of tags, check to see if there is a 'textart' tag

		# split the tags list into @itemTags array
		my @itemTags = split(',', $file{'tags_list'});

		# loop through all the tags in @itemTags
		while (scalar(@itemTags)) {
			my $thisTag = pop @itemTags;
			if ($thisTag eq 'textart') {
				$isTextart = 1; # set isTextart to 1 if 'textart' tag is present
			}
			if ($thisTag eq 'survey') {
				$isSurvey = 1; # set $isSurvey to 1 if 'survey' tag is present
			}
		}
	}

	if ($isTextart) {
		# if textart, format with extra spacing to preserve character arrangement
		#$message = TextartForWeb($message);
		$message = TextartForWeb(GetFile($file{'file_path'}));
	} else {
		# if not textart, just escape html characters
		WriteLog('FormatMessage: calling FormatForWeb');
		$message = FormatForWeb($message);
	}

	return $message;
} # FormatMessage()

1;
