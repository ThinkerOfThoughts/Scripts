#!/bin/bash


#Written by ThinkerOfThoughts
#Questions, concerns or comments please direct to ThinkerOfThoughts42@gmail.com

#This script will first check if the desired device is available, if it is, it will attempt to connect
#to it (if not already connected). If it is already connected, it will disconnect the device. If it is
#not available, nothing will happen.

#If you want to add this to a keyboard shortcut, put the script somewhere, say in your home directory, then go to
#System Settings > Shortcuts > Custom Shortcuts > Edit > New > Global Shortcut > Command/URL.
#In the "Trigger" tab, enter your keyboard shortcut you want.
#In the "Action" tab, enter the following:
#bash path_to_script/bluetooth_autoconnect.sh
#you have to use the full path for it to work, using the ~ shortcut doesn't work.

#add the mac address of your device here, can befound with bt-device -l
#note: for the above command you need bluez-tools (sudo apt install bluez-tools).
device_address="PUT MAC ADDRESS HERE"


#checking if mac address is valid
if bluetoothctl info "$device_address" | grep "Device $device_address not available" -q
    then {
        #if device is not detected, exit
        exit;
    } fi

if bluetoothctl info "$device_address" | grep 'Connected: yes' -q; then
    #if device is connected, disconnect
  bluetoothctl disconnect "$device_address"
else
    #if device is not connected, connect
  bluetoothctl connect "$device_address"
fi
