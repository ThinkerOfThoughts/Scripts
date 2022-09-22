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


  printf "\nRemoving old package list.\n"
  apt clean

  printf "\nUpdating apt package list.\n"
  apt update

  printf "\nChecking if updates are available.\n"

updates='$(/usr/lib/update-notifier/apt-check --human-readable)'
if [ ${updates:0:1} != 0 ]
then {
      printf "Updates found. Installing.\n"

      #output of the command is going into a variable first so it can be used later
      output=$(apt-get -y dist-upgrade | tee /dev/tty)
      if [ $? -ne 0 ]
      then {
          printf "\nError installing updates. Aborting.\n";
          exit $retVal;
      } fi

      #checking if packages have been kept back for some reason
      if [[ $output == *"The following packages have been kept back"* ]]
      then {
        printf "\nPackages have been kept back and not upgrade, want to try indavidually installing them (this should give apt what it needs to upgrade them)?\n"
        read -p "Yes/No? " -n 1 -r
        echo #move to new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then {
            printf "\nOkay\n";
        }
        else {
              printf "\nParsing list of packages.\n"
              declare -a packages_array=("")

              packages_string="$(awk 'BEGIN {p=0}; /kept back:/{ p = 1 ; next }; /upgraded./ { p = 0; next; }; p { print }' <<< "$output")" #seperates out the list of kept back packages

              IFS=' ' read -r -a packages_array <<< "$packages_string" #splitting string of packages to array


              printf "\nPackages to upgrade:\n"
              echo $packages_string

              printf "\nAttempting to upgrade.\n\n"

              for i in "${packages_array[@]}"
              do
                printf "\nUpgrading: $i\n"

                output=$(sudo apt-get install $i | tee /dev/tty)
                if [ $? -ne 0 ]
                then {
                  printf "\nError installing updates. Aborting.\n";
                  exit $retVal;
                } fi
              done

            } fi
      } fi
  }
  else {
    printf "\nNo updates found.\n";
  } fi

printf "\nRemoving auto-installed packages that aren't needed any more.\n";
#cleaning up
apt -V autoremove
