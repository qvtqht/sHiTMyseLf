#!/usr/bin/perl -T
#freebsd: #!/usr/local/bin/perl -T

# indexes one file or all files eligible for indexing
# --all .... all eligible files
# [path] ... index specified file
# --chain .. chain.log file (contains timestamps)

use strict;
use warnings;
use utf8;
#use HTML::Entities qw(decode_entities);

my @argsFound;
while (my $argFound = shift) {
	push @argsFound, $argFound;
}

use Digest::SHA qw(sha512_hex);

require('./gpgpg.pl');
require('./utils.pl');

sub MakeChainIndex { # $import = 1; reads from log/chain.log and puts it into item_attribute table
	# note: this is kind of a hack, and non-importing validation should just be separate own sub
	# note: this hack seems to work ok

	my $import = shift;
	if (!defined($import)) {
		$import = 1;
	} else {
		chomp $import;
		$import = ($import ? 1 : 0);
	}
	WriteMessage("MakeChainIndex($import)");

	if (GetConfig('admin/read_chain_log')) {
		WriteLog('MakeChainIndex: admin/read_chain_log was TRUE');
		my $chainLog = GetFile('html/chain.log');

		if (defined($chainLog) && $chainLog) {
			WriteLog('MakeChainIndex: $chainLog was defined');
			my @addedRecord = split("\n", $chainLog);

			my $previousLine = '';
			my $sequenceNumber = 0;

			my %return;

			foreach my $currentLine (@addedRecord) {
				WriteLog("MakeChainIndex: $currentLine");
				WriteMessage("Verifying Chain: $sequenceNumber");

				my ($fileHash, $addedTime, $proofHash) = split('\|', $currentLine);
				my $expectedHash = md5_hex($previousLine . '|' . $fileHash . '|' . $addedTime);

				if ($expectedHash ne $proofHash) {
					WriteLog('MakeChainIndex: warning: proof hash mismatch. abandoning chain import');

					# save the current chain.log and create new one
					# new chain.log should go up to the point of the break
					my $curTime = GetTime();
					my $moveChain = `mv html/chain.log html/chain.log.$curTime ; head -n $sequenceNumber html/chain.log.$curTime > html/chain_new.log; mv html/chain_new.log html/chain.log`;

					# make a record of what just happened
					my $moveChainMessage = 'Chain break detected. Timestamps for items may reset. #meta #warning ' . $curTime;
					PutFile('html/txt/chain_break_' . $curTime . '.txt');

					if ($import) {
						MakeChainIndex($import); # recurse
					}

					WriteLog('MakeChainIndex: return 0');
					return 0;
				}

				DBAddItemAttribute($fileHash, 'chain_timestamp', $addedTime);
				DBAddItemAttribute($fileHash, 'chain_sequence', $sequenceNumber);
				DBAddItemAttribute($fileHash, 'chain_previous', $previousLine);
				WriteLog('MakeChainIndex: $sequenceNumber = ' . $sequenceNumber);
				WriteLog('MakeChainIndex: (next item stub/aka checksum) $previousLine = ' . $previousLine);

				$return{'chain_sequence'} = $sequenceNumber;
				$return{'chain_previous'} = $previousLine;
				$return{'chain_timestamp'} = $addedTime;

				$sequenceNumber = $sequenceNumber + 1;
				$previousLine = $currentLine;
			} # foreach $currentLine (@addedRecord)

			WriteMessage("==========================");
			WriteMessage("Verifying Chain: Complete!");
			WriteMessage("==========================");

			DBAddItemAttribute('flush');

			return %return;
		} # $chainLog
		else {
			WriteLog('MakeChainIndex: warning: $chainLog was NOT defined');
			return 0;
		}
	} # GetConfig('admin/read_chain_log')
	else {
		WriteLog('MakeChainIndex: admin/read_chain_log was FALSE');
		return 0;
	}

	WriteLog('MakeChainIndex: warning: unreachable was reached');
	return 0;
} # MakeChainIndex()

sub GetTokenDefs {
	my @tokenDefs = (
		{ # cookie of user who posted the message
			'token'   => 'cookie',
			'mask'    => '^(cookie)(\W+)([0-9A-F]{16})',
			'mask_params'    => 'mgi',
			'message' => '[Cookie]'
		},
		{ # allows cookied user to set own name
			'token'   => 'my_name_is',
			'mask'    => '^(my name is)(\W+)([A-Za-z0-9\'_\., ]+)\r?$',
			'mask_params'    => 'mgi',
			'message' => '[MyNameIs]'
		},
		{ # parent of item (to which item is replying)
			'token'   => 'parent',
			'mask'    => '^(\>\>)(\W?)([0-9a-f]{40})', # >>
			'mask_params' => 'mg',
			'message' => '[Parent]'
		},
		{ # parent of item (to which item is replying)
			'token'   => 'signature_divider',
			'mask'    => '^(-- )()()$', # -- \n
			'mask_params' => 'mg',
			'message' => '[Signature Divider]'
		},
	#				{ # reference to item
	#					'token'   => 'itemref',
	#					'mask'    => '(\W?)([0-9a-f]{8})(\W?)',
	#					'mask_params' => 'mg',
	#					'message' => '[Reference]'
	#				}, #todo make it ensure item exists before parsing
		{ # title of item, either self or parent. used for display when title is needed #title title:
			'token'   => 'title',
			'mask'    => '^(title)(\W)(.+)$',
			'mask_params'    => 'mg',
			'apply_to_parent' => 1,
			'message' => '[Title]'
		},
		{ # begin time, self only:
			'token'   => 'begin',
			'mask'    => '^(begin)(\W)(.+)$',
			'mask_params'    => 'mg',
			'message' => '[Begin]'
		},
		{ # duration, self only:
			'token'   => 'duration',
			'mask'    => '^(duration)(\W)(.+)$',
			'mask_params'    => 'mg',
			'message' => '[Duration]'
		},
		{ # track: self only:
			'token'   => 'track',
			'mask'    => '^(track)(\W)(.+)$',
			'mask_params'    => 'mg',
			'message' => '[Track]'
		},
		{ # name of item, either self or parent. used for display when title is needed #title title:
			'token'   => 'name',
			'mask'    => '^(name)(\W)(.+)$',
			'mask_params'    => 'mg',
			'apply_to_parent' => 1,
			'message' => '[Name]'
		},
		{ # order of item, either self or parent. used for ordering things
			'token'   => 'order',
			'mask'    => '^(order)(\W)(.+)$',
			'mask_params'    => 'mg',
			'apply_to_parent' => 1,
			'message' => '[Order]'
		},
		{ # used for image alt tags #todo
			'token'   => 'alt',
			'mask'    => '^(alt)(\W+)(.+)$',
			'mask_params'    => 'mg',
			'apply_to_parent' => 1,
			'message' => '[Alt]'
		},
		{ # hash of line from access.log where item came from (for parent item)
			'token'   => 'access_log_hash',
			'mask'    => '^(AccessLogHash)(\W+)(.+)$',
			'mask_params'    => 'mgi',
			'apply_to_parent' => 1,
			'message' => '[AccessLogHash]'
		},
		{ # solved puzzle (user id, timestamp, random number between 0 and 1
			# together they must hash to the prefix specified in config/puzzle/accept
			# the default prefix (also accepted) is specified in config/puzzle/prefix
			'token' => 'puzzle',
			'mask' => '^()()([0-9A-F]{16} [0-9]{10} 0\.[0-9]+)',
			'mask_params' => 'mg',
			'message' => '[Puzzle]'
		},
		{ # anything beginning with http and up to next space character (or eof)
			'token' => 'url',
			'mask' => '()()(http[\S]+)',
			'mask_params' => 'mg',
			'message' => '[URL]',
			'apply_to_parent' => 0
		},
		{ # hashtags, currently restricted to latin alphanumeric and underscore
			'token' => 'hashtag',
			'mask'  => '(\#)()([a-zA-Z0-9_]{1,32})',
			'mask_params' => 'mgi',
			'message' => '[HashTag]',
			'apply_to_parent' => 1
		},
		{ # verify token, for third-party identification
			# example: verify http://www.example.com/user/JohnSmith/
			# must be child of pubkey item
			'token' => 'verify',
			'mask'  => '^(verify)(\W)(.+)$',
			'mask_params' => 'mgi',
			'message' => '[Verify]',
			'apply_to_parent' => 1
		},
		{ # #sql token, returns sql results (for privileged users)
			# example: #sql select author_key, alias from author_alias
			# must be a select statement, no update etc
			# to begin with, limited to 1 line; #todo
			'token' => 'sql',
			'mask' => '^(sql)(\W).+$',
			'mask_params' => 'mgi',
			'message' => '[SQL]',
			'apply_to_parent' => 0
		},
		{ # config token for setting configuration
			# config/admin/anyone_can_config = allow anyone to config (for open-access boards)
			# config/admin/signed_can_config = allow only signed users to config
			# config/admin/cookied_can_config = allow any user (including cookies) to config
			# otherwise, only admin user can config
			# also, anything under config/admin/ is still restricted to admin user only
			# admin user must have a pubkey
			'token' => 'config',
			'mask'  => '^(config)(\W)(.+)$',
			'mask_params' => 'mgi',
			'message' => '[Config]',
			'apply_to_parent' => 1
		}
	);

		# REGEX cheatsheet
		# ================
		#
		# \w word
		# \W NOT word
		# \s whitespace
		# \S NOT whitespace
		#
		# /s = single-line (changes behavior of . metacharacter to match newlines)
		# /m = multi-line (changes behavior of ^ and $ to work on lines instead of entire file)
		# /g = global (all instances)
		# /i = case-insensitive
		# /e = eval
		#
		# allowed flag combinations:
		# mg (??)
		# mgi ??
		# gi    ??
		# g       ??
		#

	return @tokenDefs;
} # GetTokenDefs()

