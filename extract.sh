#!/bin/bash

source script-functions.sh

cd ~/Documents/git-repos/remote-github/data-extract-from-website
git pull

# if this function fails, we do not have the required dependencies, so quit.
check_for_program_dependencies
if (( $? == 0 )); then
  exit
fi

# Run shellcheck to check for syntax errors in bash script. If any exist, in
# either script file, exit and direct the user to the log files.
run_shell_check
if (( $? == 0 )); then
  exit
fi

# bare bones check that this script started:
DATE_VAR=$(date +%F)
TIME_VAR=$(date +%H:%M:%S)
echo "${DATE_VAR} ${TIME_VAR}" > script_exec_started

# If there are no arguments, or the only argument is --email with a string after
# it, then we can continue...
if [[ -z "$1" || ( "$1" == "--cars-only" ) ]]
then
  LOG_FILE_NAME=data-extract-from-website.log
  PATH_TO_LOG_FILE=./logs/$DATE_VAR/$TIME_VAR/$LOG_FILE_NAME

  mkdir -p logs
  mkdir -p logs/"$DATE_VAR"
  mkdir -p logs/"$DATE_VAR"/"$TIME_VAR"
  if [ "$1" == "--cars-only" ]
  then
    time ./extract-helper.sh --cars-only | tee "$PATH_TO_LOG_FILE"
  else
    time ./extract-helper.sh | tee "$PATH_TO_LOG_FILE"
  fi

  cp ./* logs/"$DATE_VAR"/"$TIME_VAR"

  cd logs/"$DATE_VAR"/"$TIME_VAR"
  # Remove these from the newly created log folder
  rm -rf ./*.sh
  rm -rf names-of-items-on-webpage
  rm -rf README.md
  rm -rf script_exec_finish
  rm -rf example.md
  rm -rf shellcheck-helper.log
  rm -rf shellcheck.log

  # Back to logs folder
  cd ../..
  rm -rf latest
  ln -fs "$DATE_VAR"/"$TIME_VAR" latest

  # Remove all but the logs from the last week... That is, all the logs from
  # the last 2 weeks do not get deleted  (1 folder a day, for 14 days plus
  # well as the symlink for the latest entry  ---  (1*14)+1 = 15 --- Use 16 in
  # script because it needs to be 1 more than the amount I need).
  # vv Ignore shellcheck warning about using ls
  # shellcheck disable=SC2012
  ls -tp | tail -n +16 | xargs -d '\n' rm -rf --
else
  echo " "
  echo "Usage: If no options are given, this script will run fully"
  echo "--cars-only : Will execute only the new car, or old car parts"
  echo " "
fi

cd ~/Documents/git-repos/remote-github/data-extract-from-website
# Remove all pdf files from root dir
rm -rf ./*.pdf

# bare bones check that this script finished:
echo "$(date +%F) $(date +%H:%M:%S)" > script_exec_finish
cp script_exec_finish logs/"$DATE_VAR"/"$TIME_VAR"

