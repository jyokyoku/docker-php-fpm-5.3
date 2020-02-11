#!/usr/bin/env bash

set -e
set -u
set -o pipefail

MODULES="$( docker run --rm -t --entrypoint=php  jyokyoku/php:5.3.3-fpm -m \
	| grep -vE '(^\[)|(^\s*$)' \
	| sort -u
)"

echo "| Module       | Built-in  |"
echo "|--------------|-----------|"
echo "${MODULES}" | while read line; do
	line="$( echo "${line}" | sed 's/\r//g' | xargs )"
	printf "| %-12s | ✔         |\n" "${line}"
done
