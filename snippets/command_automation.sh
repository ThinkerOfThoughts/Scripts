#!/bin/bash


#Written by ThinkerOfThoughts
#Questions, concerns or comments please direct to ThinkerOfThoughts42@gmail.com

#program to be run
program="someprogram";

#prompts to expect
declare -a prompts=(
"prompt_0"
"prompt_1"
"prompt_2"
"prompt_3"
"prompt_4");

#commands to be sent
declare -a commands=(
"command_0"
"command_1"
"command_2"
"command_3"
"command_4");

expect <<-EOF
    set timeout -1
    spawn $program  #launching program

    expect "${prompts[0]}" { send "${command[0]}\r" } #sending first command when prompt[0] is given

    expect eof
    catch wait result
    exit [lindex \$result 3]
EOF