sub IndexHtmlFile { # $file | 'flush' ; indexes one text file into database
# DRAFT
# DRAFT
# DRAFT
# DRAFT
# DRAFT
	my $SCRIPTDIR = GetDir('script');
	my $HTMLDIR = GetDir('html');
	my $TXTDIR = GetDir('txt');

	my $file = shift;
	chomp($file);

	if ($file eq 'flush') {
		IndexTextFile('flush');
	}

	my $html = GetFile($file);

	#print $file;
	#sleep 3;

	#print $html;
	#sleep 3;


	my @matches;

	print length($html)."\n";

	$html =~ s/\<span[^>]+\>/<span>/g;

	print length($html)."\n";

	sleep 3;

	while ($html =~/(?<=<span>)(.*?)(?=<\/span>)/g) {
	  push @matches, $1;
	}

	foreach my $m (@matches) {
		print trim($m), "\n===\n";
		#todo htmldecode

		$m = str_replace('<p>', "\n\n", $m);
		#$m = decode_entities($m);
		my $mHash = sha1_hex($m);
		my $mFilename = GetPathFromHash($mHash);
		PutFile($mFilename, $m);
	}

	#if ($html =~ m/<span.+>(.+)<\/span>/g) {
		#print Dumper($1);
		#print ';-)';
#		print "Word is $1, ends at position ", pos $x, "\n";
		sleep 3;
	#}#

	sleep 3;
} # IndexHtmlFile()

