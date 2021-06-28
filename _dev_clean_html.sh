#!/bin/sh

# this script will clean html to make room for new html

# mkdir trash
# mkdir trash.`date +%s`
# #todo first move to trash, then rm. reason: rm takes longer than mv
#echo this script is currently disabled because we are now parsing html files as data, and there is test data i want to keep
#exit;
echo "touch -d @0 html/*.html html/*/*.html html/*/*/*.html"
touch -d @0 html/*.html html/*/*.html html/*/*/*.html

echo "touch -d @0 html/*.js html/*/*.js html/*/*/*.js"
touch -d @0 html/*.js html/*/*.js html/*/*/*.js

echo find html -iname '*.html' -type f -exec rm {} \;
find html -iname '*.html' -type f -exec rm {} \;

#echo find html -iname '*.html' -type f -mtime +5 -exec rm {} \;
#find html -iname '*.html' -type f -mtime +5 -exec rm {} \;

#echo find html -mtime +5 -exec ls {} \;
#find html -mtime +5 -exec ls {} \;

echo "================="
echo "Cleanup complete!"
echo "================="
#echo "Rebuilding with ./generate_html_frontend.pl in 3...";
#sleep 2

#echo "2... "
#sleep 2

#echo "1... "
#sleep 2

#echo "Running ./generate_html_frontend.pl"
#./generate_html_frontend.pl
time ./pages.pl --php
time ./pages.pl -M welcome
