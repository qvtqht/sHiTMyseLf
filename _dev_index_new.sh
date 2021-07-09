#!/bin/sh

time find html/image -cmin -3 | xargs ./index.pl
time find html/txt -cmin -3 | grep \\.txt$ | xargs ./index.pl

