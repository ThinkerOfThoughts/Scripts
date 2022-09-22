#!/bin/bash
#test_runner.sh

#things that need to be installed on local system
declare -a programs_basic_arr=("nmap" "java" "gradle" "ffmpeg");

#arguments
declare -a args=("-build" "-launch" "-awsLaunch" "-init" "-create" "-deploy" "-ssh" "-terminate" "-stdlog" "-errorlog" "-accesslog" "-enginelog" "-allLogs" "-man");

#explination of arguments, locations are 1 to 1 with args
declare -a arg_man=(
"\nAll arguments will be executed in the order they are given, i.e. maker.sh -launch -build will launch, and then build the app.\nIf one fails then the program will exit.\n"
"\n-build...............Builds the java code into a .jar file and packs it and the config files/directories into Bundle.zip\n"
"\n-launch...............Launches the local version in the default browser\n"
"\n-awsLaunch...............Launches the aws version in the default browser\n"
"\n-init...............Initializes a eb cli\n"
"\n-create...............Creates a new elastic beanstalk instance\n"
"\n-deploy...............Updates the aws instance currently on aws\n"
"\n-ssh...............Opens an ssh connection to the elastic beantstalk instance. \n\t\tNote: before running it for the first time you must first run the following eb ssh --setup\n"
"\n-terminate...............Terminates (deletes) the current elastic beanstalk instance\n"
"\n-stdlog...............Opens a window that streams the stdout log for the instance\n"
"\n-errorlog...............Opens a window that streams the error log for the instance\n"
"\n-accesslog...............Opens a window that streams the access log for the instance\n"
"\n-enginelog...............Opens a window that streams the engine error log for the instance\n"
"\n-allLogs...............Opens a window for each of the log files for the instance\n"
"\n-man...............Displays the commands for this script and what they do\n");

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )	#the /Yiutube directory containing source code
cd "$parent_path"


app_jar_name="YiuTube-0.0.1-SNAPSHOT.jar";
app_jar_path="build/libs/";

#where .git directory is, will be determined later
git_path="$parent_path"

config_files_name="eb_configuration_files";
#where the config files meant to be modified, that are used for comparisons in this script are located
config_files="$parent_path/$config_files_name";
#where the elastic beanstalk files are located relative to the directory containing .git
eb_extensions_filename=".ebextensions";
eb_extensions="$git_path/$eb_extensions_filename";
elasticbeanstalk_filename=".elasticbeanstalk"
eb_config="$git_path/$elasticbeanstalk_filename";
nginx_platform_name=".platform";
nginx_platform="$nginx_platform_name";
nginx_confd_path="$nginx_platform/nginx/conf.d";
nginx_conf_name="proxy.conf";
nginx_config_name="00_myconf.config";
ffmpeg_hook="1_ffmpeg_installer.sh";

#where the source bundlle will be stored
app_bundle_name="Bundle.zip";
app_bundle_path="build/libs";
full_bundle_path="$parent_path/$app_bundle_path/$app_bundle_name";

#folders to include in source bundle
git_dir_to_zip="./$eb_extensions_filename ./$elasticbeanstalk_filename $nginx_platform_name"
app_jar_to_zip="./$app_jar_name" #a hook is a file that runs after the environment has been created, this one installs ffmpeg
	

#ports used by app on aws
local_port=5000;
ssh_port=22;

eb_username=$(sed -n -e 's/ profile: //p' "$config_files_name/config.yml");
environment_name=$(sed -n -e 's/ environment: //p' "$config_files_name/config.yml");
securitygroup_name=$(sed -n -e 's/ value: //p' "$config_files_name/securitygroup.config");
app_name=$(sed -n -e 's/ application_name: //p' "$config_files_name/config.yml");


printf "Username: $eb_username\nEnvironment name: $environment_name\nSecurity Group: $securitygroup_name\ntApp Name: $app_name\n\n";

build_command="gradlew build --warning-mode all";

local_url="http://localhost:$local_port";

aws_url="yiutubedev-env.us-east-1$elasticbeanstalk_filename.com";


