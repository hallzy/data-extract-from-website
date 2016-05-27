#!/bin/bash

# Functions that are to be used in the extract-from-pick-a-part script
# ====================================================================

# check_for_program_dependencies#{{{
function check_for_program_dependencies {
  passed=1

  # Shellcheck
  command -v shellcheck >/dev/null 2>&1 || {
    echo "shellshock does not exist. Please install"
    passed=0
  }
  # mutt
  command -v mutt >/dev/null 2>&1 || {
    echo "mutt does not exist. Please install"
    passed=0
  }
  # wget
  command -v wget >/dev/null 2>&1 || {
    echo "wget does not exist. Please install"
    passed=0
  }
  # awk
  command -v awk >/dev/null 2>&1 || {
    echo "awk does not exist. Please install"
    passed=0
  }
  # curl
  command -v curl >/dev/null 2>&1 || {
    echo "curl does not exist. Please install"
    passed=0
  }
  # dos2unix
  command -v dos2unix >/dev/null 2>&1 || {
    echo "dos2unix does not exist. Please install"
    passed=0
  }
  # gimli
  command -v gimli >/dev/null 2>&1 || {
    echo "gimli does not exist. Please install"
    passed=0
  }


  return $passed
}

#}}}

# run_shell_check#{{{
# Run shellcheck to check for syntax errors in bash script. If any exist, in
# either script file, exit and direct the user to the log files.
function run_shell_check {
  shellcheck ./*.sh > shellcheck.log

  if [ -s shellcheck.log ]; then
    # File contains something, so execution failed
    echo "shellcheck failed. See shellcheck.log"
    return 0
  fi

  return 1
}

#}}}

