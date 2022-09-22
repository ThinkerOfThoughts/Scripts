#!/bin/bash


#Written by ThinkerOfThoughts
#Questions, concerns or comments please direct to ThinkerOfThoughts42@gmail.com

#All this does is update/upgrade everything with one update. Meant to be tied to a custom terminal command. To add it to the list of commands, in terminal run "nano ~/.bashrc", scrolls down to "# some more ls aliases" and add "alias update_all='sudo bash PATH_TO_FILE/update_all.sh", ctrl+o to save, ctrl+x, to exit, then restart the terminal.

printf "Checking super user status: ";
if [[ $EUID > 0 ]]
  then {
      printf "Fail\nPlease re-run script as root user. Thank you.\n\n"
      exit
} fi
  printf "OK\n\n";


  printf "Removing old package list.\n"
  apt clean

  printf "Updating apt package list.\n"
  apt update

  printf "Checking if updates are available.\n"

updates='$(/usr/lib/update-notifier/apt-check --human-readable)'
if [ ${updates:0:1} != 0 ]
then {
      printf "Updates found. Installing.\n"
      apt -y dist-upgrade

      if [ $? -ne 0 ]
      then {
          printf "\nError installing updates. Aborting.\n";
          exit $retVal;
      } fi
  }
  else {
    printf "No updates found.\n";
  } fi

printf "Removing auto-installed packages that aren't needed any more.\n";
#cleaning up
apt -V autoremove
