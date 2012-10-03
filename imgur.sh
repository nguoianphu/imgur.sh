#!/bin/bash

# imgur script by Bart Nagel <bart@tremby.net>
# improvements by Tino Sino <robottinosino@gmail.com>
# version 5
# I release this into the public domain. Do with it what you will.

# Required: curl
#
# Optional: xsel or xclip for automatically putting the URLs on the X selection 
# for easy pasting
#
# Instructions:
# Put it somewhere in your path and maybe rename it:
# 	mv ~/Downloads/imgurbash.sh ~/bin/imgur
# Make it executable:
# 	chmod +x ~/bin/imgur
# Optional, since Alan kindly provided an API key for this script: stick your 
# API key in the top:
# 	vim ~/bin/imgur
# Upload an image:
# 	imgur images/hilarious/manfallingover.jpg
# Upload multiple images:
# 	imgur images/delicious/cake.png images/exciting/bungeejump.jpg
# The URLs will be displayed (and the delete page's URLs will be displayed on 
# stderr). If you have xsel or xclip the URLs will also be put on the X 
# selection, which you can usually paste with a middle click.

# API Key provided by Alan@imgur.com
apikey="b3625162d3418ac51a9ee805b1840452"

# function to output usage instructions
function usage {
	echo "Usage: $(basename $0) <filename> [<filename> [...]]" >&2
	echo "Upload images to imgur and output their new URLs to stdout. Each one's" >&2
	echo "delete page is output to stderr between the view URLs." >&2
	echo "If xsel or xclip is available, the URLs are put on the X selection for" >&2
	echo "easy pasting." >&2
}

# check API key has been entered
if [ -z "$apikey" ]; then
	echo "You first need to edit the script and put your API key in the variable near the top." >&2
	exit 15
fi

# check arguments
if [ "$1" == "-h" -o "$1" == "--help" ]; then
	usage
	exit 0
elif [ $# -eq 0 ]; then
	echo "No file specified" >&2
	usage
	exit 16
fi

# check curl is available
type curl &>/dev/null || {
	echo "Couldn't find curl, which is required." >&2
	exit 17
}

clip=""
errors=false

# loop through arguments
while [ $# -gt 0 ]; do
	file="$1"
	shift

	# check file exists
	if [ ! -f "$file" ]; then
		echo "file '$file' doesn't exist, skipping" >&2
		errors=true
		continue
	fi

	# upload the image
	response=$(curl -vF "key=$apikey" -H "Expect: " -F "image=@$file" \
		http://imgur.com/api/upload.xml 2>/dev/null)
	# the "Expect: " header is to get around a problem when using this through 
	# the Squid proxy. Not sure if it's a Squid bug or what.
	if [ $? -ne 0 ]; then
		echo "Upload failed" >&2
		errors=true
		continue
	elif echo "$response" | grep -q "<error msg>"; then
		echo "Error message from imgur:" >&2
		msg="${response##*<error_msg>}"
		echo "${msg%%</error_msg>*}" >&2
		errors=true
		continue
	fi

	# parse the response and output our stuff
	url="${response##*<original_image>}"
	url="${url%%</original_image>*}"
	deleteurl="${response##*<delete_page>}"
	deleteurl="${deleteurl%%</delete_page>*}"
	echo $url
	echo "Delete page: $deleteurl" >&2

	# append the URL to a string so we can put them all on the clipboard later
	clip+="$url"
	if [ $# -gt 0 ]; then
		clip+=$'\n'
	fi
done

# put the URLs on the clipboard if we have xsel or xclip
if [ $DISPLAY ]; then
	if type xsel &>/dev/null; then
		echo -n "$clip" | xsel
	elif type xclip &>/dev/null; then
		echo -n "$clip" | xclip
	else
		echo "Haven't copied to the clipboard: no xsel or xclip" >&2
	fi
else
	echo "Haven't copied to the clipboard: no \$DISPLAY" >&2
fi

if $errors; then
	exit 1
fi