sub IndexTextFile { # $file | 'flush' ; indexes one text file into database
# Reads a given $file, parses it, and puts it into the index database
# If ($file eq 'flush'), flushes any queued queries
# Also sets appropriate task entries
	my $SCRIPTDIR = GetDir('script');
	my $HTMLDIR = GetDir('html');
	my $TXTDIR = GetDir('txt');

	my $file = shift;
	chomp($file);

	if ($file eq 'flush') {
		WriteLog("IndexTextFile(flush)");
		DBAddKeyAlias('flush');
		DBAddItem('flush');
		DBAddVoteRecord('flush');
		DBAddEventRecord('flush');
		DBAddItemParent('flush');
		DBAddPageTouch('flush');
		DBAddTask('flush');
		DBAddConfigValue('flush');
		DBAddItemAttribute('flush');
		DBAddLocationRecord('flush');
		return 1;
	}

	WriteLog('IndexTextFile: $file = ' . $file);

	if (GetConfig('admin/organize_files')) {
		# renames files to their hashes
		$file = OrganizeFile($file);
	}

	my $fileHash = ''; # hash of file contents
	$fileHash = GetFileHash($file);

	my $titleCandidate = '';

	if (!$file || !$fileHash) {
		WriteLog('IndexTextFile: warning: $file or $fileHash missing; returning');
		WriteLog('IndexTextFile: warning: $file = ' . ($file ? $file : 'FALSE'));
		WriteLog('IndexTextFile: warning: $fileHash = ' . ($fileHash ? $fileHash : 'FALSE'));
		return 0;
	}

	# if the file is present in deleted.log, get rid of it and its page, return
	if (IsFileDeleted($file, $fileHash)) {
		# write to log
		WriteLog('IndexTextFile: IsFileDeleted() returned true, returning');
		if ($file) {
			WriteLog('IndexTextFile: IsFileDeleted() $file = ' . $file);
		}
		if ($fileHash) {
			WriteLog('IndexTextFile: IsFileDeleted() $file = ' . $file);
		}
		return 0;
	}

	my $addedTime = 0;

	WriteLog('IndexTextFile: $fileHash = ' . $fileHash);
	if (GetConfig('admin/logging/write_chain_log')) {
		$addedTime = AddToChainLog($fileHash);
		#todo there is a bug here, should not depend on chain log
	}

	if (GetCache('indexed/' . $fileHash)) {
		WriteLog('IndexTextFile: aleady indexed, returning. $fileHash = ' . $fileHash);
		return $fileHash;
	}

	my $authorKey = '';

	if (substr(lc($file), length($file) -4, 4) eq ".txt") {
		if (GetConfig('admin/gpg/enable')) {
			$authorKey = GpgParse($file) || '';
#
#			if ($authorKey eq 'AE85DDBDCED2E285') {
#				#todo #scaffolding
#				my $queryAddAdmin = "insert into vote(file_hash, vote_value) values('$fileHash', 'admin')";
#				SqliteQuery2($queryAddAdmin);
#			}
		}
		my $message = GetFileMessage($file);

		if (!defined($message) || !$message) {
			WriteLog('IndexTextFile: warning: $message was not defined, setting to empty string');
			$message = '';
		}

		if (
			GetConfig('admin/index/filter_common_noise')
			&&
			$message =~ m/^[0-9a-f][0-9a-f]\/[0-9a-f][0-9a-f]\/[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\.html$/
			||
			$message =~ m/^[0-9a-f][0-9a-f]\/[0-9a-f][0-9a-f]\/[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\.html\?message=[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/
			||
			$message =~ m/^\<a href=\"item\?id.+\"\>.+\<\/a\>$/

		) {
			AppendFile('log/deleted.log', $fileHash);
			if (IsFileDeleted($file, $fileHash)) {
				#cool
			}
			return 0;
		}

		my $detokenedMessage = $message;
		my %hasToken;

		if ($detokenedMessage) {
			my $cussWords = GetTemplate('list/scunthorpe');
			# #scunthorpe

			if ($cussWords) {
				my $cussWordCount = 0;

				my @cussWord = split("\n", $cussWords);
				if (@cussWord) {
					for my $word (@cussWord) {
						$word = trim($word);
#						if ($word && (index($message, $word) != -1)) {
						if ($word && $message =~ m/\W$word\W/i) {
							WriteLog('IndexTextFile: scunthorpe: $word = ' . $word);
							$cussWordCount ++;
						}
					}

					if ($cussWordCount) {
						#print "DBAddVoteRecord($fileHash, 0, 'scunthorpe')\n";
						#print `sleep 1`;
						DBAddVoteRecord($fileHash, 0, 'scunthorpe');
					}
				}

			}
		}


		my @tokenMessages;
		my @tokensFound;
		{ #tokenize into @tokensFound
			###################################################
			# TOKEN FIRST PASS PARSING BEGINS HERE
			# token: identifier
			# mask: token string, separator, parameter
			# params: parameters for regex matcher
			# message: what's displayed in place of token for user
			my @tokenDefs = GetTokenDefs();

			# parses standard issue tokens, definitions above
			# stores into @tokensFound

			my $limitTokensPerFile = int(GetConfig('admin/index/limit_tokens_per_file'));
			if (!$limitTokensPerFile) {
				$limitTokensPerFile = 500;
			}

			#todo sanity check on $limitTokensPerFile;

			foreach my $tokenDefRef (@tokenDefs) {
				my %tokenDef = %$tokenDefRef;
				my $tokenName = $tokenDef{'token'};
				my $tokenMask = $tokenDef{'mask'};
				my $tokenMaskParams = $tokenDef{'mask_params'};
				my $tokenMessage = $tokenDef{'message'};

				WriteLog('IndexTextFile: $tokenMask = ' . $tokenMask);

				if (GetConfig("admin/token/$tokenName") && $detokenedMessage) {
					# token is enabled, and there is still something left to parse

					my @tokenLines;

					if ($tokenMaskParams eq 'mg') {
						# probably an easier way to do this, but i haven't found it yet
						@tokenLines = ($detokenedMessage =~ m/$tokenMask/mg);
					} elsif ($tokenMaskParams eq 'mgi') {
						@tokenLines = ($detokenedMessage =~ m/$tokenMask/mgi);
					} elsif ($tokenMaskParams eq 'gi') {
						@tokenLines = ($detokenedMessage =~ m/$tokenMask/gi);
					} elsif ($tokenMaskParams eq 'g') {
						@tokenLines = ($detokenedMessage =~ m/$tokenMask/g);
					} else {
						WriteLog('IndexTextFile: warning: sanity check failed: $tokenMaskParams unaccounted for');
					}

					WriteLog('IndexTextFile: found tokens: ' . scalar(@tokensFound) . ' + lines: ' . scalar(@tokenLines));

					if (scalar(@tokensFound) + scalar(@tokenLines) > $limitTokensPerFile) {
						# i don't remember why both are counted here...
						WriteLog('IndexTextFile: warning: found too many tokens, skipping. $file = ' . $file);
						return 0;
					} else {
						WriteLog('IndexTextFile: sanity check passed');
					}

					while (@tokenLines) {
						my $foundTokenName = shift @tokenLines;
						my $foundTokenSpacer = shift @tokenLines;
						my $foundTokenParam = shift @tokenLines;

						$foundTokenParam = trim($foundTokenParam);

						my $reconLine = $foundTokenName . $foundTokenSpacer . $foundTokenParam;
						WriteLog('IndexTextFile: token/' . $tokenName . ' : ' . $reconLine);

						my %newTokenFound;
						$newTokenFound{'token'} = $tokenName;
						$newTokenFound{'param'} = $foundTokenParam;
						$newTokenFound{'recon'} = $reconLine;
						$newTokenFound{'message'} = $tokenMessage;
						$newTokenFound{'apply_to_parent'} = $tokenDef{'apply_to_parent'};
						push(@tokensFound, \%newTokenFound);

						if ($tokenName eq 'hashtag') {
							$hasToken{$foundTokenParam} = 1;
						}

						$detokenedMessage = str_replace($reconLine, '', $detokenedMessage);
					} # while (@tokenLines)
				} # GetConfig("admin/token/$tokenName") && $detokenedMessage
			} # @tokenDefs

			# TOKEN FIRST PASS PARSING ENDS HERE
			# @tokensFound now has all the found tokens
			WriteLog('IndexTextFile: scalar(@tokensFound) = ' . scalar(@tokensFound));
			###################################################
		} #tokenize into @tokensFound

		my @itemParents;

		{ # first pass, look for cookie, parent, auth
			foreach my $tokenFoundRef (@tokensFound) {

				my %tokenFound = %$tokenFoundRef;
				if ($tokenFound{'token'} && $tokenFound{'param'}) {

					if ($tokenFound{'token'} eq 'cookie') {
						if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
							DBAddItemAttribute($fileHash, 'cookie_id', $tokenFound{'param'}, 0, $fileHash);
							$message = str_replace($tokenFound{'recon'}, $tokenFound{'message'}, $message);
							$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
							if (!$authorKey) {
								$authorKey = $tokenFound{'param'};
							}
						} else {
							WriteLog('IndexTextFile: warning: cookie: sanity check failed');
						}
					} # cookie

					if ($tokenFound{'token'} eq 'parent') {
						if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
							WriteLog('IndexTextFile: DBAddItemParent(' . $fileHash . ',' . $tokenFound{'param'} . ')');
							DBAddItemParent($fileHash, $tokenFound{'param'});
							push(@itemParents, $tokenFound{'param'});

							# $message = str_replace($tokenFound{'recon'}, $tokenFound{'message'}, $message);
							$message = str_replace($tokenFound{'recon'}, '>>' . $tokenFound{'param'}, $message); #hacky
							$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
						} else {
							WriteLog('IndexTextFile: warning: parent: sanity check failed');
						}
					} # parent
				} #param
			} # foreach
		} # first pass, look for cookie, parent, auth

		WriteLog('IndexTextFile: %hasToken: ' . join(',', keys(%hasToken)));

		DBAddItem2($file, $fileHash, 'txt');

		if ($hasToken{'example'}) {
			push @tokenMessages, 'Token #example was found, other tokens will be ignored.';
			DBAddVoteRecord($fileHash, 0, 'example');
		} # #example
		else { # not #example
			my $itemTimestamp = $addedTime;
			if (!$itemTimestamp) {
				$itemTimestamp = DBGetItemAttribute($fileHash, 'chain_timestamp');#todo bug here, depends on chain being on
			}
			my @hashTagsAppliedToParent;

			foreach my $tokenFoundRef (@tokensFound) {
				my %tokenFound = %$tokenFoundRef;
				if ($tokenFound{'token'} && $tokenFound{'param'}) {
					WriteLog('IndexTextFile: token, param: ' . $tokenFound{'token'} . ',' . $tokenFound{'param'});

					if (
						$tokenFound{'token'} eq 'title' || #title
						$tokenFound{'token'} eq 'name' ||
						$tokenFound{'token'} eq 'order' ||
						$tokenFound{'token'} eq 'alt' ||
						$tokenFound{'token'} eq 'access_log_hash' ||
						$tokenFound{'token'} eq 'begin' ||
						$tokenFound{'token'} eq 'duration' ||
						$tokenFound{'token'} eq 'track' ||
						$tokenFound{'token'} eq 'url'
					) {
						# these tokens are applied to:
						# 	if item has parent, then to the parent
						# 		otherwise: to self
						WriteLog('IndexTextFile: token_found: ' . $tokenFound{'recon'});

						if (!$itemTimestamp) {
							WriteLog('IndexTextFile: warning: $itemTimestamp being set to time()');
							$itemTimestamp = time(); #todo #fixme #stupid
						}

						if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
							WriteLog('IndexTextFile: %tokenFound: ' . Dumper(%tokenFound));
							if ($tokenFound{'apply_to_parent'} && @itemParents) {
								foreach my $itemParent (@itemParents) {
									DBAddItemAttribute($itemParent, $tokenFound{'token'}, $tokenFound{'param'}, $itemTimestamp, $fileHash);
								}
							} else {
								DBAddItemAttribute($fileHash, $tokenFound{'token'}, $tokenFound{'param'}, $itemTimestamp, $fileHash);
							}
						} else {
							WriteLog('IndexTextFile: warning: ' . $tokenFound{'token'} . ' (generic): sanity check failed');
						}

						DBAddVoteRecord($fileHash, 0, $tokenFound{'token'});
					} # title, access_log_hash, url, alt, name

					if ($tokenFound{'token'} eq 'config') { #config
						if (
							IsAdmin($authorKey) || #admin can always config #todo
							GetConfig('admin/anyone_can_config') || # anyone can config
							(GetConfig('admin/signed_can_config') || 0) || # signed can config #todo
							(GetConfig('admin/cookied_can_config') || 0) # cookied can config #todo
						) {
							my ($configKey, $configSpacer, $configValue) = ($tokenFound{'param'} =~ m/(.+)(\W)(.+)/);

							WriteLog('IndexTextFile: $configKey = ' . (defined($configKey) ? $configKey : '(undefined)'));
							WriteLog('IndexTextFile: $configSpacer = ' . (defined($configSpacer) ? $configSpacer : '(undefined)'));
							WriteLog('IndexTextFile: $configValue = ' . (defined($configValue) ? $configValue : '(undefined)'));

							if (!defined($configKey) || !$configKey || !defined($configValue)) {
								WriteLog('IndexTextFile: warning: $configKey or $configValue missing from $tokenFound token');
							} else {
								my $configKeyActual = $configKey;
								if ($configKey && defined($configValue) && $configValue ne '') {
									# alias 'theme' to 'html/theme'
									# $configKeyActual = $configKey;
									if ($configKey eq 'theme') {
										# alias theme to html/theme
										$configKeyActual = 'html/theme';
									}
									#todo merge html/clock and html/clock_format
									# if ($configKey eq 'clock') {
									# 	# alias theme to html/theme
									# 	$configKeyActual = 'clock_format';
									# }
									$configValue = trim($configValue);
								}

								if (IsAdmin($authorKey) || ConfigKeyValid($configKeyActual)) { #todo
									# admins can write to any config
									# non-admins can only write to existing config keys (and not under admin/)

									# #todo create a whitelist of safe keys non-admins can change

									DBAddConfigValue($configKeyActual, $configValue, 0, $fileHash);

									#this must be called before WriteIndexedConfig()
									#because we must flush to indexing database
									#because that's where WriteIndexedConfig() gets its new config
									IndexTextFile('flush'); #todo optimize

									WriteIndexedConfig(); # config token in index.pl
									$message = str_replace($tokenFound{'recon'}, "[Config: $configKeyActual = $configValue]", $message);
									$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);

									if (!$titleCandidate) {
										$titleCandidate = 'Configuration change';
									}
								} else {
									# token tried to pass unacceptable config key
									$message = str_replace($tokenFound{'recon'}, "[Not Accepted: $configKeyActual]", $message);
									$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
								}
							} # sanity check
						} # has permission to config
					} # #config


					if ($tokenFound{'token'} eq 'puzzle') { # puzzle
						my ($puzzleAuthorKey, $mintedAt, $checksum) = split(' ', $tokenFound{'param'});
						WriteLog("IndexTextFile: token: puzzle: $puzzleAuthorKey, $mintedAt, $checksum");

						#todo must match message author key
						if ($puzzleAuthorKey ne $authorKey) {
							WriteLog('IndexTextFile: puzzle: warning: $puzzleAuthorKey ne $authorKey');
						} else {
							my $hash = sha512_hex($tokenFound{'recon'});
							my $configPuzzleAccept = GetConfig('puzzle/accept');
							if (!$configPuzzleAccept) {
								$configPuzzleAccept = '';
							}
							my @acceptPuzzlePrefix = split("\n", $configPuzzleAccept);
							push @acceptPuzzlePrefix, GetConfig('puzzle/prefix');
							my $puzzleAccepted = 0;

							foreach my $puzzlePrefix (@acceptPuzzlePrefix) {
								$puzzlePrefix = trim($puzzlePrefix);
								if (!$puzzlePrefix) {
									next;
								}

								my $puzzlePrefixLength = length($puzzlePrefix);
								if (
									(substr($hash, 0, $puzzlePrefixLength) eq $puzzlePrefix) && # hash matches
									($authorKey eq $puzzleAuthorKey) # key matches cookie or fingerprint
								) {
									$message =~ s/$tokenFound{'recon'}/[$puzzlePrefix]/g;
									# $message =~ s/$tokenFound{'recon'}/[Solved puzzle with this prefix: $puzzlePrefix]/g;
									DBAddItemAttribute($fileHash, 'puzzle_timestamp', $mintedAt);
									DBAddVoteRecord($fileHash, $mintedAt, 'puzzle');
									$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
									$puzzleAccepted = 1;

									last;
									#DBAddItemAttribute('
									#$message .= 'puzzle valid!'; #$reconLine . "\n" . $hash;
								}
							}#foreach my $puzzlePrefix (@acceptPuzzlePrefix) {
						}
					} # puzzle


					if ($tokenFound{'token'} eq 'my_name_is') { # my_name_is
						if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
							WriteLog('IndexTextFile: my_name_is: sanity check PASSED');
							if ($authorKey) {
								$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
								my $nameGiven = $tokenFound{'param'};
								$message =~ s/$tokenFound{'recon'}/[my name is: $nameGiven]/g;

								DBAddKeyAlias($authorKey, $tokenFound{'param'}, $fileHash);
								DBAddKeyAlias('flush');

								if (!$titleCandidate) {
									$titleCandidate = $tokenFound{'param'} . ' has self-identified';
								}
							}
						} else {
							WriteLog('IndexTextFile: warning: my_name_is: sanity check FAILED');
						}
					} # my_name_is

					if ($tokenFound{'token'} eq 'hashtag') { #hashtag
						if ($tokenFound{'param'} eq 'remove' && GetConfig('admin/token/remove')) { #remove
							if (scalar(@itemParents)) {
								WriteLog('IndexTextFile: Found #remove token, and item has parents');
								foreach my $itemParent (@itemParents) {
									# find the author of the item in question.
									# this will help us determine whether the request can be fulfilled
									my $parentItemAuthor = DBGetItemAuthor($itemParent) || '';
									#WriteLog('IndexTextFile: #remove: IsAdmin = ' . IsAdmin($authorKey) . '; $authorKey = ' . $authorKey . '; $parentItemAuthor = ' . $parentItemAuthor);
									WriteLog('IndexTextFile: #remove: $authorKey = ' . $authorKey);
									#WriteLog('IndexTextFile: #remove: IsAdmin = ' . IsAdmin($authorKey));
									WriteLog('IndexTextFile: #remove: $parentItemAuthor = ' . $parentItemAuthor);

									# at this time only signed requests to remove are honored
									if (
										$authorKey # is signed
											&&
											(
												IsAdmin($authorKey)                   # signed by admin
													||                             # OR
												($authorKey eq $parentItemAuthor) 	   # signed by same as author
											)
									) {
										WriteLog('IndexTextFile: #remove: Found seemingly valid request to remove');

										AppendFile('log/deleted.log', $itemParent);
										DBDeleteItemReferences($itemParent);

										my $htmlFilename = $HTMLDIR . '/' . GetHtmlFilename($itemParent);
										if (-e $htmlFilename) {
											WriteLog('IndexTextFile: #remove: ' . $htmlFilename . ' exists, calling unlink()');
											unlink($htmlFilename);
										}
										else {
											WriteLog('IndexTextFile: #remove: ' . $htmlFilename . ' does NOT exist, very strange');
										}

										my $itemParentPath = GetPathFromHash($itemParent);
										if (-e $itemParentPath) {
											# this only works if organize_files is on and file was put into its path
											# otherwise it will be removed at another time
											WriteLog('IndexTextFile: removing $itemParentPath = ' . $itemParentPath);
											WriteLog('IndexTextFile: unlink($itemParentPath); $itemParentPath = ' . $itemParentPath);
											#unlink($itemParentPath);
										}

										if (!GetConfig('admin/logging/record_remove_action')) {
											# log_remove remove_log
											#todo unlink the file represented by $voteFileHash, not $file (huh???)

											WriteLog('IndexTextFile: #remove: trying to remove #remove action source file');

											if (-e $file) {
												WriteLog('IndexTextFile: #remove: source file exists! ' . $file . ', calling unlink()');

												# this removes the remove call itself
												if (!trim($detokenedMessage)) {
													WriteLog('IndexTextFile: #remove: passed $detokenedMessage sanity check for ' . $file);

													DBAddTask('filesys', 'unlink', $file, time());
													#unlink($file);

													if (-e $file) {
														WriteLog('IndexTextFile: warning: just called unlink($file), but still exists: $file = ' . $file);
													}
												} else {
													WriteLog('IndexTextFile: #remove: $detokenedMessage is not FALSE, skipping file removal');
												}
											}
											else {
												WriteLog('IndexTextFile: #remove: warning: $file = ' . $file . ' does NOT exist');
											}
										}

										#todo unlink and refresh, or at least tag as needing refresh, any pages which include deleted item
									} # has permission to remove
									else {
										WriteLog('IndexTextFile: Request to remove file was not found to be valid');
									}
								} # foreach my $itemParent (@itemParents)
							} # has parents
						} # #remove
						elsif (
							$tokenFound{'param'} eq 'admin' || #admin token needs permission
							$tokenFound{'param'} eq 'approve' #approve token needs permission
						) { # #admin #approve tokens which need permissions
							my $hashTag = $tokenFound{'param'};
							if (scalar(@itemParents)) {
								WriteLog('IndexTextFile: Found permissioned token ' . $tokenFound{'param'} . ', and item has parents');
								foreach my $itemParent (@itemParents) {
									# find the author of this item
									# this will help us determine whether the request can be fulfilled

									if (
										$authorKey # is signed
										&&
										(
											IsAdmin($authorKey) # signed by admin
											||
											(
												GetConfig('admin/allow_self_admin_when_adminless') &&
												!DBGetAdminKey()
												 #todo parent should be pubkey and item should be signed
											)
											||
											(
												GetConfig('admin/allow_self_admin_whenever')
												 #todo parent should be pubkey and item should be signed
											)
										)

									) {
										WriteLog('IndexTextFile: #admin: Found seemingly valid request');
										DBAddVoteRecord($itemParent, 0, $hashTag, $authorKey, $fileHash);

										my $authorGpgFingerprint = DBGetItemAttribute($itemParent, 'gpg_fingerprint');
										if ($authorGpgFingerprint =~ m/([0-9A-F]{16})/) {
											#todo this is dirty, dirty hack
											$authorGpgFingerprint = $1;
										} else {
											$authorGpgFingerprint = '';
										}

										WriteLog('IndexTextFile: #admin: $authorGpgFingerprint = ' . $authorGpgFingerprint);

										if ($authorGpgFingerprint) {
											WriteLog('IndexTextFile: #admin: found $authorGpgFingerprint');
											ExpireAvatarCache($authorGpgFingerprint);
										} else {
											WriteLog('IndexTextFile: #admin: did NOT find $authorGpgFingerprint');
										}

										DBAddVoteRecord('flush');

										DBAddPageTouch('stats', 0);

										if (!$titleCandidate) {
											$titleCandidate = '[#' . $hashTag . ']';
										}
									} # if ($authorKey && IsAdmin)
									else {
										WriteLog('IndexTextFile: Request to admin file was not found to be valid');
									}
								} # foreach my $itemParent (@itemParents)
							} # has parents
						} # #admin #approve
						else { # non-permissioned hashtags
							WriteLog('IndexTextFile: non-permissioned hashtag');
							if ($tokenFound{'param'} =~ /^[0-9a-zA-Z_]+$/) { #todo actual hashtag format
								WriteLog('IndexTextFile: hashtag sanity check passed');
								my $hashTag = $tokenFound{'param'};
								if (scalar(@itemParents)) { # item has parents to apply tag to
									WriteLog('IndexTextFile: parents found, applying hashtag to them');

									foreach my $itemParentHash (@itemParents) { # apply to all parents
										WriteLog('IndexTextFile: applying hashtag, $itemParentHash = ' . $itemParentHash);
										if ($authorKey) {
											WriteLog('IndexTextFile: $authorKey = ' . $authorKey);
											# include author's key if message is signed
											DBAddVoteRecord($itemParentHash, 0, $hashTag, $authorKey, $fileHash);
										}
										else {
											WriteLog('IndexTextFile: $authorKey was FALSE');
											DBAddVoteRecord($itemParentHash, 0, $hashTag, '', $fileHash);
										}
										DBAddPageTouch('item', $itemParentHash);
										push @hashTagsAppliedToParent, $hashTag;
									} # @itemParents
								} # scalar(@itemParents)
								else {
									# no parents, self-apply
									if ($authorKey) {
										WriteLog('IndexTextFile: $authorKey = ' . $authorKey);
										# include author's key if message is signed
										DBAddVoteRecord($fileHash, 0, $hashTag, $authorKey, $fileHash);
									}
									else {
										WriteLog('IndexTextFile: $authorKey was FALSE');
										DBAddVoteRecord($fileHash, 0, $hashTag, '', $fileHash);
									}
								}
							} # valid hashtag
						} # non-permissioned hashtags

						$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
					} #hashtag
				} # if ($tokenFound{'token'} && $tokenFound{'param'}) {
			} # foreach @tokensFound

			if (scalar(@hashTagsAppliedToParent)) {
				if (!$titleCandidate) {
					# there's no title already
					 
					my $titleCandidateComma = '';
					foreach my $hashTagApplied (@hashTagsAppliedToParent) {
						$titleCandidate .= ' #' . $hashTagApplied;
					}
					$titleCandidate = trim($titleCandidate);
					if (length($titleCandidate) > 25) {
						$titleCandidate = substr($titleCandidate, 0, 25) . ' [...]';
					}
					if (scalar(@itemParents) > 1) {
						$titleCandidate .= ' applied to ' . scalar(@itemParents) . ' items';
					}
				}
			} # hash tags applied to parent items
		} # not #example

		$detokenedMessage = trim($detokenedMessage);
		if (trim($detokenedMessage) eq '-- ') {
			WriteLog('IndexTextFile: warning: bandaid encountered: dashdashspace');
			#todo #bandaid
			# this should be handled by the signature_divider token
			$detokenedMessage = '';
		}

		WriteLog('IndexTextFile: $fileHash = ' . $fileHash . '; length($detokenedMessage) = ' . length($detokenedMessage) . '; $detokenedMessage = "' . $detokenedMessage . '"');
		
