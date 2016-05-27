#!/bin/bash

# Functions that are to be used in the extract-from-pick-a-part script

# run_shell_check#{{{
# Run shellcheck to check for syntax errors in bash script. If any exist, in
# either script file, exit and direct the user to the log files.
function run_shell_check {
  shellcheck *.sh > shellcheck.log
  failed=0

  if [ -s shellcheck.log ]; then
    # File contains something, so execution failed
    echo "shellcheck failed. See shellcheck.log"
    return 0
  fi

  return 1
}

#}}}

