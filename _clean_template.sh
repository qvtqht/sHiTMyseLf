#!/bin/bash

echo "rm -rfv config/template/*"
rm -rfv config/template/*

echo "rm -rfv config/theme/*"
rm -rfv config/theme/*

echo "================="
echo "Cleanup complete!"
echo "================="
echo "Removing existing frontend cache with ./_clean_html.sh in 3..."
sleep 1

echo "2... "
sleep 1

echo "1... "
sleep 1

echo "Running ./_clean_html.sh"
./_clean_html.sh