#strings for various commands
#aws cli specific
eb_init="eb init $app_name --profile $eb_username";
eb_create="eb create -s $app_name --profile $eb_username";
eb_deploy="eb deploy  -v --profile $eb_username";
eb_ssh="eb ssh --profile $eb_username";
eb_terminate="eb terminate $app_name --profile $eb_username";
eb_log_stdout="eb logs --stream -g /aws/elasticbeanstalk/Yiutubedev-env/var/log/web.stdout.log --profile $eb_username";
eb_log_access="eb logs --stream -g /aws/elasticbeanstalk/Yiutubedev-env/var/log/nginx/access.log --profile $eb_username";eb_log_error="eb logs --stream -g /aws/elasticbeanstalk/Yiutubedev-env/var/log/nginx/error.log --profile $eb_username";
eb_log_engine="eb logs --stream -g /aws/elasticbeanstalk/Yiutubedev-env/var/log/eb-engine.log --profile $eb_username"


#bash specific
local_server_ping=$"nmap -p $local_port localhost";
aws_server_ping="ping -w30 -c2 $aws_url";
ssh_server_ping="nc -vzw 2 $aws_url $ssh_port";
aws_launch="xdg-open http://$aws_url/";


# ebb_ssh_log="eb ssh --command "
# eb_ssh_log_stdout="sudo tail -f ../../../var/log/web.stdout.log";
# eb_ssh_log_access="sudo tail -f ../../../var/log/nginx/access.log";
# eb_ssh_log_error="sudo tail -f ../../../var/log/nginx/error.log";
# eb_ssh_log_engine="sudo tail -f ../../../var/log/eb-engine.log";

#error message
no_install_basic="Could not install ${programs_basic_arr[$i]}, to_install_basic_arr element number $i, prereq_installer.sh line: ";


for i in "${programs_basic_arr[@]}"
do {
	echo "Checking for ${programs_basic_arr[$i]}";

	if ! command -v ${programs_basic_arr[$i]}
	then {
		sudo apt-get update
		sudo apt-get install ${programs_basic_arr[$i]}

		if ! command -v ${programs_basic_arr[$i]}
		then {
			echo $no_install_basic $LINENO
			exit 1;
		} fi
		echo "Installed ${programs_basic_arr[$i]}";
	} else {
		echo "Found ${programs_basic_arr[$i]}";
	} fi
} done




#detects if running as superuser, this can cause problems if its allowed
printf "Checking super user status: ";
if [ "$EUID" -eq 0 ]
then {
	printf "Fail\nPlease re-run script as non-root user. Thank you.\nIf you did not run the script with sudo, superuser my have been entered during the installation of required libraries/applications, if this is the case, simply rerun the script.
\n\nThis message is printed from line $LINENO\n"
	exit;
} fi
printf "OK\n\n";

printf "Determining location of .git directory: ";
if [ ! -d "$git_path/.git" ]
then {
	printf "Fail\n.git not found in $parent_path\n"

	git_path="$(realpath "$parent_path/..")";
	
	printf "Checking in $git_path:\n"

	if [ ! -d "$git_path/.git" ]
	then {
		printf "Fail\n.git not found in $parent_path\n"

		git_path="$(realpath "$git_path/..")";
		
		printf "Checking in $git_path\n"
	
		if [ ! -d "$git_path/.git" ]
		then {
			printf "Fail\nError: Unable to find the .git directory in" $parent_path "or" $(realpath "$parent_path/..") " or " $PWD "Please manually run eb init from the directory containing .git, or modify git_path near the top of this script to the correct path. This message is printed from line $LINENO";
			exit;
		} fi
	} fi
	
	printf ".git found\nUpdating directory locations\n";
	eb_extensions="$git_path/$eb_extensions_filename";
	eb_config="$git_path/$elasticbeanstalk_filename";
	nginx_platform="$git_path/$nginx_platform_name"
	nginx_confd_path="$nginx_platform/nginx/conf.d";
	full_bundle_path="$parent_path/$app_bundle_path/$app_bundle_name";
} fi
printf "OK\n\n";


printf "Ensuring $eb_config exists: ";
if [ ! -d "$eb_config" ]
then {
	printf "Not found.";
	printf "\nCreating directory $eb_config\n";
	mkdir $eb_config;
} fi
printf "OK\n\n";

