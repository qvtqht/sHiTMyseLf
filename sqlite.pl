#!/usr/bin/perl -T
#freebsd: #!/usr/local/bin/perl

use strict;
use warnings;
use utf8;
use Data::Dumper;
use Carp;
use 5.010;

require './utils.pl';

my @foundArgs;
while (my $argFound = shift) {
	push @foundArgs, $argFound;
}

sub GetSqliteDbName {
	my $cacheDir = GetDir('cache');
	my $SqliteDbName = "$cacheDir/index.sqlite3"; # path to sqlite db
	return $SqliteDbName;
}

sub DBMaxQueryLength { # Returns max number of characters to allow in sqlite query
	return 1024;
}

sub DBMaxQueryParams { # Returns max number of parameters to allow in sqlite query
	return 128;
}

sub SqliteQuery2 {
    return SqliteQuery(@_);
}

sub SqliteMakeTables { # creates sqlite schema
    # sub SqliteCreateTables {
    # sub SqliteMakeTables {
    # sub DBMakeTables {
	my $existingTables = SqliteQueryCachedShell('.tables');
	if ($existingTables) {
		WriteLog('SqliteMakeTables: warning: tables already exist');
		return '';
	}

    my $schemaQueries = GetConfig('sqlite3/schema.sql'); #todo improve name, use template tree; use GetTemplate()
    $schemaQueries .= GetConfig('sqlite3/vote_value.sql'); #todo improve name, use template tree; use GetTemplate()

    $schemaQueries =~ s/^#.+$//mg; # remove sh-style comments (lines which begin with #)

    #confess $schemaQueries;

    SqliteQuery($schemaQueries);

	my $SqliteDbName = GetSqliteDbName();

	my $schemaHash = `sqlite3 "$SqliteDbName" ".schema" | sha1sum | awk '{print \$1}' > config/sqlite3_schema_hash`;
	# this can be used as schema "version"
	# only problem is first time it changes, now cache must be regenerated
	# so need to keep track of the previous one and recursively call again or copy into new location

} # SqliteMakeTables()

sub SqliteGetQueryString {
	my $query = shift;
	chomp $query;

	my @queryParams = @_;

	if ($query =~ m/^(.+)$/s) { #todo real sanity check
		$query = $1;
	} else {
	    WriteLog('SqliteGetQueryString: warning: sanity check failed on $query');
	    return '';
	}

    if (! $query =~ m/\s/) {
        #if no spaces in query, it may be a query name
        # here try to look it up

        WriteLog('SqliteGetQueryString: looking up query/');
        if (GetConfig('query/' . $query)) {
            #todo IsItem() ...
            #todo sanity
            $query = GetConfig('query/' . $query);
        } else {
            WriteLog('SqliteGetQueryString: warning: query did not contain spaces, but lookup in config/query failed');
        }
    }

    # remove any non-space space characters and make it one line
    my $queryOneLine = $query;
    $queryOneLine =~ s/\s/ /g;
    while ($queryOneLine =~ m/\s\s/) {
        $queryOneLine =~ s/  / /g;
    }
    $queryOneLine = trim($queryOneLine);

    WriteLog('SqliteGetQueryString: $queryOneLine = ' . $queryOneLine);
    WriteLog('SqliteGetQueryString: caller: ' . join(', ', caller));

    #die Dumper(@queryParams);

    my $queryWithParams = $queryOneLine;

    if (@queryParams && scalar(@queryParams)) {
        # insert params into ? placeholders
        while (@queryParams) {
            my $paramValue = shift @queryParams;
            $queryWithParams =~ s/\?/'$paramValue'/;
        }
    }

    WriteLog('SqliteGetQueryString: $queryWithParams = ' . $queryWithParams);

    return $queryWithParams;
} # SqliteGetQueryString()

sub SqliteQueryHashRef { # $query, @queryParams; calls sqlite with query, and returns result as array of hashrefs
# ATTENTION: first array element returned is an array of column names!

	WriteLog('SqliteQueryGetArrayOfHashRef: begin');

	my $query = shift;
	chomp $query;

	if ($query =~ m/^([0-9a-zA-Z_-]+)$/i) {
		$query = $1;
		if (GetConfig('query/' . $query)) {
			#todo sanity
			$query = GetConfig('query/' . $query);
		}
	}

	my @queryParams = @_;
	my $queryWithParams = SqliteGetQueryString($query, @queryParams);

	if ($queryWithParams) {
		#my $resultString = SqliteQueryCachedShell($queryWithParams);
		my $resultString = SqliteQuery($queryWithParams);

        if ($resultString) {
    		my @resultsArray;
            my @resultStringLines = split("\n", $resultString);

            my @columns = ();
            while (@resultStringLines) {
                my $line = shift @resultStringLines;
                if (!@columns) {
                    @columns = split ('\|', $line);
                    push @resultsArray, \@columns;
                    # store column names, next
                } else {
                    my @fields = split('\|', $line);
                    my %newHash;
                    foreach my $field (@columns) {
                        $newHash{$field} = shift @fields;
                    }
                    push @resultsArray, \%newHash;
                }
            }

            return @resultsArray;
		} # if ($resultString)
	} # if ($query)
} # SqliteQueryGetArrayOfHashRef()

