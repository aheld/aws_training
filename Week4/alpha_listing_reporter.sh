#!/bin/bash

echo "<html><body><h1>Alphabetical Listing</h1><ul>" > alpha.html

ls -RAp ../data/ | grep -v / | grep -v -e ^$ | sort -f | awk '{ print "<li>"$0"</li>" }' >> alpha.html

echo "</ul></body></html>" >> alpha.html
