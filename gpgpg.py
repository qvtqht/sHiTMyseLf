#!/usr/bin/python

import sys
import re
import os
import subprocess
from utils import WriteLog, GetFileHash, IsItem, GetDir, GetFile, GetFileMessageCachePath, GetCache, DBAddItemAttribute, \
                  DBAddVoteRecord, DBAddItemAttribute, ExpireAvatarCache, DBAddKeyAlias, GetTemplate, GetTime, PutFileMessage

# gpgpg.pl (gnu pretty good privacy guard)

# INPUT:
# path(s) to one or more text file(s)
#
# PROCESS:
# look for gpg-looking strings #gpg_strings
# prepare arguments for calling gpg: #gpg_prepare
#   if signed message: perform signature verification #gpg_signed
#   if public key: adds to keychain #gpg_pubkey
#   if encrypted message: displays message #gpg_encrypted
# call gpg #gpg_call
#   STDOUT and STDERR is piped to cache #gpg_command_pipe
# naive regex string-matching is used to pull out values #gpg_naive_regex
#   anything good is written to database
#   #gpg_naive_regex_pubkey #gpg_naive_regex_signed #gpg_naive_regex_encrypted


# require('./utils.pl');


def GpgParse(filePath): # { # $filePath ; parses file and stores gpg response in cache
    # PgpParse {
    # $filePath = path to file containing the text
    #

    if not filePath or not os.path.isfile(filePath) or os.path.isdir(filePath):
        WriteLog('GpgParse: warning: $filePath missing, non-existent, or a directory');
        return ''

    match = re.findall('([a-zA-Z0-9\.\/]+)', filePath)
    if match:
        filePath = match[0]
    else:
        WriteLog('GpgParse: warning: sanity check failed on $filePath, returning')
        return ''


    WriteLog("GpgParse({filePath})")
    fileHash = GetFileHash(filePath)

    if not fileHash or not IsItem(fileHash):
        WriteLog('GpgParse: warning: sanity check failed on $fileHash$ returned by GetFileHash($filePath$), returning')
        return ''


    CACHEPATH = GetDir('cache');
    cachePathStderr = CACHEPATH + "/gpg_stderr"
    match = re.search('^([a-zA-Z0-9_\/.]+)$', cachePathStderr)
    if match:
        cachePathStderr = match[0]
        WriteLog('GpgParse: $cachePathStderr sanity check passed: ' + cachePathStderr)
    else:
        WriteLog('GpgParse: warning: sanity check failed, $cachePathStderr = ' + cachePathStderr)
        return ''

    pubKeyFlag = 0
    encryptedFlag = 0
    signedFlag = 0

    if not os.path.isfile(cachePathStderr + os.sep + fileHash + '.txt'): # no gpg stderr output saved
        # we've not yet run gpg on this file
        WriteLog('GpgParse: found stderr output: ' + cachePathStderr + os.sep + fileHash + '.txt')
        fileContents = GetFile(filePath)

        #gpg_strings
        gpgPubkey = '-----BEGIN PGP PUBLIC KEY BLOCK-----'
        gpgSigned = '-----BEGIN PGP SIGNED MESSAGE-----'
        gpgEncrypted = '-----BEGIN PGP MESSAGE-----'

        # gpg_prepare
        # this is the base gpg command
        # these flags help prevent stalling due to password prompts
        gpgCommand = 'gpg --pinentry-mode=loopback --batch '

        # basic message classification covering only three cases, exclusively
        if fileContents.index(gpgPubkey) > -1:
            #gpg_pubkey
            WriteLog('GpgParse: found $gpgPubkey')
            gpgCommand += '--import --ignore-time-conflict --ignore-valid-from '
            pubKeyFlag = 1
        elif fileContents.index(gpgSigned) > -1:
            #gpg_signed
            WriteLog('GpgParse: found $gpgSigned')
            gpgCommand += '--verify -o - '
            signedFlag = 1
        elif fileContents.index(gpgEncrypted) > -1:
            #gpg_encrypted
            WriteLog('GpgParse: found $gpgEncrypted')
            gpgCommand += '-o - --decrypt '
            encryptedFlag = 1
        else:
            WriteLog('GpgParse: did not find any relevant strings, returning')
            return ''
        
        match = re.search('^([0-9a-f]+)$', fileHash)
        if match:
            #todo not sure if this is needed, since $fileHash is checked above
            fileHash = match[0];
        else:
            WriteLog('GpgParse: sanity check failed, $fileHash = ' + fileHash)
            return ''
        

        #gpg_command_pipe
        messageCachePath = GetFileMessageCachePath(filePath) + '_gpg'
        gpgCommand += filePath # file we're parsing
        gpgCommand += ">" + messageCachePath  # capture stdout
        gpgCommand += "2>" + cachePathStderr + os.sep + fileHash + ".txt " # capture stdeerr
        WriteLog('GpgParse: ' + fileHash + '; $gpgCommand = ' + gpgCommand)
        os.system(gpgCommand)
    
    gpgStderrOutput = GetCache('gpg_stderr' + os.sep + fileHash + '.txt')
    if gpgStderrOutput is None:
        WriteLog('GpgParse: warning: GetCache(gpg_stderr/$fileHash.txt) returned undefined!')
        gpgStderrOutput = ''
    

    if gpgStderrOutput:
        WriteLog('GpgParse: ' + fileHash + '; $gpgStderrOutput = ' + gpgStderrOutput)
        WriteLog('GpgParse: ' + fileHash + '; $pubKeyFlag = ' + pubKeyFlag)

        if pubKeyFlag:
            gpgKeyPub = ''

            match = re.search('([0-9A-F]{16})', gpgStderrOutput)
            if match: # username allowed characters chars filter is here
                gpgKeyPub = match[0];
                DBAddItemAttribute(fileHash, 'gpg_id', gpgKeyPub)

                match = re.search('"([ a-zA-Z0-9<>&\@.()_]+)"', gpgStderrOutput)
                if match:
                    # we found something which looks like a name
                    aliasReturned = match[0]
                    aliasReturned = re.sub('\<(.+\@.+?)\>', '', aliasReturned) # if has something which looks like an email, remove it

                    if gpgKeyPub and aliasReturned:
                        # gpg_naive_regex_pubkey
                        message = GetTemplate('message/user_reg.template')

                        message = re.sub('\$name', aliasReturned, message)
                        message = re.sub('\'$fingerprint', gpgKeyPub, message)

                        DBAddVoteRecord(fileHash, GetTime(), 'pubkey', gpgKeyPub, fileHash)

                        # sub DBAddVoteRecord { # $fileHash, $ballotTime, $voteValue, $signedBy, $ballotHash ; Adds a new vote (tag) record to an item based on vote/ token

                        DBAddItemAttribute(fileHash, 'gpg_alias', aliasReturned)
                        #
                        # DBAddKeyAlias($authorKey, $tokenFound{'param'}, $fileHash);
                        # DBAddKeyAlias('flush');

                        # gpg author alias shim
                        DBAddKeyAlias(gpgKeyPub, aliasReturned, fileHash)
                        DBAddKeyAlias('flush')

                        ExpireAvatarCache(gpgKeyPub) # does fresh lookup, no cache

                        PutFileMessage(fileHash, message)
                    else:
                        pass
                else:
                    WriteLog('GpgParse: warning: alias not found in pubkey mode')
                    #DBAddItemAttribute($fileHash, 'gpg_alias', '???');
                    #$message =~ s/\$name/???/g;

                return gpgKeyPub



        # } $pubKeyFlag
        elif signedFlag:
            gpgKeySigned = ''
            #gpg_naive_regex_signed
            match = re.search('([0-9A-F]{16})', gpgStderrOutput)
            if match:
                gpgKeySigned = match[0];
                DBAddItemAttribute(fileHash, 'gpg_id', gpgKeySigned)

            match = re.findall('Signature made (.+)', gpgStderrOutput)
            if match:
                # gpgDateEpoch = #todo convert to epoch time
                WriteLog('GpgParse: ' + fileHash + '; found signature made token from gpg')
                signTimestamp = match[0]
                signTimestamp = signTimestamp.strip()
                p = subprocess.Popen('date --date="' + signTimestamp + '" +%s', shell=True, stdout=subprocess.PIPE)
                signTimestampEpoch, _ = p.communicate()
                signTimestampEpoch = signTimestampEpoch.strip()

                WriteLog('GpgParse: $signTimestamp = ' + signTimestamp + '; $signTimestampEpoch = ' + signTimestampEpoch)

                DBAddItemAttribute(fileHash, 'gpg_timestamp', signTimestampEpoch)

            return gpgKeySigned

        elif encryptedFlag:
            #gpg_naive_regex_encrypted
            DBAddItemAttribute(fileHash, 'gpg_encrypted', 1)
            PutFileMessage(fileHash, '(Encrypted message)')
            WriteLog('GpgParse: $encryptedFlag was true, setting message accordingly')
            return 1
        else:
            # not a pubkey, just take whatever pgp output for us
            WriteLog('GpgParse: fallthrough, nothing gpg-worthy found...')
            return ''

    # } $gpgStderrOutput
    else:
        # for some reason gpg didn't output anything, so just put the original message
        # $returnValues{'message'} = GetFile("$cachePathMessage/$fileHash.txt");
        #WriteLog('GpgParse: warning: ' + fileHash + '; $gpgStderrOutput was false!');
        return ''

    return ''
# } GpgParse()

# while (arg1 = shift @argsFound:
#     WriteLog('index.pl: $arg1 = ' + arg1);
#     if $arg1:
#         if -e $arg1:
#             print GpgParse($arg1);
#             print "\n";
#         }
#     }
# }

for arg in sys.argv[1:]:
    WriteLog('index.pl: $arg1 = ' + arg)
    if arg and os.path.isfile(arg):
        print(GpgParse(arg))
        print()


exit(1)