printf "Ensuring $eb_extensions exists: ";
if [ ! -d "$eb_extensions" ]
then {
	printf "Not found.";
	printf "\nCreating directory $eb_extensions\n";
	mkdir $eb_extensions;
} fi
printf "OK\n\n";


printf "\n\nPlease note that all config file comparisons done after this point are checked against the config files located in $config_files/\n If you wish to make a persistant change to a config file, change the files in that directory.\n\n"

#making sure the config.yml in $elasticbeanstalk_filename has the correct artifact name
printf "Ensuring $eb_config/config.yml is set correctly: ";
if [ ! -f "$eb_config/config.yml" ]
then {
	printf "Not found.";
	printf "\nCreating file $eb_config/config.yml\n";
	cp "$config_files/config.yml" "$eb_config";
	printf "Adding to git\n";
	git add -A;
} else {
	if [[ $(cmp --silent "$eb_config/config.yml" "$config_files/config.yml") ]]
	then {
		printf "Fail\nUpdating $eb_config/config.yml\n";
		rm "$eb_config/config.yml";
		cp "$config_files/config.yml" "$eb_config";
	} fi
} fi
printf "OK\n\n";

#makes the file and directory  needed to install ffmpeg on es2
printf "\nEnsuring $eb_extensions/$ffmpeg_hook is set correctly: ";
if [ ! -f "$eb_extensions/$ffmpeg_hook" ]
then {
	printf "Not found.";
	printf "\nCreating file $eb_extensions/$ffmpeg_hook: \n";
	cp "$config_files/$ffmpeg_hook" "$eb_extensions";
	printf "Adding to git\n";
	git add -A;
} else {
	if [[ $(cmp --silent "$eb_extensions/$ffmpeg_hook" "$config_files/$ffmpeg_hook") ]]
	then {
		printf "Fail\nUpdating $eb_extensions/$ffmpeg_hook\n";
		rm $eb_extensions/$ffmpeg_hook;
		cp "$config_files/$ffmpeg_hook"  "$eb_extensions";
	} fi
} fi
printf "OK\n\n";

#makes sure the instance is using the correct security group
printf "\nEnsuring $eb_extensions/securitygroup.config is set correctly: ";
if [ -f "$eb_extensions/securitygroup.config" ]
then {
	if [[ $(cmp --silent "$eb_extensions/securitygroup.config" "$config_files/securitygroup.config") ]]
	then {
		printf "Fail\nUpdating $eb_extensions/securitygroup.config\n";
		rm "$eb_extensions/securitygroup.config";
		cp "$parent_path/securitygroup.config" "$eb_extensions";
	} fi
} else {
	printf "Fail\nAdding securitygroup.config to $eb_extensions\n";
	cp "$config_files/securitygroup.config" "$eb_extensions";
	printf "Adding to git\n";
	git add -A;
} fi
printf "OK\n\n";
	
	
#nginx config is set up
printf "\nEnsuring $nginx_confd_path exists: ";

