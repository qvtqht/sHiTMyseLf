#!/bin/sh

time find html/image -cmin -100 | xargs ./index.pl
time find html/txt -cmin -100 | grep \\.txt$ | xargs ./index.pl

