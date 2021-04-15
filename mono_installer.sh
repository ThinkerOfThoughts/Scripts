#!/bin/bash


#Written by ThinkerOfThoughts
#Questions, concerns or comments please direct to ThinkerOfThoughts42@gmail.com


#need to be superuser to install stuff
printf "Checking super user status: ";
if [ "$EUID" -ne 0 ]
then {
	printf "Fail\nPlease re-run script as root user. Thank you.\n\nThis message is printed from line $LINENO\n\n"
	exit;
} fi
printf "OK\n\n";


#these commands were copied from https://www.mono-project.com/download/stable/#download-lin-ubuntu
mono_key="hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF";

repo_version_name="bionic";
repo_version_num=18.04;
printf "Mono version for Ubuntu $repo_version_num \"$repo_version_name\" is being used, to change this to a different version, change the name in line $((LINENO -3)), you don't need to change the version number (all its doing is making things easier to recognize)\n\n";
mono_repo="deb https://download.mono-project.com/repo/ubuntu stable-${repo_version_name} main";
mono_stable_list="/etc/apt/sources.list.d/mono-official-stable.list";


declare -a mono_tools=("mono-devel" "mono-complete" "mono-dbg" "referenceassemblies-pcl" "ca-certificates-mono" "mono-xsp4" "libgtk-3-dev" "gtk-sharp3" "libcanberra-gtk-module");

#name for generated test files,function to delete these goes entirly off of the name, not the extension, so the name must be unique
test_file_name="Bash_installer_testfile";

#The following is an array of the contents of the test files that will be generated to check the basic functionality of mono ones installed
declare -a tests=(
"using System;
public class HelloWorld
{
	public static void Main(string[] args)
	{
		Console.WriteLine (\"Hello Mono World\");
	}
}"

"using System;
using System.Windows.Forms;
public class HelloWorld : Form
{
    static public void Main ()
    {
        Application.Run (new HelloWorld ());
    }

    public HelloWorld ()
    {
        Text = \"Hello Mono World\";
    }
}"

"<%@ Page Language=\"C#\" %>
<html>
<head>
   <title>Sample Calendar</title>
</head>
<asp:calendar showtitle=\"true\" runat=\"server\">
</asp:calendar>"

"using Gtk;
using System;

class Hello
{
    static void Main ()
    {
        Application.Init ();

        Window window = new Window (\"Hello Mono World\");
        
		window.DeleteEvent += delete_event;
		
        window.Show ();

        Application.Run ();
    }
    
	static void delete_event (object obj, DeleteEventArgs args)
	{
		Application.Quit ();
	}
}"
);


#checks if the return value is 0; exits if it isn't
function error_check ( )
{
	retVal=$?;
	
	if [ $retVal -ne 0 ]
	then
	{
		printf "\nError triggered at or before $1\n\n";
		test_file_remover;
		exit $retVal;
	} fi
}


function test_file_remover()
{

	printf "Removing any generated test files containing the name $test_file_name (to disable this, comment out line $((LINENO+1)))\n\n";
	rm -f $test_file_name*
}

#repo setup
printf "Setting up repository\n";

sudo apt install gnupg ca-certificates;
error_check $LINENO;
sudo apt-key adv --keyserver $mono_key;
error_check $LINENO;
echo $mono_repo | sudo tee $mono_stable_list
error_check $LINENO;
sudo apt update
error_check $LINENO;

printf "\n\nOK\n\n";


#installing tools
for i in "${mono_tools[@]}"
do {
	printf "Installing $i\n";

	
	sudo apt-get install $i
	error_check $LINENO;

	printf "Installed $i\n\n";

} done

printf "\n\nOK\n\n";


printf "Testing basic compilation:\n";
printf "${tests[0]}" > "${test_file_name}0.cs";
error_check $LINENO;
csc "${test_file_name}0.cs";
error_check $LINENO;
mono "${test_file_name}0.exe";
error_check $LINENO;
printf "\n\nOK\n\n";



printf "Testing HTTPS:\n"
csharp -e "new System.Net.WebClient ().DownloadString (\"https://www.nuget.org\")"
error_check $LINENO;
printf "\n\nOK\n\n";


printf "Testing WinForms:\n"
printf "${tests[1]}" > "${test_file_name}1.cs";
error_check $LINENO;
csc "${test_file_name}1.cs" -r":System.Windows.Forms.dll"
error_check $LINENO;
mono "${test_file_name}1.exe"
error_check $LINENO;
printf "\n\nOK\n\n";

printf "Testing ASP.net:\n"
printf "${test[2]}" > "${test_file_name}2.aspx"
error_check $LINENO;
xsp4 --port 9000
error_check $LINENO;
printf "\n\nOK\n\n";


printf "Testing Gtk#:\n"
printf "${tests[3]}" > "${test_file_name}3.cs";
error_check $LINENO;
mcs "${test_file_name}3.cs" -pkg":gtk-sharp-3.0"
error_check $LINENO;
mono "${test_file_name}3.exe"
error_check $LINENO;
printf "\n\nOK\n\n";

test_file_remover

printf "\n\nMono and its dependencies should now be installed and working\n\n";

exit 0;