sub EscapeShellChars { # $string ; escapes string for including as parameter in shell command
	#todo this is still probably not safe and should be improved upon #security
	my $string = shift;
	chomp $string;

	$string =~ s/([\"|\$`\\])/\\$1/g;
	# chars are: " | $ ` \

	return $string;
} # EscapeShellChars()

sub SqliteQuery { # performs sqlite query via sqlite3 command
#todo add parsing into array?
    #print Dumper(@_);

	my $query = shift;
	if (!$query) {
		WriteLog('SqliteQuery: warning: called without $query');
		return;
	}
	chomp $query;
	my @queryParams = @_;

	WriteLog('SqliteQuery: $query = ' . $query);
	WriteLog('SqliteQuery: caller = ' . join(',', caller));

    $query = SqliteGetQueryString($query, @queryParams);

	my $SqliteDbName = GetSqliteDbName();

	if ($SqliteDbName =~ m/^(.+)$/) {
	    #todo real sanity check
	    $SqliteDbName = $1;
    } else {
        #todo failed sanity check
    }

	if ($query =~ m/^(.+)$/) {
	    #todo real sanity check
	    $query = $1;
    } else {
        #todo failed sanity check
    }

	my $results = `sqlite3 -header "$SqliteDbName" "$query"`;
	return $results;
} # SqliteQuery()

sub SqliteQueryCachedShell { # $query, @queryParams ; performs sqlite query via sqlite3 command
# uses cache with query text's hash as key
# sub CacheSqliteQuery {
	WriteLog('SqliteQueryCachedShell: caller: ' . join(', ', caller));

	my $withHeader = 1;

	my $query = shift;
	if (!$query) {
		WriteLog('SqliteQueryCachedShell: warning: called without $query');
		return;
	}
	chomp $query;
	my @queryParams = @_;

	$query = SqliteGetQueryString($query, @queryParams);

	my $cachePath = md5_hex($query);
	if ($cachePath =~ m/^([0-9a-f]{32})$/) {
		$cachePath = $1;
	} else {
		WriteLog('SqliteQueryCachedShell: warning: $cachePath sanity check failed');
	}
	my $cacheTime = GetTime();

    if (0) {
	    # this limits the cache to expiration of 1-100 seconds
	    # #bug this does not account for milliseconds
	    $cacheTime = substr($cacheTime, 0, length($cacheTime) - 2);
	    $cachePath = "$cacheTime/$cachePath";
    }

	WriteLog('SqliteQueryCachedShell: $cachePath = ' . $cachePath);
	my $results;

	#$results = GetCache("sqcs/$cachePath");
	#todo uncomment ###todo

	if ($results) {
		#cool
		WriteLog('SqliteQueryCachedShell: $results was populated from cache');
	} else {
		my $results = SqliteQuery($query);
		WriteLog('SqliteQueryCachedShell: PutCache: length($results) ' . length($results));
		PutCache('sqcs/'.$cachePath, $results);
	}

	if ($results) {
        return $results;
    }
} # SqliteQueryCachedShell()

sub DBGetVotesForItem { # Returns all votes (weighed) for item
	my $fileHash = shift;

	if (!IsSha1($fileHash)) {
		WriteLog("DBGetVotesTable called with invalid parameter! returning");
		WriteLog("$fileHash");
		return '';
	}

	my $query;
	my @queryParams;

	$query = "
		SELECT
			file_hash,
			ballot_time,
			vote_value,
			author_key
		FROM vote
		WHERE file_hash = ?
	";
	@queryParams = ($fileHash);

	my @result = SqliteQueryGetArrayOfHashRef($query, @queryParams);

	return @result;
}
#
sub DBGetEvents { #gets events list
	WriteLog('DBGetEvents()');

	my $query;

	$query = "
		SELECT
			item_flat.item_title AS event_title,
			event.event_time AS event_time,
			event.event_duration AS event_duration,
			item_flat.file_hash AS file_hash,
			item_flat.author_key AS author_key,
			item_flat.file_path AS file_path
		FROM
			event
			LEFT JOIN item_flat ON (event.item_hash = item_flat.file_hash)
		ORDER BY
			event_time
	";

	my @queryParams = ();
	#	push @queryParams, $time;

	#todo rewrite this sub better

	my @queryResult = SqliteQueryGetArrayOfHashRef($query, @queryParams);
	return @queryResult;
}

sub DBGetAuthorFriends { # Returns list of authors which $authorKey has tagged as friend
# Looks for vote_value = 'friend' and items that contain 'pubkey' tag
	my $authorKey = shift;
	chomp $authorKey;
	if (!$authorKey) {
		return;
	}
	if (!IsFingerprint($authorKey)) {
		return;
	}

	my $query = "
		SELECT
			DISTINCT item_flat.author_key
		FROM
			vote
			LEFT JOIN item_flat ON (vote.file_hash = item_flat.file_hash)
		WHERE
			vote.author_key = ?
			AND vote_value = 'friend'
			AND ',' || item_flat.tags_list || ',' LIKE '%,pubkey,%'
		;
	";

	my @queryParams = ();
	push @queryParams, $authorKey;

	my @queryResult = SqliteQueryGetArrayOfHashRef($query, @queryParams);
	return @queryResult;

} # DBGetAuthorFriends()

sub DBGetLatestConfig { # Returns everything from config_latest view
# config_latest contains the latest set value for each key stored
	WriteLog('DBGetLatestConfig() BEGIN');
	WriteLog('DBGetLatestConfig: warning: disabled');
	return '';

	my $query = "SELECT * FROM config_latest";
	#todo write out the fields


	my @queryResult = SqliteQueryGetArrayOfHashRef($query);
	return @queryResult;

} # DBGetLatestConfig()

sub DBGetAuthorCount { # Returns author count.
# By default, all authors, unless $whereClause is specified

	my $authorCount;

	my $query = 'author_count';

	my $queryResult = SqliteGetValue($query);

	#$authorCount = $queryResult[0]->{'author_count'};

	return $queryResult;
}

sub DBGetItemCount { # Returns item count.
# By default, all items, unless $whereClause is specified
	#my $whereClause = shift;

	my $itemCount;
#	if ($whereClause) {
#		if (substr(lc($whereClause), 0, 7) eq 'where ') {
#			$whereClause = substr($whereClause, 7);
#		}
#		$itemCountQuery = SqliteQueryCachedShell("SELECT COUNT(*) AS item_count FROM item_flat WHERE $whereClause LIMIT 1");
#	} else {
    $itemCount = SqliteGetValue('item_count');
#	}
	if ($itemCount) {
		chomp($itemCount);
	} else {
		#todo warning
		$itemCount = -1;
	}

	return $itemCount;
} # DBGetItemCount()

sub DBGetItemParents {# Returns all item's parents
# $itemHash = item's hash/identifier
# Sets up parameters and calls DBGetItemList
	my $itemHash = shift;

	if (!IsSha1($itemHash)) {
		WriteLog('DBGetItemParents called with invalid parameter! returning');
		return '';
	}

	$itemHash = SqliteEscape($itemHash);

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE file_hash IN(SELECT item_hash FROM item_child WHERE item_hash = '$itemHash')";
	$queryParams{'order_clause'} = "ORDER BY add_timestamp"; #todo this should be by timestamp

	return DBGetItemList(\%queryParams);
}

sub DBGetItemReplies { # Returns replies for item (actually returns all child items)
# $itemHash = item's hash/identifier
# Sets up parameters and calls DBGetItemList
	my $itemHash = shift;
	if (!IsItem($itemHash)) {
		WriteLog('DBGetItemReplies: warning: sanity check failed, returning');
		return '';
	}
	if ($itemHash ne SqliteEscape($itemHash)) {
		WriteLog('DBGetItemReplies: warning: $itemHash contains escapable characters');
		return '';
	}
	WriteLog("DBGetItemReplies($itemHash)");

	my %queryParams;
	if (GetConfig('admin/expo_site_mode') && !GetConfig('admin/expo_site_edit')) {
		$queryParams{'where_clause'} = "WHERE ','||tags_list||',' NOT LIKE '%,notext,%' AND file_hash IN(SELECT item_hash FROM item_parent WHERE parent_hash = '$itemHash')";
	} else {
		$queryParams{'where_clause'} = "WHERE file_hash IN (SELECT item_hash FROM item_parent WHERE parent_hash = '$itemHash')";
	}
	$queryParams{'order_clause'} = "ORDER BY (tags_list NOT LIKE '%hastext%'), add_timestamp";

	return DBGetItemList(\%queryParams);
}

sub SqliteEscape { # Escapes supplied text for use in sqlite query
# Just changes ' to ''
	my $text = shift;

	if (defined $text) {
		$text =~ s/'/''/g;
	} else {
		$text = '';
	}

	return $text;
}

sub SqliteGetValue {
    #todo
	my $query = shift;
	my @queryParams = @_;
	#todo sanity

	my @result = SqliteQueryHashRef($query, @queryParams);

	if (scalar(@result) > 1) { #first row is column names
        my $firstColumn = $result[0][0];
        my %firstRow = %{$result[1]}; #0 is headers
        my $return = $firstRow{$firstColumn};

        return $return;
	} else {
	    return '';
	}
}

sub DBGetItemTitle { # get title for item ($itemhash)
	my $itemHash = shift;

	if (!$itemHash || !IsItem($itemHash)) {
		return;
	}

	#my $query = 'SELECT title FROM item_title WHERE file_hash = ?';
	my @queryParams = ();
	#push @queryParams, $itemHash;

	#fuck parametrized queries
	my $query = 'SELECT title FROM item_title WHERE file_hash LIKE \'' . $itemHash . '%\'';

	my $itemTitle = SqliteGetValue($query, @queryParams);

	if ($itemTitle) {
		my $maxLength = shift;
		if ($maxLength) {
			if ($maxLength > 0 && $maxLength < 255) {
				#todo sanity check failed message
				if (length($itemTitle) > $maxLength) {
					$itemTitle = substr($itemTitle, 0, $maxLength) . '...';
				}
			}
		}

		return $itemTitle;
	} else {
		return '';
	}
} # DBGetItemTitle()

sub DBGetItemFilePath { # get path for item's source file
	my $itemHash = shift;

	if (!$itemHash || !IsItem($itemHash)) {
		return;
	}

	my $query = 'SELECT file_path FROM item WHERE file_hash = ?';
	my @queryParams = ();

	push @queryParams, $itemHash;

	my $itemFile = SqliteGetValue($query, @queryParams);

	if ($itemFile) {
		return $itemFile;
	} else {
		return '';
	}
} # DBGetItemTitle()

sub DBGetItemAuthor { # get author for item ($itemhash)
	my $itemHash = shift;

	if (!$itemHash || !IsItem($itemHash)) {
		return;
	}

	chomp $itemHash;

	WriteLog('DBGetItemAuthor(' . $itemHash . ')');

	my $query = 'SELECT author_key FROM item_flat WHERE file_hash = ?';
	my @queryParams = ();
	#
	push @queryParams, $itemHash;

	WriteLog('DBGetItemAuthor: $query = ' . $query);

	my $authorKey = SqliteGetValue($query, @queryParams);

	if ($authorKey) {
		return $authorKey;
	} else {
		return;
	}
}

sub DBAddConfigValue { # $key, $value, $resetFlag, $sourceItem ; add value to config table
	state $query;
	state @queryParams;

	my $key = shift;

	if (!$key) {
		WriteLog('DBAddConfigValue: warning: sanity check failed');
		return '';
	}

	if ($key eq 'flush') {
		WriteLog("DBAddConfigValue(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		$query = '';
		@queryParams = ();
	}

	my $value = shift;
	my $resetFlag = shift;
	my $sourceItem = shift;

	if ($key =~ m/^([a-z0-9_\/.]+)$/) {
		# sanity success
		$key = $1;
	} else {
		WriteLog('DBAddConfigValue: warning: sanity check failed on $key = ' . $key);
		return '';
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO config(key, value, reset_flag, file_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?)';
	push @queryParams, $key, $value, $resetFlag, $sourceItem;

	return;
}

sub DBGetTouchedPages { # Returns items from task table, used for prioritizing which pages need rebuild
# index, rss, authors, stats, tags, and top are returned first
	my $touchedPageLimit = shift;

	WriteLog("DBGetTouchedPages($touchedPageLimit)");

	# sorted by most recent (touch_time DESC) so that most recently touched pages are updated first.
	# this allows us to call a shallow update and still expect what we just did to be updated.
	my $query = "
		SELECT
			task_name,
			task_param,
			touch_time,
			priority
		FROM task
		WHERE task_type = 'page' AND priority > 0
		ORDER BY priority DESC, touch_time DESC
		LIMIT ?;
	";

	my @params;
	push @params, $touchedPageLimit;

	my @results = SqliteQueryGetArrayOfHashRef($query, @params);

	return @results;
} # DBGetTouchedPages()

sub DBGetAllPages { # Returns items from task table, used for prioritizing which pages need rebuild
# index, rss, authors, stats, tags, and top are returned first
	my $touchedPageLimit = shift;

	WriteLog("DBGetAllPages($touchedPageLimit)");

	# sorted by most recent (touch_time DESC) so that most recently touched pages are updated first.
	# this allows us to call a shallow update and still expect what we just did to be updated.
	my $query = "
		SELECT
			task_name,
			task_param,
			touch_time,
			priority
		FROM task
		WHERE task_type = 'page'
		ORDER BY priority DESC, touch_time DESC
		;
	";

	my @params;

	my @results = SqliteQueryGetArrayOfHashRef($query, @params);

	return @results;
} # DBGetAllPages()

sub DBAddItemPage { # $itemHash, $pageType, $pageParam ; adds an entry to item_page table
# should perhaps be called DBAddItemPageReference
# purpose of table is to track which items are on which pages

	state $query;
	state @queryParams;

	my $itemHash = shift;

	if ($itemHash eq 'flush') {
		if ($query) {
			WriteLog("DBAddItemPage(flush)");

			if (!$query) {
				WriteLog('Aborting, no query');
				return;
			}

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = "";
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddItemPage('flush');
		$query = '';
		@queryParams = ();
	}

	my $pageType = shift;
	my $pageParam = shift;

	if (!$pageType) {
		WriteLog('DBAddItemPage: warning: called without $pageType');
		return;
	}
	if (!$pageParam) {
		$pageParam = '';
	}

	WriteLog("DBAddItemPage($itemHash, $pageType, $pageParam)");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_page(item_hash, page_name, page_param) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?, ?, ?)';
	push @queryParams, $itemHash, $pageType, $pageParam;
}

sub DBResetPageTouch { # Clears the task table
# Called by clean-build, since it rebuilds the entire site
	WriteMessage("DBResetPageTouch() begin");

	my $query = "DELETE FROM task WHERE task_type = 'page'";
	my @queryParams = ();

	SqliteQuery2($query, @queryParams);

	WriteMessage("DBResetPageTouch() end");
}

sub DBDeletePageTouch { # $pageName, $pageParam
#todo optimize
	#my $query = 'DELETE FROM task WHERE page_name = ? AND page_param = ?';
	my $query = "UPDATE task SET priority = 0 WHERE task_type = 'page' AND task_name = ? AND task_param = ?";

	my $pageName = shift;
	my $pageParam = shift;

	my @queryParams = ($pageName, $pageParam);

	SqliteQuery2($query, @queryParams);
}

sub DBDeleteItemReferences { # delete all references to item from tables
# sub RemoveItemReferences {
# #todo feels not up to date as of 1617729803 / march 6 2021
# #todo ensure that table lists are up to date
	WriteLog('DBDeleteItemReferences() ...');

	my $hash = shift;
	if (!IsSha1($hash)) {
		return;
	}

	WriteLog('DBDeleteItemReferences(' . $hash . ')');

	#todo queue all pages in item_page ;
	#todo item_page should have all the child items for replies

	#file_hash
	my @tables = qw(
		author_alias
		config
		item
		item_attribute
	);
	foreach (@tables) {
		my $query = "DELETE FROM $_ WHERE file_hash = '$hash'";
		SqliteQuery2($query);
	}

	#item_hash
	my @tables2 = qw(event item_page item_parent location);
	foreach (@tables2) {
		my $query = "DELETE FROM $_ WHERE item_hash = '$hash'";
		SqliteQuery2($query);
	}

	{ #dupe of below? #todo
		my $query = "DELETE FROM vote WHERE ballot_hash = '$hash'";
		SqliteQuery2($query);
	}

	{
		my $query = "DELETE FROM item_attribute WHERE source = '$hash'";
		SqliteQuery2($query);
	}

	#ballot_hash
	my @tables3 = qw(vote);
	foreach (@tables3) {
		my $query = "DELETE FROM $_ WHERE ballot_hash = '$hash'";
		SqliteQuery2($query);
	}

	#todo
	#item_attribute.source
	#item_parent (?)
	#item_page (and refresh)
	#
	#
	#

	#todo any successes deleting stuff should result in a refresh for the affected page
}

sub DBAddTask { # $taskType, $taskName, $taskParam, $touchTime # make new task
# DBAddTaskToQueue {

	state $query;
	state @queryParams;

	my $taskType = shift;

	if ($taskType eq 'flush') {
		# flush to database queue stored in $query and @queryParams
		if ($query) {
			WriteLog("DBAddTask(flush)");

			if (!$query) {
				WriteLog('DBAddTask: flush: no query, exiting');
				return;
			}

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = "";
			@queryParams = ();
		}

		return;
	}

	my $taskName = shift;
	my $taskParam = shift;
	my $touchTime = shift;

	WriteLog("DBAddTask($taskType, $taskName, $taskParam, $touchTime)");

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddTask('flush');
		$query = '';
		@queryParams = ();
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO task(task_type, task_name, task_param, touch_time) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= "('page', ?, ?, ?)";
	push @queryParams, $taskType, $taskName, $taskParam, $touchTime;
} # DBAddTask()

sub DBAddPageTouch { # $pageName, $pageParam; Adds or upgrades in priority an entry to task table
# task table is used for determining which pages need to be refreshed
# is called from IndexTextFile() to schedule updates for pages affected by a newly indexed item
# if $pageName eq 'flush' then all the in-function stored queries are flushed to database.
	state $query;
	state @queryParams;

	my $pageName = shift;

	if ($pageName eq 'index') {
		#return;
		# this can be uncommented during testing to save time
		#todo optimize this so that all pages aren't rewritten at once
	}

	if ($pageName eq 'tag') {
		# if a tag page is being updated,
		# then the tags summary page must be updated also
		DBAddPageTouch('tags');
	}

	if ($pageName eq 'flush') {
		# flush to database queue stored in $query and @queryParams
		if ($query) {
			WriteLog("DBAddPageTouch(flush)");

			if (!$query) {
				WriteLog('Aborting DBAddPageTouch(flush), no query');
				return;
			}

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = "";
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddPageTouch('flush');
		$query = '';
		@queryParams = ();
	}

	my $pageParam = shift;

	if (!$pageParam) {
		$pageParam = 0;
	}

	my $touchTime = GetTime();

	if ($pageName eq 'author') {
		# cascade refresh items which are by this author
		#todo probably put this in another function
		# could also be done as
		# foreach (author's items) { DBAddPageTouch('item', $item); }
		#todo this is kind of a hack, sould be refactored, probably

		# touch all of author's items too
		#todo fix awkward time() concat
		my $queryAuthorItems = "
			UPDATE task
			SET priority = (priority + 1), touch_time = " . time() . "
			WHERE
				task_type = 'page' AND
				task_name = 'item' AND
				task_param IN (
					SELECT file_hash FROM item_flat WHERE author_key = ?
				)
		";
		my @queryParamsAuthorItems;
		push @queryParamsAuthorItems, $pageParam;

		SqliteQuery2($queryAuthorItems, @queryParamsAuthorItems);
	}
	#
	# if ($pageName eq 'item') {
	# 	# cascade refresh items which are by this author
	# 	#todo probably put this in another function
	# 	# could also be done as
	# 	# foreach (author's items) { DBAddPageTouch('item', $item); }
	#
	# 	# touch all of author's items too
	# 	my $queryAuthorItems = "
	# 		UPDATE task
	# 		SET priority = (priority + 1)
	# 		WHERE
	#			task_type = 'page' AND
	# 			task_name = 'item' AND
	# 			task_param IN (
	# 				SELECT file_hash FROM item WHERE author_key = ?
	# 			)
	# 	";
	# 	my @queryParamsAuthorItems;
	# 	push @queryParamsAuthorItems, $pageParam;
	#
	# 	SqliteQuery2($queryAuthorItems, @queryParamsAuthorItems);
	# }

	#todo need to incremenet priority after doing this

	WriteLog("DBAddPageTouch($pageName, $pageParam)");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO task(task_type, task_name, task_param, touch_time) VALUES ";
	} else {
		$query .= ',';
	}

	#todo
	# https://stackoverflow.com/a/34939386/128947
	# insert or replace into poet (_id,Name, count) values (
	# 	(select _id from poet where Name = "SearchName"),
	# 	"SearchName",
	# 	ifnull((select count from poet where Name = "SearchName"), 0) + 1)
	#
	# https://stackoverflow.com/a/3661644/128947
	# INSERT OR REPLACE INTO observations
	# VALUES (:src, :dest, :verb,
	#   COALESCE(
	#     (SELECT occurrences FROM observations
	#        WHERE src=:src AND dest=:dest AND verb=:verb),
	#     0) + 1);


	$query .= "(?, ?, ?, ?)";
	push @queryParams, 'page', $pageName, $pageParam, $touchTime;
} # DBAddPageTouch()

sub DBGetVoteCounts { # Get total vote counts by tag value
# Takes $orderBy as parameter, with vote_count being default;
#todo can probably be converted to parameterized query
	my $orderBy = shift;
	if ($orderBy) {
	} else {
		$orderBy = 'ORDER BY vote_count DESC';
	}

	my $query = "
		SELECT
			vote_value,
			vote_count
		FROM (
			SELECT
				vote_value,
				COUNT(vote_value) AS vote_count
			FROM
				vote
			WHERE
				file_hash IN (SELECT file_hash FROM item)
			GROUP BY
				vote_value
		)
		WHERE
			vote_count >= 1
		$orderBy;
	";

	my @result = SqliteQueryHashRef($query);

	return @result;
}

sub DBGetTagCount { # Gets number of distinct tag/vote values
	my $query = "
		SELECT
			COUNT(vote_value) AS vote_count
		FROM (
			SELECT
				DISTINCT vote_value
			FROM
				vote
			GROUP BY
				vote_value
		)
		LIMIT 1
	";

	my $result = SqliteGetValue($query);

	return $result;
} # DBGetTagCount()

sub DBGetItemLatestAction { # returns highest timestamp in all of item's children
# $itemHash is the item's identifier

	my $itemHash = shift;
	my @queryParams = ();

	# this is my first recursive sql query
	my $query = '
	SELECT MAX(add_timestamp) AS add_timestamp
	FROM item_flat
	WHERE file_hash IN (
		WITH RECURSIVE item_threads(x) AS (
			SELECT ?
			UNION ALL
			SELECT item_parent.item_hash
			FROM item_parent, item_threads
			WHERE item_parent.parent_hash = item_threads.x
		)
		SELECT * FROM item_threads
	)
	';

	push @queryParams, $itemHash;

	return SqliteGetValue($query, @queryParams);
} # DBGetItemLatestAction()

sub DBAddKeyAlias { # adds new author-alias record $key, $alias, $pubkeyFileHash
	# $key = user key
	# $alias = alias/name
	# $pubkeyFileHash = hash of file in which alias was established

	state $query;
	state @queryParams;

	my $key = shift;

	if ($key eq 'flush') {
		if ($query) {
			WriteLog("DBAddKeyAlias(flush)");

			if (!$query) {
				WriteLog('Aborting, no query');
				return;
			}

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = "";
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddKeyAlias('flush');
		$query = '';
		@queryParams = ();
	}

	my $alias = shift;
	my $pubkeyFileHash = shift;

	if (!$query) {
		$query = "INSERT OR REPLACE INTO author_alias(key, alias, file_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= "(?, ?, ?)";
	push @queryParams, $key, $alias, $pubkeyFileHash;

	ExpireAvatarCache($key); # does fresh lookup, no cache
	DBAddPageTouch('author', $key);
} # DBAddKeyAlias()

sub DBAddItemParent { # Add item parent record. $itemHash, $parentItemHash ;
# Usually this is when item references parent item, by being a reply or a vote, etc.
#todo replace with item_attribute
	state $query;
	state @queryParams;

	my $itemHash = shift;

	if ($itemHash eq 'flush') {
		if ($query) {
			WriteLog('DBAddItemParent(flush)');

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddPageTouch('flush');
		DBAddItemParent('flush');
		$query = '';
		@queryParams = ();
	}

	my $parentHash = shift;

	if (!$parentHash) {
		WriteLog('DBAddItemParent: warning: $parentHash missing');
		return;
	}

	if ($itemHash eq $parentHash) {
		WriteLog('DBAddItemParent: warning: $itemHash eq $parentHash');
		return;
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_parent(item_hash, parent_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?)';
	push @queryParams, $itemHash, $parentHash;

	DBAddPageTouch('item', $itemHash);
	DBAddPageTouch('item', $parentHash);
}

sub DBAddItem2 {
	my $filePath = shift;
	my $fileHash = shift;
	my $itemType = shift;
	return DBAddItem($filePath, '', '', $fileHash, $itemType, 0);
}

sub DBAddItem { # $filePath, $fileName, $authorKey, $fileHash, $itemType, $verifyError ; Adds a new item to database
# $filePath = path to text file
# $fileName = item's file name
# $authorKey = author's gpg fingerprint
# $fileHash = hash of item
# $itemType = type of item (currently 'txt' is supported)
# $verifyError = whether there was an error with gpg verification of item

	state $query;
	state @queryParams;

	my $filePath = shift;

	if ($filePath eq 'flush') {
		if ($query) {
			WriteLog("DBAddItem(flush)");
			$query .= ';';
			SqliteQuery2($query, @queryParams);
			$query = '';
			@queryParams = ();
			DBAddItemAttribute('flush');
		}

		return '';
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddItem('flush');
		$query = '';
		@queryParams = ();
	}

	if (-e $filePath) {
		#cool
	} else {
		WriteLog('DBAddItem: warning: -e $filePath returned FALSE; $filePath = ' . $filePath . '; caller = ' . join (',', caller));
	}

	my $fileAbsPath = GetAbsolutePath($filePath);
	if ($fileAbsPath) {
		if ($filePath eq $fileAbsPath) {
			#cool
		} else {
			if (-e $fileAbsPath) {
				WriteLog('DBAddItem: warning: $filePath ne $fileAbsPath, FIXING; caller = ' . join (',', caller));
				$filePath = $fileAbsPath;
			} else {
				WriteLog('DBAddItem: warning: sanity check failed (1); caller = ' . join (',', caller));
				return '';
			}
		}
	} else {
		WriteLog('DBAddItem: warning: sanity check failed (2); caller = ' . join (',', caller));
		return '';
	}

	my $fileName = shift;
	my $authorKey = shift;
	my $fileHash = shift;
	my $itemType = shift;
	my $verifyError = shift; #todo remove this and move it somewhere else

	if (!$verifyError) {
		$verifyError = '';
	}

	#DBAddItemAttribute($fileHash, 'attribute', 'value', 'epoch', 'source');

	if (!$authorKey) {
		$authorKey = '';
	}

	if (GetConfig('admin/expo_site_mode')) {
		if (!$fileName) {
			$fileName = 'Information';
			WriteLog('DBAddItem: warning: $fileName missing; $filePath = ' . $filePath);
		}
	}
#
#	if ($authorKey) {
#		DBAddItemParent($fileHash, DBGetAuthorPublicKeyHash($authorKey));
#	}

	WriteLog("DBAddItem($filePath, $fileName, $authorKey, $fileHash, $itemType, $verifyError);");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item(file_path, file_name, file_hash, item_type) VALUES ";
	} else {
		$query .= ",";
	}
	push @queryParams, $filePath, $fileName, $fileHash, $itemType;

	$query .= "(?, ?, ?, ?)";

	my $filePathRelative = $filePath;
	my $htmlDir = GetDir('html');
	$filePathRelative =~ s/$htmlDir\//\//;

	WriteLog('DBAddItem: $filePathRelative = ' . $filePathRelative . '; $htmlDir = ' . $htmlDir);

	DBAddItemAttribute($fileHash, 'sha1', $fileHash);
	DBAddItemAttribute($fileHash, 'md5', md5_hex(GetFile($filePath)));
	DBAddItemAttribute($fileHash, 'item_type', $itemType);
	DBAddItemAttribute($fileHash, 'file_path', $filePathRelative);

	if ($authorKey) {
		DBAddPageTouch('author', $authorKey);
	}

	if ($verifyError) {
		DBAddItemAttribute($fileHash, 'verify_error', '1');
	}
} # DBAddItem()

sub DBAddEventRecord { # add event record to database; $itemHash, $eventTime, $eventDuration, $signedBy
	state $query;
	state @queryParams;

	WriteLog("DBAddEventRecord()");

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddEventRecord(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddEventRecord('flush');
		$query = '';
		@queryParams = ();
	}

	my $eventTime = shift;
	my $eventDuration = shift;
	my $signedBy = shift;

	if (!$eventTime || !$eventDuration) {
		WriteLog('DBAddEventRecord() sanity check failed! Missing $eventTime or $eventDuration');
		return;
	}

	chomp $eventTime;
	chomp $eventDuration;

	if ($signedBy) {
		chomp $signedBy;
	} else {
		$signedBy = '';
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO event(item_hash, event_time, event_duration, author_key) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?)';
	push @queryParams, $fileHash, $eventTime, $eventDuration, $signedBy;
}

sub DBAddLocationRecord { # $itemHash, $latitude, $longitude, $signedBy ; Adds new location record from latlong token
	state $query;
	state @queryParams;

	WriteLog("DBAddLocationRecord()");

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddLocationRecord(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if (
		$query
			&&
		(
			length($query) >= DBMaxQueryLength()
				||
			scalar(@queryParams) > DBMaxQueryParams()
		)
	) {
		DBAddLocationRecord('flush');
		$query = '';
		@queryParams = ();
	}

	my $latitude = shift;
	my $longitude = shift;
	my $signedBy = shift;

	if (!$latitude || !$longitude) {
		WriteLog('DBAddLocationRecord() sanity check failed! Missing $latitude or $longitude');
		return;
	}

	chomp $latitude;
	chomp $longitude;

	if ($signedBy) {
		chomp $signedBy;
	} else {
		$signedBy = '';
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO location(item_hash, latitude, longitude, author_key) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?)';
	push @queryParams, $fileHash, $latitude, $longitude, $signedBy;
}

sub DBAddVoteRecord { # $fileHash, $ballotTime, $voteValue, $signedBy, $ballotHash ; Adds a new vote (tag) record to an item based on vote/ token
	state $query;
	state @queryParams;

	WriteLog("DBAddVoteRecord()");

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddVoteRecord(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if (!$fileHash) {
		WriteLog('DBAddVoteRecord: warning: called without $fileHash');
		return '';
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddVoteRecord('flush');
		DBAddPageTouch('flush');
		$query = '';
	}

	my $ballotTime = shift;
	my $voteValue = shift;
	my $signedBy = shift;
	my $ballotHash = shift;

	if (!$ballotTime) {
		WriteLog('DBAddVoteRecord: warning: missing $ballotTime; caller: ' . join(',', caller));
		$ballotTime = 0;
		#$ballotTime = time();
		#return '';
	}

#	if (!$signedBy) {
#		WriteLog("DBAddVoteRecord() called without \$signedBy! Returning.");
#	}

	chomp $fileHash;
	chomp $ballotTime;
	chomp $voteValue;

	if ($signedBy) {
		chomp $signedBy;
	} else {
		$signedBy = '';
	}

	if ($ballotHash) {
		chomp $ballotHash;
	} else {
		$ballotHash = '';
	}

	WriteLog('DBAddVoteRecord: ' . $fileHash . ', $ballotTime=' . $ballotTime . ', $voteValue=' . $voteValue . ', $signedBy = ' . $signedBy . ', $ballotHash = ' . $ballotHash);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO vote(file_hash, ballot_time, vote_value, author_key, ballot_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?, ?)';
	push @queryParams, $fileHash, $ballotTime, $voteValue, $signedBy, $ballotHash;

	DBAddPageTouch('tag', $voteValue);
	DBAddPageTouch('item', $fileHash);
}

sub DBGetItemAttribute { # $fileHash, [$attribute] ; returns all if attribute not specified
	my $fileHash = shift;
	my $attribute = shift;

	if ($fileHash) {
		if ($fileHash =~ m/^([a-f0-9]+)$/) {
			WriteLog('DBGetItemAttribute: warning: sanity check passed on $fileHash');
			$fileHash = $1;
		} else {
			WriteLog('DBGetItemAttribute: warning: sanity check FAILED on $fileHash = ' . $fileHash);
			return '';
		}
	} else {
		return '';
	}
	if (!$fileHash) {
		WriteLog('DBGetItemAttribute: warning: where is $fileHash?');
		return '';
	}

	if ($attribute) {
		$attribute =~ s/[^a-zA-Z0-9_]//g;
		#todo add sanity check
	} else {
		$attribute = '';
	}

	my $query = "SELECT attribute, value FROM item_attribute WHERE file_hash LIKE '$fileHash%'";
	if ($attribute) {
		$query .= " AND attribute = '$attribute'";
		return SqliteGetValue($query);
	} else {
	    return SqliteQuery($query);
	    #todo split into two functions?
	}

} # DBGetItemAttribute()

sub DBAddItemAttribute { # $fileHash, $attribute, $value, $epoch, $source # add attribute to item
# currently no constraints
	state $query;
	state @queryParams;

	WriteLog("DBAddItemAttribute()");

	my $fileHash = shift;#

	if ($fileHash eq 'flush') {
		WriteLog("DBAddItemAttribute(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if (!$fileHash) {
		WriteLog('DBAddItemAttribute() called without $fileHash! Returning.');
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddItemAttribute('flush');
		$query = '';
	}

	my $attribute = shift;#
	my $value = shift;#
	my $epoch = shift;#
	my $source = shift;#

	if (!$attribute) {
		WriteLog('DBAddItemAttribute: warning: called without $attribute');
		return '';
	}
	if (!defined($value)) {
		WriteLog('DBAddItemAttribute: warning: called without $value, $attribute = ' . $attribute);
		return '';
	}

	chomp $fileHash;
	chomp $attribute;
	chomp $value;

	if (!$epoch) {
		$epoch = '';
	}
	if (!$source) {
		$source = '';
	}

	chomp $epoch;
	chomp $source;

	WriteLog("DBAddItemAttribute($fileHash, $attribute, $value, $epoch, $source)");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_attribute(file_hash, attribute, value, epoch, source) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?, ?)';
	push @queryParams, $fileHash, $attribute, $value, $epoch, $source;
}

sub DBGetAddedTime { # return added time for item specified
	my $fileHash = shift;
	if (!$fileHash) {
		WriteLog('DBGetAddedTime: warning: $fileHash missing');
		return;
	}
	chomp ($fileHash);

	if (!IsSha1($fileHash)) {
		WriteLog('DBGetAddedTime: warning: called with invalid parameter! returning');
		return;
	}

	if (!IsSha1($fileHash) || $fileHash ne SqliteEscape($fileHash)) {
		WriteLog('DBGetAddedTime: warning: important sanity check failed! this should never happen: !IsSha1($fileHash) || $fileHash ne SqliteEscape($fileHash)');
		return '';
	} #todo ideally this should verify it's a proper hash too

	my $query = "
		SELECT
			MIN(value) AS add_timestamp
		FROM item_attribute
		WHERE
			file_hash = '$fileHash' AND
			attribute IN ('chain_timestamp', 'gpg_timestamp', 'puzzle_timestamp', 'self_timestamp')
	";
	# my $query = "SELECT add_timestamp FROM added_time WHERE file_hash = '$fileHash'";

	WriteLog($query);

    my $returnValue = SqliteGetValue($query);

} # DBGetAddedTime()

sub DBGetItemListByTagList { #get list of items by taglist (as array)
# uses DBGetItemList()
#	my @tagListArray = @_;

#	if (scalar(@tagListArray) < 1) {
#		return;
#	}

	#todo sanity checks

	my @tagListArray = @_;

	my $tagListCount = scalar(@tagListArray);

	my $tagListArrayText = "'" . join ("','", @tagListArray) . "'";

	my %queryParams;
	my $whereClause = "
		WHERE file_hash IN (
			SELECT file_hash FROM (
				SELECT
					COUNT(id) AS vote_count,
						file_hash
				FROM vote
				WHERE vote_value IN ($tagListArrayText)
				GROUP BY file_hash
			) WHERE vote_count >= $tagListCount
		)
	";
	WriteLog("DBGetItemListByTagList");
	WriteLog("$whereClause");

	$queryParams{'where_clause'} = $whereClause;

	#todo this is currently an "OR" select, but it should be an "AND" select.

	return DBGetItemList(\%queryParams);
}

sub DBGetItemList { # get list of items from database. takes reference to hash of parameters
	my $paramHashRef = shift;
	my %params = %{$paramHashRef};

	#supported params:
	#where_clause
	#join_clause
	#order_clause
	#group_by_clause
	#limit_clause

	my $query;
	my $itemFields = DBGetItemFields();

	$query = "
		SELECT
			$itemFields
		FROM
			item_flat
	";

	#todo sanity check: typically, none of these should have a semicolon?
	if (defined ($params{'join_clause'})) {
		$query .= " " . $params{'join_clause'};
	}
	if (defined ($params{'where_clause'})) {
		$query .= " " . $params{'where_clause'};
	}
	if (defined ($params{'group_by_clause'})) {
		$query .= " " . $params{'group_by_clause'};
	}
	if (defined ($params{'order_clause'})) {
		$query .= " " . $params{'order_clause'};
	}
	if (defined ($params{'limit_clause'})) {
		$query .= " " . $params{'limit_clause'};
	}

	WriteLog('DBGetItemList: $query = ' . $query);

	my ($package, $filename, $line) = caller;
	WriteLog('DBGetItemList: caller: ' . $package . ',' . $filename . ', ' . $line);

	my @resultsArray = SqliteQueryHashRef($query);

	WriteLog('DBGetItemList: scalar(@resultsArray) = ' . scalar(@resultsArray));

	shift @resultsArray; #remove headers entry

	return @resultsArray;
} # DBGetItemList()

sub DBGetAllAppliedTags { # return all tags that have been used at least once
	my $query = "
		SELECT DISTINCT vote_value FROM vote
		JOIN item ON (vote.file_hash = item.file_hash)
	";

	my $dbh = SqliteConnect();
	#todo rewrite better

	my $sth = $dbh->prepare($query);

	my @ary;

	$sth->execute();

	$sth->bind_columns(\my $val1);

	while ($sth->fetch) {
		push @ary, $val1;
	}

	return @ary;
}

sub DBGetItemListForAuthor { # return all items attributed to author
	my $author = shift;
	chomp($author);

	if (!IsFingerprint($author)) {
		WriteLog('DBGetItemListForAuthor called with invalid parameter! returning');
		return;
	}
	$author = SqliteEscape($author);

	my %params = {};

	$params{'where_clause'} = "WHERE author_key = '$author'";

	return DBGetItemList(\%params);
}

sub DBGetAuthorList { # returns list of all authors' gpg keys as array
	my $query = "SELECT key FROM author";

	my $dbh = SqliteConnect();
    #todo rewrite better

	my $sth = $dbh->prepare($query);

	$sth->execute();

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
}

sub DBGetAuthorAlias { # returns author's alias by gpg key
	my $key = shift;
	chomp $key;

	if (!IsFingerprint($key)) {
		WriteLog('DBGetAuthorAlias: warning: called with invalid parameter! returning');
		return;
	}

	$key = SqliteEscape($key);

	if ($key) {
		my $query = "SELECT alias FROM author_alias WHERE key = '$key'";
		return SqliteGetValue($query);
	} else {
		return "";
	}
}

sub DBGetAuthorScore { # returns author's total score
# score is the sum of all the author's items' scores
# $key = author's gpg key
	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('Problem! DBGetAuthorScore called with invalid parameter! returning');
		return '';
	}

	state %scoreCache;
	if (exists($scoreCache{$key})) {
		return $scoreCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT IFNULL(author_score, 0) author_score FROM author_score WHERE author_key = '$key'";
		$scoreCache{$key} = SqliteGetValue($query);
		return $scoreCache{$key};
	} else {
		return "";
	}
} # DBGetAuthorScore()

sub DBGetAuthorItemCount { # returns number of items attributed to author identified by $key
# $key = author's gpg key
	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('DBGetAuthorItemCount: warning: called with non-fingerprint parameter, returning');
		return 0;
	}
	if ($key ne SqliteEscape($key)) {
		# should be redundant, but what the heck
		WriteLog('DBGetAuthorItemCount: warning: $key != SqliteEscape($key)');
		return 0;
	}

	state %scoreCache;
	if (exists($scoreCache{$key})) {
		return $scoreCache{$key};
	}

	if ($key) {
		my $query = "SELECT COUNT(file_hash) file_hash_count FROM (SELECT DISTINCT file_hash FROM item_flat WHERE author_key = ?)";
		$scoreCache{$key} = SqliteGetValue($query, $key);
		return $scoreCache{$key};
	} else {
		return 0;
	}

	WriteLog('DBGetAuthorItemCount: warning: unreachable reached');
	return 0;
} # DBGetAuthorItemCount()

sub DBGetAuthorLastSeen { # return timestamp of last item attributed to author
# $key = author's gpg key
	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('Problem! DBGetAuthorLastSeen called with invalid parameter! returning');
		return;
	}

	state %lastSeenCache;
	if (exists($lastSeenCache{$key})) {
		return $lastSeenCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT MAX(item_flat.add_timestamp) AS last_seen FROM item_flat WHERE author_key = '$key'";
		$lastSeenCache{$key} = SqliteGetValue($query);
		return $lastSeenCache{$key};
	} else {
		return "";
	}
}

sub DBGetAuthorPublicKeyHash { # Returns the hash/identifier of the file containing the author's public key
# $key = author's gpg fingerprint
# cached in hash called %authorPubKeyCache

	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('Problem! DBGetAuthorPublicKeyHash called with invalid parameter! returning');
		return;
	}

	state %authorPubKeyCache;
	if (exists($authorPubKeyCache{$key}) && $authorPubKeyCache{$key}) {
		WriteLog('DBGetAuthorPublicKeyHash: returning from memo: ' . $authorPubKeyCache{$key});
		return $authorPubKeyCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT MAX(author_alias.file_hash) AS file_hash FROM author_alias WHERE key = '$key'";
		my $fileHashReturned = SqliteGetValue($query);
		if ($fileHashReturned) {
			$authorPubKeyCache{$key} = SqliteGetValue($query);
			WriteLog('DBGetAuthorPublicKeyHash: returning ' . $authorPubKeyCache{$key});
			return $authorPubKeyCache{$key};
		} else {
			WriteLog('DBGetAuthorPublicKeyHash: database drew a blank, returning 0');
			return 0;
		}
	} else {
		return "";
	}
} # DBGetAuthorPublicKeyHash()

sub DBGetServerKey {
	return DBGetAdminKey();
}

sub DBGetAdminKey { # Returns the pubkey id of the top-scoring admin (or nothing)
# cached in hash called %authorPubKeyCache

	WriteLog('DBGetAdminKey()');

	my $memoKey = 1; #hardcoded in case it needs to change

	state %memoHash;
	if (exists($memoHash{$memoKey}) && $memoHash{$memoKey}) {
		WriteLog('DBGetAdminKey: returning from memo: ' . $memoHash{$memoKey});
		return $memoHash{$memoKey};
	}

	my $key = 1;

	if ($key) { #todo fix non-param sql
		my $query = "SELECT MAX(author_flat.author_key) AS author_key FROM author_flat WHERE file_hash in (SELECT file_hash FROM item_flat WHERE ',' || tags_list || ',' LIKE '%,admin,%') LIMIT 1";
		my $valueReturned = SqliteQueryCachedShell($query);
		if ($valueReturned) {
			$memoHash{$memoKey} = SqliteQueryCachedShell($query);
			WriteLog('DBGetAdminKey: returning ' . $memoHash{$memoKey});
			return $memoHash{$memoKey};
		} else {
			WriteLog('DBGetAdminKey: database drew a blank, returning 0');
			return 0;
		}
	} else {
		WriteLog('DBGetAdminKey: warning: $key was false, returning empty string');
		return '';
	}

	WriteLog('DBGetAdminKey: warning: fall-through, returning empty string');
} # DBGetAdminKey()

sub DBGetItemFields { # Returns fields we typically need to request from item_flat table
# todo this shouldn't have a DB prefix
	my $itemFields = "
		item_flat.file_path file_path,
		item_flat.item_name item_name,
		item_flat.file_hash file_hash,
		item_flat.author_key author_key,
		item_flat.child_count child_count,
		item_flat.parent_count parent_count,
		item_flat.add_timestamp add_timestamp,
		item_flat.item_title item_title,
		item_flat.item_score item_score,
		item_flat.tags_list tags_list,
		item_flat.item_type item_type,
		item_flat.item_order item_order,
		item_flat.item_sequence item_sequence
	";

    #fix spaces
	$itemFields = trim($itemFields);
	$itemFields = str_replace("\t", '', $itemFields);
	#$itemFields =~ s/\s/ /g;
	#$itemFields =~ s/  / /g;

	return $itemFields;
}

sub DBGetTopAuthors { # Returns top-scoring authors from the database
	WriteLog('DBGetTopAuthors() begin');

	my $query = "
		SELECT
			author_key,
			author_alias,
			last_seen,
			item_count
		FROM author_flat
		ORDER BY item_count DESC
		LIMIT 1024;
	";

	my @queryParams = ();

	my $dbh = SqliteConnect();
	#todo rewrite better

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
}

sub DBGetTopItems { # get top items minus flag (hard-coded for now)
	WriteLog('DBGetTopItems()');

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE item_score > 0";
	$queryParams{'order_clause'} = "ORDER BY add_timestamp DESC";
	$queryParams{'limit_clause'} = "LIMIT 100";
	my @resultsArray = DBGetItemList(\%queryParams);

	return @resultsArray;
}

sub DBGetItemsByPrefix { # $prefix ; get items whose hash begins with $prefix
	my $prefix = shift;
	if (!IsItemPrefix($prefix)) {
		WriteLog('DBGetItemsByPrefix: warning: $prefix sanity check failed');
		return '';
	}

	my $itemFields = DBGetItemFields();
	my $whereClause;
	$whereClause = "
		WHERE
			(file_hash LIKE '%$prefix')

	"; #todo remove hardcoding here

	my $query = "
		SELECT
			$itemFields
		FROM
			item_flat
		$whereClause
		ORDER BY
			add_timestamp DESC
		LIMIT 50;
	";

	WriteLog('DBGetItemsByPrefix: $query = ' . $query);
	my @queryParams;

	my $dbh = SqliteConnect();
	#todo rewrite better

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my @resultsArray = ();
	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	WriteLog('DBGetItemsByPrefix: scalar(@resultsArray) = ' . @resultsArray);

	return @resultsArray;
} # DBGetItemsByPrefix()

sub DBGetItemVoteTotals { # get tag counts for specified item, returned as hash of [tag] -> count
	my $fileHash = shift;
	if (!$fileHash) {
		WriteLog('DBGetItemVoteTotals: warning: $fileHash missing, returning');
		return 0;
	}

	chomp $fileHash;

	if (!IsItem($fileHash)) {
		WriteLog('DBGetItemVoteTotals: warning: sanity check failed, returned');
		return;
	}

	WriteLog("DBGetItemVoteTotals($fileHash)");

	my $query = "
		SELECT
			vote_value,
			COUNT(vote_value) AS vote_count
		FROM
			vote
		WHERE
			file_hash = ?
		GROUP BY
			vote_value
		ORDER BY
			vote_count DESC;
	";

	my @queryParams;
	push @queryParams, $fileHash;

    my @result = SqliteQueryHashRef($query, @queryParams);

    shift @result; # remove headers

    my %voteTotals;

    while (@result) {
        my $rowReference = shift @result;
        my %row = %{$rowReference};
        if ($row{'vote_value'}) {
            $voteTotals{$row{'vote_value'}} = $row{'vote_count'};
        }
    }

	return %voteTotals;
} # DBGetItemVoteTotals()

sub PrintBanner2 {
	my $string = shift; #todo sanity checks
	my $width = length($string);

	my $edge = "=" x $width;

	print "\n" ;
	print "\n";
	print $edge;
	print "\n"  ;
	print "\n"   ;
	print $string;
	print "\n"    ;
	print "\n"     ;
	print $edge;
	print "\n"      ;
	print "\n"       ;
}

while (my $arg1 = shift @foundArgs) {
	#print("\n=========================\n");
	PrintBanner2("\nFOUND ARGUMENT: $arg1;\n");
	#print("\n=========================\n");

	# go through all the arguments one at a time
	if ($arg1) {
	    if ($arg1 eq '--test') {
	        SqliteMakeTables();
	        PutFile('./html/txt/test.txt', 'test');
	        DBAddItem('./html/txt/test.txt', 'b', 'c', 'd', 'txt');
	        DBAddItem('flush');
	        my @testParams;
	        push @testParams, 'ha';
	        push @testParams, 'ha';
	        push @testParams, 'ha';


	        print "\n\n".'SqliteGetQueryString(...) = ' . SqliteGetQueryString('select ? ? ?' . "\n" . "thanks", @testParams);
	        print "\n\n".'SqliteQuery(...) = ' . SqliteQuery('select count(*) as c from item limit 1');
	        print "\n\n".'SqliteGetValue(...) = ' . SqliteGetValue('select count(*) as c from item limit 1');
			print "\n\n".'DBGetItemCount() = ' . DBGetItemCount();
			print "\n\n".'SqliteQueryHashRef("select * from item") = ' . Dumper(SqliteQueryHashRef("select * from item"));
			#confess SqliteQueryHashRef("select * from item");
	    }
    }
}

1;