#		if ($fileHash eq 'ef5f020ffae013876493cf25e323a2c67a3f09db') {
#			die($detokenedMessage);
#		}

		if ($detokenedMessage eq '') {
			# add #notext label/tag
			WriteLog('IndexTextFile: no $detokenedMessage, setting #notext; $fileHash = ' . $fileHash);
			DBAddVoteRecord($fileHash, 0, 'notext');
			#DBAddItemAttribute($fileHash, 'all_tokens_no_text', 1);

			if ($titleCandidate) {
				#no message, only tokens. try to get a title from the tokens, which we stashed earlier
				DBAddItemAttribute($fileHash, 'title', $titleCandidate);
			}
		}
		else { # has $detokenedMessage
			WriteLog('IndexTextFile: has $detokenedMessage $fileHash = ' . $fileHash);
			{ #title:
				my $firstEol = index($detokenedMessage, "\n");
				my $titleLength = GetConfig('title_length'); #default = 255
				if (!$titleLength) {
					$titleLength = 255;
					WriteLog('#todo: warning: $titleLength was false');
				}
				if ($firstEol == -1) {
					if (length($detokenedMessage) > 1) {
						$firstEol = length($detokenedMessage);
					}
				}
				if ($firstEol > $titleLength) {
					$firstEol = $titleLength;
				}
				if ($firstEol > 0) {
					my $title = '';
					if ($firstEol <= $titleLength) {
						$title = substr($detokenedMessage, 0, $firstEol);
					} else {
						$title = substr($detokenedMessage, 0, $titleLength) . '...';
					}
					DBAddItemAttribute($fileHash, 'title', $title, 0);
					DBAddVoteRecord($fileHash, 0, 'hastitle');
				}
			}

			DBAddVoteRecord($fileHash, 0, 'hastext');
			DBAddPageTouch('tag', 'hastext');

			my $normalizedHash = sha1_hex(trim($detokenedMessage));
			#v1

			{#v2
				my $hash = sha1_hex('');
				#draft better normalized hash
				my @lines = split("\n", $detokenedMessage);
				my @lines2;
				for my $line (@lines) {
					$line = trim($line);
					if ($line ne '') {
						push @lines2, lc($line);
					}
				}
				my @lines3 = uniq(sort(@lines2));
				for my $line (@lines3) {
					$hash = sha1_hex($hash . $line);
				}
				$normalizedHash = $hash;
			}

			DBAddItemAttribute($fileHash, 'normalized_hash', $normalizedHash, 0);

			#todo reparent item if another with the same normhash already exists
		} # has a $detokenedMessage

		if ($message) {
			# cache the processed message text
			my $messageCacheName = GetMessageCacheName($fileHash);
			WriteLog('IndexTextFile: Calling PutFile(), $fileHash = ' . $fileHash . '; $messageCacheName = ' . $messageCacheName);
			PutFile($messageCacheName, $message);
		} else {
			WriteLog('IndexTextFile: I was going to save $messageCacheName, but $message is blank! $file = ' . $file);
			WriteLog('IndexTextFile: I was going to save $messageCacheName, but $message is blank! $fileHash = ' . $fileHash);
			return '';
		}
	} # .txt

	return $fileHash;
} # IndexTextFile()

