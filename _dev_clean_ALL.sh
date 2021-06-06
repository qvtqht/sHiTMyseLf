#!/bin/sh

# MYDATE=`date +%s`
# mkdir trash
# mkdir trash.$MYDATE

echo "rm -v cron.lock"
rm -v cron.lock

echo "rm -rf cache"
rm -rf cache

echo "rm -rf html/*.html html/*/*.html html/*/*/*.html"
rm -rf html/*.html html/*/*.html html/*/*/*.html

echo "rm -rf html/*.js html/*/*.js html/*/*/*.js"
rm -rf html/*.js html/*/*.js html/*/*/*.js

echo "rm -rf html/*.php html/*/*.php html/*/*/*.php"
rm -rf html/*.php html/*/*.php html/*/*/*.php

echo "rm -rf html/*.xml html/*/*.xml"
rm -rf html/*.xml html/*/*.xml

echo "rm -rf html/.htaccess"
rm -rf html/.htaccess

echo "rm -rf html/*.zip"
rm -rf html/*.zip

echo "rm -rf html/rss.xml html/rss.txt"
rm -rf html/rss.xml html/rss.txt

#echo "rm -rf config/template/*"
#rm -rf config/template/*

echo "rm -rf config/query/*"
rm -rf config/query/*

echo "rm -rf config/string/*"
rm -rf config/string/*

echo "rm -rf config/theme/*"
rm -rf config/theme/*

echo "rm -rf config/admin/my_version"
rm -rf config/admin/my_version

echo "find html -type d -empty -delete"
find html -type d -empty -delete

echo "touch html/post.html"
touch html/post.html

echo "rm -v log/log.log"
rm -v log/log.log

echo "mkdir -p html/txt"
mkdir -p html/txt

echo "================="
echo "Cleanup complete!"
echo "================="
echo "Rebuilding with ./build.pl in 3..."
sleep 2

echo "2... "
sleep 2

echo "1... "
sleep 2

echo "Running ./build.pl"
time perl -T ./build.pl

echo "==============="
echo "Build complete!"
echo "==============="



echo "Building system pages with ./pages.pl --system in 3..."
sleep 2

echo "2... "
sleep 2

echo "1... "
sleep 2

echo "Running ./pages.pl --system"
time perl -T ./pages.pl --system

echo "=================="
echo "System pages done!"
echo "=================="



echo "Verifying Chain with ./index.pl --chain in 3..."
sleep 2

echo "2... "
sleep 2

echo "1... "
sleep 2

echo "Running ./index.pl --chain"
time perl -T ./index.pl --chain

echo "============================"
echo "Chain verification complete!"
echo "============================"



echo "Reindexing all stored files with ./index.pl --all in 3..."
sleep 2

echo "2... "
sleep 2

echo "1... "
sleep 2

echo "Running ./index.pl --all"
time perl -T ./index.pl --all

echo "======================"
echo "Reindex of files done!"
echo "======================"



