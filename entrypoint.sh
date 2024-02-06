#!/bin/bash

# convert swiftlint's output into GitHub Actions Logging commands
# https://help.github.com/en/github/automating-your-workflow-with-github-actions/development-tools-for-github-actions#logging-commands

sh -c "git config --global --add safe.directory $PWD"

function stripPWD() {
    if ! ${WORKING_DIRECTORY+false};
    then
        cd - > /dev/null
    fi
    sed -E "s/$(pwd|sed 's/\//\\\//g')\///"
}

function convertToGitHubActionsLoggingCommands() {
    sed -E 's/^(.*):([0-9]+):([0-9]+): (warning|error|[^:]+): (.*)/::\4 file=\1,line=\2,col=\3::\5/'
}

function diffLines() {
	git diff --name-only --relative HEAD $(git merge-base FETCH_HEAD $DIFF_BASE) -- '*.swift' | while read file; do
		git diff -U0 HEAD $(git merge-base HEAD $DIFF_BASE) -- "$file" | sed -n '/^@@ -[0-9]*/{s/@@ -\([0-9]*\).*/\1/;p;}' | while read start_line; do
			git blame -L $start_line,+1 -- "$file" | sed -n "s|[^)]* ([^)]* \([0-9]*\)).*|$PWD/$file:\1|p"
		done
	done
}

if ! ${WORKING_DIRECTORY+false};
then
	cd ${WORKING_DIRECTORY}
fi

if ! ${DIFF_BASE+false};
then
	changedFiles=$(git --no-pager diff --name-only --relative HEAD $(git merge-base FETCH_HEAD $DIFF_BASE) -- '*.swift')

	if [ -z "$changedFiles" ]
	then
		echo "No Swift file changed"
		exit
	fi
fi

set -o pipefail && swiftlint lint "$@" -- $changedFiles | grep -Ff <(diffLines) | stripPWD | convertToGitHubActionsLoggingCommands