sub uniq { # @array ; return array without duplicate elements
# copied from somewhere like perlmonks
    my %seen;
    grep !$seen{$_}++, @_;
}

sub AddToChainLog { # $fileHash ; add line to log/chain.log
	# line format is:
	# file_hash|timestamp|checksum
	# file_hash = hash of file, a-f0-9 40
	# timestamp = epoch time in seconds, no decimal
	# checksum  = hash of new line with previous line
	#
	# if success, returns timestamp of item (epoch seconds)

	my $fileHash = shift;

	if (!$fileHash) {
		WriteLog('AddToChainLog: warning: sanity check failed');
		return '';
	}

	chomp $fileHash;

	if (!IsItem($fileHash)) {
		WriteLog('AddToChainLog: warning: sanity check failed');
		return '';
	}

	my $HTMLDIR = GetDir('html');
	my $logFilePath = "$HTMLDIR/chain.log"; #public

	$fileHash = IsItem($fileHash);

	{
		#look for existin entry, exit if found
		my $findExistingCommand = "grep ^$fileHash $logFilePath";
		my $findExistingResult = `$findExistingCommand`;

		WriteLog("AddToChainLog: $findExistingCommand returned $findExistingResult");
		if ($findExistingResult) { #todo remove fork
			# hash already exists in chain, return
			#todo return timestamp
			my ($exHash, $exTime, $exChecksum) = split('|', $findExistingResult);

			if ($exTime) {
				return $exTime;
			} else {
				return 0;
			}
		}
	}

	# get components of new line: hash, timestamp, and previous line
	my $newAddedTime = GetTime();
	my $logLine = $fileHash . '|' . $newAddedTime;
	my $lastLineAddedLog = `tail -n 1 $logFilePath`; #note the backticks
	if (!$lastLineAddedLog) {
		$lastLineAddedLog = '';
	}
	chomp $lastLineAddedLog;
	my $lastAndNewTogether = $lastLineAddedLog . '|' . $logLine;
	my $checksum = md5_hex($lastAndNewTogether);
	my $newLineAddedLog = $logLine . '|' . $checksum;

	WriteLog('AddToChainLog: $lastLineAddedLog = ' . $lastLineAddedLog);
	WriteLog('AddToChainLog: $lastAndNewTogether = ' . $lastAndNewTogether);
	WriteLog('AddToChainLog: md5(' . $lastAndNewTogether . ') = $checksum  = ' . $checksum);
	WriteLog('AddToChainLog: $newLineAddedLog = ' . $newLineAddedLog);

	if (!$lastLineAddedLog || ($newLineAddedLog ne $lastLineAddedLog)) {
		# write new line to file
		AppendFile($logFilePath, $newLineAddedLog);

		# figure out how many existing entries for chain sequence value
		my $chainSequenceNumber = (`wc -l html/chain.log | cut -d " " -f 1`) - 1;
		if ($chainSequenceNumber < 0) {
			WriteLog('AddToChainLog: warning: $chainSequenceNumber < 0');
			$chainSequenceNumber = 0;
		}

		# add to index database
		DBAddItemAttribute($fileHash, 'chain_timestamp', $newAddedTime);
		DBAddItemAttribute($fileHash, 'chain_sequence', $chainSequenceNumber);
	}

	return $newAddedTime;
} # AddToChainLog()

