#!/bin/bash


#Written by ThinkerOfThoughts
#Questions, concerns or comments please direct to ThinkerOfThoughts42@gmail.com

#Write a .txt file with a list of installed programs/libraries (formated as demonstrated below), and this script will attempt to install them
#command to run is ./Installer file_with_programs.txt
<<format
@apt
program_1
program_2
program_3
@snap
snap_program1
snap_program2
snap_program3
@custom
some wierd command needed to install
one command per line
they will be run in sequence.
when the end of a sequence is reached
!
use that
format


#functions

#need to be superuser to install stuff
printf "Checking super user status: ";
if [ "$EUID" -ne 0 ]
then {
	printf "Fail\nPlease re-run script as root user. Thank you.\n\nThis message is printed from line $LINENO\n\n"
	exit;
} fi
printf "OK\n\n";


#checks if the return value is 0; exits if it isn't
function error_check ( )
{
	retVal=$?;

	if [ $retVal -ne 0 ]
	then
	{
		printf "\nError triggered at or before $1\n\n";
		exit $retVal;
	} fi
}

#updates package list and system prior to adding things
function update ( )
{

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

		error_check
	}
	else {
		printf "No updates found.\n";
	} fi

	printf "Removing auto-installed packages that aren't needed any more.\n";
	#cleaning up
	apt -V autoremove
}

#reads in given file, or attempts to at least
function file_in ( )
{
	printf "Attempting to read in $1";
	if [ ! -d "$1" ]
	then {
		printf "Not found.";
		exit
	} fi

	#temp array
	declare -a temp=("");

	#readarray reads file into array
	#-d \n sets delimiter to newline
	#-t removes trailing newline
	readarray -d \n -t temp < $1
	error_check

	printf "File read in successfully. Parsing."
	for i in "${apt_apps[@]}"
	do {


	} done

	printf "OK\n\n";
}



#variables
#these are ones that can be installed with apt, just add the names of specific programs/libraries to the array
declare -a apt_apps=("");

#ones to be installed with snap
declare -a snap_apps("");

#These are ones that require weird commands to install, add the entire command to the array, if there is a series, add one, then the next, in order
declare -a custom_commands("");





#main

update
printf "\n\nOK\n\n";


#reading in files





#apt stuff
for i in "${apt_apps[@]}"
do {
	printf "Installing $i\n";

	sudo apt-get install $i
	error_check $LINENO;

	printf "Installed $i\n\n";

} done

#installing non-apt stuff
for i in "${secondary_installer[@]}"
do {
	printf "Running $i\n";


	sudo $i
	error_check $LINENO;

} done
printf "\n\nOK\n\n";
exit 0;