if [ -d "$nginx_confd_path" ]
then {
	printf "OK\n\n";
	printf "\nEnsuring $nginx_conf_name is set correctly: ";

	if [ -f "$nginx_confd_path/$nginx_conf_name" ]
	then {
		if [[ $(cmp --silent "$nginx_confd_path/$nginx_conf_name" "$config_files/$nginx_conf_name") ]]
		then {
			printf "Fail\nUpdating $nginx_confd_path/$nginx_conf_name\n";
			rm "$nginx_confd_path/$nginx_conf_name";
			cp "$config_files/$nginx_conf_name" "$nginx_confd_path";
		} fi
	} else {
			printf "Fail\nCreating $nginx_confd_path/$nginx_conf_name\n";
			cp "$config_files/$nginx_conf_name" "$nginx_confd_path";
	} fi
	printf "OK\n\n";
	
	printf "\nEnsuring $nginx_config_name is set correctly: ";
	if [ -f "$nginx_platform/$nginx_config_name" ]
	then {
		if [[ $(cmp --silent "$nginx_platform/$nginx_config_name" "$config_files/$nginx_config_name") ]]
		then {
			printf "Fail\nUpdating $nginx_platform/$nginx_config_name\n";
			rm "$nginx_platform/$nginx_config_name";
			cp "$config_files/$nginx_config_name" "$nginx_platform/$nginx_config_name";
		} fi
	} else {
		printf "Fail\nCreating $nginx_platform/$nginx_config_name\n";
		cp "$config_files/$nginx_config_name" "$nginx_platform/$nginx_config_name";
	} fi
	
} else {
	printf "Fail\nCreating directory $nginx_confd_path\n";
	mkdir -p $nginx_confd_path
	printf "Creating file $nginx_confd_path/$nginx_conf_name\n";
	cp "$config_files/$nginx_conf_name" "$nginx_confd_path";
	
	printf "Creating file $nginx_platform/$nginx_config_name\n";
	cp "$config_files/$nginx_config_name" "$nginx_platform";
	printf "Adding to git\n";
	git add -A;
} fi
printf "OK\n\n";

	
for argument in "$@" #runs through the given arguments in order
do {

	if [[ $argument == *"${args[0]}"* ]]
	then {
		printf "Removing old $app_jar_path/$app_jar_name\n";
		if [ -f "$app_jar_path/$app_jar_name" ]
		then 
		{
			rm 	$app_jar_path/$app_jar_name;
		} fi
			
		printf "Removing old source Bundle\n";
		if [ -f "$full_bundle_path" ]
		then
		{
			rm $full_bundle_path;
		} fi

		printf "Running build script\n";
		bash $build_command

		printf "Creating source Bundle: \n";
		if [ -d "$parent_path/$app_bundle_path" ]
		then
		{
			#the cd is needed as otherwise zip includes the filepath to the zipped thing
			cd $app_jar_path
			zip -r $full_bundle_path $app_jar_to_zip;
			if [ ! "$?" -eq 0 ] 
			then
			{
				printf "\nError: Could not create $full_bundle_path\n\nThis message is printed from line $LINENO\n"
				exit;
			} fi
			
			cd $git_path
			zip -r $full_bundle_path $git_dir_to_zip;
			if [ ! "$?" -eq 0 ] 
			then
			{
				printf "\nError: Could not create $full_bundle_path\n\nThis message is printed from line $LINENO\n"
				exit;
			} fi
			
			cd $parent_path;
			
			if [ ! -f "$full_bundle_path" ]
			then
			{
				printf "\nError: Could not create $full_bundle_path\n\nThis message is printed from line $LINENO\n"
				exit;
			} fi
		} else {
			printf "\nError: Could not find directory $parent_path/$app_bundle_path\n\nThis message is printed from line $LINENO\n"
			exit;
		} fi
		printf "OK\n\n";
	} fi
	
	if [[ $argument == *"${args[1]}"* ]]
	then {
		gnome-terminal -x java -jar $FILE; #launch app in another terminal
		((counter = 100))   #call nmap on url and port until a response is received indicating that the app is running
		until  $local_server_ping | grep "open" 
		do {
			((i=i+1))
			if [ "$i" -eq "10" ]
			then {
				printf '\n%s%s\n' "10 ping attempts have been made, something may have gone wrong. This message is printed from line: " "$LINENO\n";
			} fi
			echo "Waiting for server to come online";
			$local_server_ping
			sleep 2;
		} done
		
		if $local_server_ping | grep "open" 
		then {
			sleep 2;
			xdg-open $local_url;
		} fi
	} fi
	
	if [[ $argument == *"${args[2]}"* ]]
	then {
		echo "Waiting for server to come online";
		$aws_server_ping
		rc=$?
		if [[ $rc -ne 0 ]]
		then {
				printf "\n\nPinged for 30 seconds. Either something has gone wrong or things are being unusually s either way I give up. \nThe url for your YiuTube, is $aws_url \n\nThis message is printed from line $LINENO"\n;
		} else {
			printf "\nOpening $aws_url in default browser\n";
			sleep 2;
			$aws_launch;
		} fi
	} fi
	
	#reinitialize eb
	if [[ $argument == *"${args[3]}"* ]]
	then {
		cd $git_path;
		$eb_init;
		if [ ! "$?" -eq 0 ]
		then {
			exit;
		} fi
		cd $parent_path;
	} fi
	
	#create instance
	if [[ $argument == *"${args[4]}"* ]]
	then {
		cd $git_path;
		$eb_create;
		if [ ! "$?" -eq 0 ]
		then {
				exit;
		} fi
		cd $parent_path;
	} fi
	
	#deploy instance
	if [[ $argument == *"${args[5]}"* ]] 
	then {
		cd $git_path;
		$eb_deploy
		if [ ! "$?" -eq 0 ]
		then {
			exit;
		} fi
		cd $parent_path;
	} fi


	if [[ $argument == *"${args[6]}"* ]]
	then {
		((counter = 0)); #pinging url until a responce is recieved indicating that the app is running
		while  [[ ! $ssh_server_ping ]]
		do {
			((i=i+1))
			if [ "$i" -eq "15" ]
			then {  #app should be up and running by 15*2 seconds
				printf "Its been 30 seconds, something may have gone wrong.\n\nThis message is printed from line $LINENO\n";
				exit;
			} fi
			echo "Waiting for server to come online";
			sleep 2;
			$ssh_server_ping
		} done
		
		if [[ $ssh_server_ping ]]
		then {
			cd $git_path;
			gnome-terminal -- $eb_ssh;
			cd $parent_path;
		} fi
	} fi
	
	#terminates the app_name environment
	if [[ $argument == *"${args[7]}"* ]]
	then {
		read -p "Are you sure you want to terminate $app_name (y/n): " -r;
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then {
			$eb_terminate;
			if [ ! "$?" -eq 0 ]
			then {
				exit;
			} fi
		} fi
	} fi
	
	#opens a new terminal that streams specified log
	if [[ $argument == *"${args[8]}"* ]]
	then {
		cd $git_path;
		gnome-terminal -- $eb_log_stdout;
		cd $parent_path;
	} fi
	
	if [[ $argument == *"${args[9]}"* ]]
	then {
		cd $git_path;
		gnome-terminal -- $eb_log_error;
		cd $parent_path;
	} fi
	
	if [[ $argument == *"${args[10]}"* ]]
	then {
		cd $git_path;
		gnome-terminal -- $eb_log_access;
		cd $parent_path;
	} fi
	
	if [[ $argument == *"${args[11]}"* ]]
	then {
		cd $git_path;
		gnome-terminal -- $eb_log_engine;
		cd $parent_path;
	} fi

	
	if [[ $argument == *"${args[12]}"* ]]
	then {
			cd $git_path;
			gnome-terminal -- $eb_log_stdout;
			gnome-terminal -- $eb_log_error;
			gnome-terminal -- $eb_log_access;
			gnome-terminal -- $eb_log_engine;
			cd $parent_path;
	} fi
	
	if [[ $argument == *"${args[13]}"* ]]
	then {
			echo -e "${arg_man[@]}";

	} fi
	
	
# 	#open ssh terminal to stream a given logs
# 		if [[ $argument == *"-ssh_stdlog"* ]]
# 	then {
# 		cd $git_path;
# 		gnome-terminal -- $eb_ssh_log_stdout;
# 		cd $parent_path;
# 	} fi
# 	
# 	if [[ $argument == *"-ssh_errorlog"* ]]
# 	then {
# 		cd $git_path;
# 		gnome-terminal -- $eb_ssh_log_error;
# 		cd $parent_path;
# 	} fi
# 	
# 	if [[ $argument == *"-ssh_accesslog"* ]]
# 	then {
# 		cd $git_path;
# 		gnome-terminal -- $eb_ssh_log_access;
# 		cd $parent_path;
# 	} fi
# 	
# 	if [[ $argument == *"-ssh_enginelog"* ]]
# 	then {
# 		cd $git_path;
# 		gnome-terminal -- $eb_ssh_log_engine;
# 		cd $parent_path;
# 	} fi
# 	
# 
# 	if [[ $argument == *"-allLogs"* ]]
# 	then {
# 			cd $git_path;
# 			gnome-terminal -- $$eb_ssh_log_stdout;
# 			gnome-terminal -- $eb_ssh_log_error;
# 			gnome-terminal -- $eb_ssh_log_access;
# 			gnome-terminal -- $eb_ssh_log_engine;
# 			cd $parent_path;
# 	} fi
} done



#just keeping things neat, I hate it when scripts generate a bunch of large files and then don't clean them up
if [ -f "$bundle_path" ]
then {
	rm 	$full_bundle_path;
} fi