sub IndexImageFile { # $file ; indexes one image file into database
	# Reads a given $file, gets its attributes, puts it into the index database
	# If ($file eq 'flush), flushes any queued queries
	# Also sets appropriate task entries

	my $file = shift;
	chomp($file);

	if ($file =~ m/^([0-9a-zA-Z\/._\-])$/) {
		$file = $1;
	} else {
		WriteLog(' warning: sanity check failed on $file');
		return 0;
	}

	WriteLog("IndexImageFile($file)");

	if ($file eq 'flush') {
		WriteLog("IndexImageFile(flush)");
		DBAddItemAttribute('flush');
		DBAddItem('flush');
		DBAddVoteRecord('flush');
		DBAddPageTouch('flush');

		return 1;
	}

	#my @tagFromFile;
	#my @tagsFromFile;
	my @tagFromPath;
	if (GetConfig('admin/expo_site_mode')) {
		if ($file =~ /speaker/) {
			push @tagFromPath, 'speaker';
		}
		if ($file =~ /academic/) {
			push @tagFromPath, 'academic';
		}
		if ($file =~ /sponsor/) {
			push @tagFromPath, 'sponsor';
			if ($file =~ /gold/) {
				push @tagFromPath, 'gold';
			}
			if ($file =~ /silver/) {
				push @tagFromPath, 'silver';
			}
		}
		if ($file =~ /committee/) {
			push @tagFromPath, 'committee';
		}
		if ($file =~ /media/) {
			push @tagFromPath, 'media';
		}
		if ($file =~ /agenda/) {
			push @tagFromPath, 'agenda';
		}
	}

	my $addedTime;          # time added, epoch format
	my $fileHash;            # git's hash of file blob, used as identifier

	if (IsImageFile($file)) {
		my $fileHash = GetFileHash($file);

		if (GetCache('indexed/'.$fileHash)) {
			WriteLog('IndexImageFile: skipping because of flag: indexed/'.$fileHash);
			return $fileHash;
		}

		WriteLog('IndexImageFile: $fileHash = ' . ($fileHash ? $fileHash : '--'));

		$addedTime = DBGetAddedTime($fileHash);
		# get the file's added time.

		# debug output
		WriteLog('IndexImageFile: $file = ' . ($file?$file:'false'));
		WriteLog('IndexImageFile: $fileHash = ' . ($fileHash?$fileHash:'false'));
		WriteLog('IndexImageFile: $addedTime = ' . ($addedTime?$addedTime:'false'));

		# if the file is present in deleted.log, get rid of it and its page, return
		if (IsFileDeleted($file, $fileHash)) {
			# write to log
			WriteLog('IndexImageFile: IsFileDeleted() returned true, returning');
			return 0;
		}

		if (!$addedTime) {
			WriteLog('IndexImageFile: file missing $addedTime');
			if (GetConfig('admin/logging/write_chain_log')) {
				$addedTime = AddToChainLog($fileHash);
			} else {
				$addedTime = GetTime();
			}
			if (!$addedTime) {
				# sanity check
				WriteLog('IndexImageFile: warning: sanity check failed for $addedTime');
				$addedTime = GetTime();
			}
		}

		my $itemName = TrimPath($file);

		{  #thumbnails

			# # make 1024x1024 thumbnail
			# if (!-e "$HTMLDIR/thumb/thumb_1024_$fileHash.gif") {
			# 	my $convertCommand = "convert \"$file\" -thumbnail 1024x1024 -strip $HTMLDIR/thumb/thumb_1024_$fileHash.gif";
			# 	WriteLog('IndexImageFile: ' . $convertCommand);
			#
			# 	my $convertCommandResult = `$convertCommand`;
			# 	WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
			# }

			my $fileShellEscaped = EscapeShellChars($file); #todo this is still a hack, should rename file if it has shell chars?

			# make 800x800 thumbnail
			my $HTMLDIR = GetDir('html');

			if (!-e "$HTMLDIR/thumb/thumb_800_$fileHash.gif") {
				my $convertCommand = "convert \"$fileShellEscaped\" -thumbnail 800x800 -strip $HTMLDIR/thumb/thumb_800_$fileHash.gif";
				WriteLog('IndexImageFile: ' . $convertCommand);

				my $convertCommandResult = `$convertCommand`;
				WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
			}
#			if (!-e "$HTMLDIR/thumb/squared_800_$fileHash.gif") {
#				my $convertCommand = "convert \"$fileShellEscaped\" -crop 800x800 -strip $HTMLDIR/thumb/squared_800_$fileHash.gif";
#				WriteLog('IndexImageFile: ' . $convertCommand);
#
#				my $convertCommandResult = `$convertCommand`;
#				WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
#			}
			if (!-e "$HTMLDIR/thumb/thumb_400_$fileHash.gif") {
				my $convertCommand = "convert \"$fileShellEscaped\" -thumbnail 400x400 -strip $HTMLDIR/thumb/thumb_400_$fileHash.gif";
				WriteLog('IndexImageFile: ' . $convertCommand);

				my $convertCommandResult = `$convertCommand`;
				WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
			}
#			if (!-e "$HTMLDIR/thumb/squared_400_$fileHash.gif") {
#				my $convertCommand = "convert \"$fileShellEscaped\" -crop 400x400 -strip $HTMLDIR/thumb/squared_400_$fileHash.gif";
#				WriteLog('IndexImageFile: ' . $convertCommand);
#
#				my $convertCommandResult = `$convertCommand`;
#				WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
#			}
			if (!-e "$HTMLDIR/thumb/thumb_42_$fileHash.gif") {
				my $convertCommand = "convert \"$fileShellEscaped\" -thumbnail 42x42 -strip $HTMLDIR/thumb/thumb_42_$fileHash.gif";
				WriteLog('IndexImageFile: ' . $convertCommand);

				my $convertCommandResult = `$convertCommand`;
				WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
			}
#			if (!-e "$HTMLDIR/thumb/squared_42_$fileHash.gif") {
#				my $convertCommand = "convert \"$fileShellEscaped\" -crop 42x42 -strip $HTMLDIR/thumb/squared_42_$fileHash.gif";
#				WriteLog('IndexImageFile: ' . $convertCommand);
#
#				my $convertCommandResult = `$convertCommand`;
#				WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
#			}

			# # make 48x48 thumbnail
			# if (!-e "$HTMLDIR/thumb/thumb_48_$fileHash.gif") {
			# 	my $convertCommand = "convert \"$file\" -thumbnail 48x48 -strip $HTMLDIR/thumb/thumb_48_$fileHash.gif";
			# 	WriteLog('IndexImageFile: ' . $convertCommand);
			#
			# 	my $convertCommandResult = `$convertCommand`;
			# 	WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
			# }
		}

		DBAddItem($file, $itemName, '', $fileHash, 'image', 0);
		DBAddItem('flush');
		#DBAddItemAttribute($fileHash, 'title', $itemName, $addedTime);
		#DBAddItemAttribute($fileHash, 'title', $itemName, time()); #todo time should come from actual file time #todo re-add this
		DBAddVoteRecord($fileHash, $addedTime, 'image'); # add image tag

		if (@tagFromPath) {
			foreach my $tag (@tagFromPath) {
				DBAddVoteRecord($fileHash, $addedTime, $tag);
			}
		}

		DBAddPageTouch('read');
		DBAddPageTouch('tag', 'image');
		DBAddPageTouch('item', $fileHash);
		DBAddPageTouch('stats');
		DBAddPageTouch('rss');
		DBAddPageTouch('index');
		DBAddPageTouch('flush');

		return $fileHash;
	}
} # IndexImageFile()

