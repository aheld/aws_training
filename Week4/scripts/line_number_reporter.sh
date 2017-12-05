#!/bin/bash

echo "<html><body><h1>Line Numbers</h1><ul>" > line_numbers.html

for FILE in ../data/*
	do
		if [ -f $FILE  ]
		then
			echo "<li>"`wc -l $FILE`"</li>"
		fi
	done >> line_numbers.html

echo "</ul></body></html>" >> line_numbers.html