sub WriteIndexedConfig { # writes config indexed in database into config/
	WriteLog('WriteIndexedConfig() begin');

	my @indexedConfig = DBGetLatestConfig();

	WriteLog('WriteIndexedConfig: scalar(@indexedConfig) = ' . scalar(@indexedConfig));

	foreach my $configLine(@indexedConfig) {
		my $configKey = $configLine->{'key'};
		my $configValue = $configLine->{'value'};

		chomp $configValue;
		$configValue = trim($configValue);

		if (IsSha1($configValue)) {
			WriteLog('WriteIndexedConfig: Looking up hash: ' . $configValue);

			if (-e 'cache/' . GetMyCacheVersion() . "/message/$configValue") { #todo make it cleaner
				WriteLog('WriteIndexedConfig: success: lookup of $configValue = ' . $configValue);
				$configValue = GetCache("message/$configValue");#todo should this be GetItemMessage?
			} else {
				WriteLog('WriteIndexedConfig: warning: no result for lookup of $configValue = ' . $configValue);
			}
		}

		if ($configLine->{'reset_flag'}) {
			ResetConfig($configKey);
		} else {
			PutConfig($configKey, $configValue);
		}
	}

	WriteLog('WriteIndexedConfig: finished, calling GetConfig(unmemo)');

	GetConfig('unmemo');

	return '';
}

sub MakeIndex { # indexes all available text files, and outputs any config found
	WriteLog( "MakeIndex()...\n");

	my $TXTDIR = GetDir('txt');
	WriteLog('MakeIndex: $TXTDIR = ' . $TXTDIR);

	#my @filesToInclude = split("\n", `grep txt\$ ~/index/home.txt`); #homedir #~
	#my @filesToInclude = split("\n", `find $TXTDIR -name \\\*.txt -o -name \\\*.html`); #includes html files #indevelopment
	my @filesToInclude = split("\n", `find $TXTDIR -name \\\*.txt`);

	my $filesCount = scalar(@filesToInclude);
	my $currentFile = 0;
	foreach my $file (@filesToInclude) {
		#$file =~ s/^./../;

		$currentFile++;
		my $percent = ($currentFile / $filesCount) * 100;
		WriteMessage("*** MakeIndex: $currentFile/$filesCount ($percent %) $file");
		IndexFile($file); # aborts if cache/.../indexed/filehash exists
	}
	IndexFile('flush');

	WriteIndexedConfig(); # MakeIndex

	if (GetConfig('admin/image/enable')) {
		my $HTMLDIR = GetDir('html');

		my @imageFiles = split("\n", `find $HTMLDIR/image`);
		my $imageFilesCount = scalar(@imageFiles);
		my $currentImageFile = 0;
		WriteLog('MakeIndex: $imageFilesCount = ' . $imageFilesCount);

		foreach my $imageFile (@imageFiles) {
			$currentImageFile++;
			my $percentImageFiles = $currentImageFile / $imageFilesCount * 100;
			WriteMessage("*** MakeIndex: $currentImageFile/$imageFilesCount ($percentImageFiles %) $imageFile");
			IndexImageFile($imageFile);
		}

		IndexImageFile('flush');
	} # admin/image/enable
} # MakeIndex()

sub DeindexMissingFiles { # remove from index data for files which have been removed
# takes no parameters
#
	# get all items in database
	my %queryParams = ();
	my @items = DBGetItemList(\%queryParams);
	my $itemsDeletedCount = 0;

	WriteLog('DeindexMissingFiles scalar(@items) is ' . scalar(@items));
	WriteMessage("Checking for deleted items... ");

	#print Dumper(@items);

	if (@items) {
		# for each of the items, check if the file still exists
		foreach my $item (@items) {

			if ($item->{'file_path'}) {
				if (!-e $item->{'file_path'}) {
					# if file does not exist, remove its references
					WriteLog('DeindexMissingFiles: Found a missing text file, removing references. ' . $item->{'file_path'});
					DBDeleteItemReferences($item->{'file_hash'});
					$itemsDeletedCount++;
				}
			}
		}

		if ($itemsDeletedCount) {
			# if any files were de-indexed, report this, and pause for 3 seconds to inform operator
			WriteMessage('DeindexMissingFiles: deleted items found and removed: ' . $itemsDeletedCount);
			WriteIndexedConfig(); # DeindexMissingFiles()
			WriteMessage(`sleep 2`);
		}
	}

	return $itemsDeletedCount;
} # DeindexMissingFiles()

sub IndexFile { # $file ; calls IndexTextFile() or IndexImageFile() based on extension
	my $file = shift;

	if ($file eq 'flush') {
		WriteLog('IndexFile: flush was requested');
		IndexImageFile('flush');
		IndexTextFile('flush');
		return '';
	}

	if (!$file) {
		WriteLog('IndexFile: warning: $file is false');
		return '';
	}

	chomp $file;

	WriteLog('IndexFile: $file = ' . $file);
	if (!-e $file) {
		WriteLog('IndexFile: warning: -e $file is false (file does not exist)');
		return '';
	}
	if (-d $file) {
		WriteLog('IndexFile: warning: -d $file was true (file is a directory)');
		return '';
	}

	my $fileHash = GetFileHash($file);
	if (GetCache("indexed/$fileHash")) {
		WriteLog('IndexFile: aleady indexed, returning. $fileHash = ' . $fileHash);
		return $fileHash;
	}

	my $indexSuccess = 0;

	my $ext = lc(GetFileExtension($file));

	if ($ext eq 'txt') {
		WriteLog('IndexFile: calling IndexTextFile()');
		$indexSuccess = IndexTextFile($file);

		if (!$indexSuccess) {
			WriteLog('IndexFile: warning: $indexSuccess was FALSE');
			$indexSuccess = 0;
		}
	}

	if (
		$ext eq 'png' ||
		$ext eq 'gif' ||
		$ext eq 'jpg' ||
		$ext eq 'jpeg' ||
		$ext eq 'bmp' ||
		$ext eq 'svg' ||
		$ext eq 'webp' ||
		$ext eq 'jfif' ||
		$ext eq 'tiff' ||
		$ext eq 'tff'
	) {
		WriteLog('IndexFile: calling IndexImageFile()');
		$indexSuccess = IndexImageFile($file);
	}

	if ($indexSuccess) {
		WriteLog('IndexFile: $indexSuccess = ' . $indexSuccess);
	} else {
		WriteLog('IndexFile: warning: $indexSuccess FALSE');
	}

	if ($indexSuccess) {
		if (-e $file) {
	 		if (GetConfig('admin/index/stat_file')) {
				my @fileStat = stat($file);
				my $fileSize =    $fileStat[7];
				my $fileModTime = $fileStat[9];
				WriteLog('IndexFile: $fileModTime = ' . $fileModTime . '; $fileSize = ' . $fileSize);
				if ($fileModTime) {
					if (IsItem($indexSuccess)) {
						DBAddItemAttribute($indexSuccess, 'file_m_timestamp', $fileModTime);
						DBAddItemAttribute($indexSuccess, 'file_size', $fileSize);
					} else {
						WriteLog('IndexFile: warning: IsItem($indexSuccess) was FALSE');
					}
				}
			}
	 		if (GetConfig('admin/index/add_git_hash_file')) {
	 			#todo sanity check before running shell command #security
	 			if ($file =~ m/^([0-9a-z.\/_]+)/) {
	 				$file = $1;

					my $gitHash = `git hash-object $file`;
					if ($gitHash) {
						DBAddItemAttribute($indexSuccess, 'git_hash_object', $gitHash);
					} else {
						WriteLog('IndexFile: warning: $gitHash returned false');
					}
				} else {
					WriteLog('IndexFile: warning: add_git_hash_file, $file failed sanity check');
				}
	 		}
		}
	}

	PutCache('indexed/' . $indexSuccess, $file);

	return $indexSuccess;
} # IndexFile()

while (my $arg1 = shift @argsFound) {
	WriteLog('index.pl: $arg1 = ' . $arg1);
	if ($arg1) {
		if ($arg1 eq '--clear') {
			print "index.pl: --clear\n";
			print `rm -vrf cache/b/indexed/*`;
		}
		if ($arg1 eq '--all') {
			print "index.pl: --all\n";
			MakeIndex();
			print "=========================\n";
			print "index.pl: --all finished!\n";
			print "=========================\n";
		}
		if ($arg1 eq '--chain') {
			# html/chain.log
			print "index.pl: --chain\n";
			MakeChainIndex();
		}
		if (-e $arg1) {
			IndexFile($arg1);
			IndexFile('flush');
		}
	}
}

#MakeTagIndex();
1;
