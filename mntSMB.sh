#!/bin/bash
#
# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the "Do What The Fuck You Want To"
# Public License, Version 2, December 2004, as published by Sam Hocevar.
# See http://sam.zoy.org/wtfpl/COPYING for more details.
# or https://en.wikipedia.org/wiki/WTFPL

# Authors: Huw Hamer Powell <huw@huwpowell.com>
# Purpose: Check if there is an SMB Server in your network and mount shares from it
#	If a share is already mounted prompt and Unmount it if it is already mounted.
#	The mount point is created and destroyed after use (to prevent
#	automatic backup software to backup in the directory if the device
#	is not mounted)

# Version 3, enhanced for Ubuntu 13.X+, Fedora 35+, and similar distros.
# Runs on all GNU/Linux distros (install cifs-utils)

# Version 4, Crafted a mod for FC32+ and added some visible interactions using zenity/yad ..Else silent) HHP 20200509
# Added the use of zenity/yad to produce dialog in Gnome
# Added proper mount options to cope with SMB Vers=1.0 and x display icons for mounted drives

# Runs on all GNU/Linux distros (install cifs-utils) (maybe required. Try without first HHP 20200513)
# UNUNTU needs cifs-utils and smb-client (apt install cifs-utils smb-client)

#  1) Install cifs-utils (sudo dnf install cifs-utils) (probably not required in FC32 but try without first) HHP 20200509
#  2)If you want to use the full functionality of nice dialog boxes install yad . otherwise we default to zenity *not so nice but it works)
#  3) Change the first four variables according to your configuration. Or maintain a .ini file with the four variables. Can be created by the script if neccessary
#  4) Run this program at boot or from your $HOME  when your network is ready
#	(need to use sudo.. so run the skeleton script mntSMB which will call this script (mntSMB.sh) using sudo... Or from the CLI or Gnome Desktop 
#		   Also, run it on logoff to umount any mounted shares (Will remove the mount point directory). Does not matter if you don't , Just cleaner if you do :)
#
#------ Edit these four DEFAULT options to match your system. Alternatinvely create the .ini file and edit that instead and save the .ini file for next time
_IP="10.0.1.200"					# e.g. "192.168.1.100"
_VOLUME="TimeCapsule"				# Whatever you named the SMB share"
_USER="`hostname`"					# The User id ON THE SMB Server .. else Guest/anonymous (defaults to the currect hostname)
_PASSWORD="88888888"					# Password for the Above SMB Server User, prefix special characters, e.g.
#------
_MOUNT_POINT=/media					# Base folder for mounting (/media recommended but could be /mnt or other choice)

NC_PORT=139						# Which port to use to connect during scanning
TIMEOUTDELAY=5						# timeout for dialogs and messages. (in seconds)
YADTIMEOUTDELAY=$(($TIMEOUTDELAY*4))			# Extra time for completing the initial form and where necessary



#------------ SMB PROTOCOL LEVEL IMPORTANT!!!!!!!!! -----------
#------------ if you use Apple TimeCapsule --------------------
# We use smbclient to find out the available shares on the TimeCapsule SAMBA/WINDOWS/SMB server 
# Because the TimeCapsule uses SMB1 protocol (most Linux Distributions default to SMB3)
# Add these lines to /etc/samba/smb.conf in the [GLOBAL] section
#	client min protocol = NT1		;; Add this line to enable smbclient operations ( Getting list of shares etc. below ) Dont add it and smbclient will not work!
#	client use spnego = no			;; Add these two lines if you intend to use Anonymous/Guest login
#	client NTLMv2 auth = no			;; (else using Username and Password does not need them)
#
# OTHERWISE set these options for smbclient. Then you do not have to change the defaults for the whole system in /etc/samba/smb.conf

SMBPROTOCOL_LEVEL="NT1"
SMBCLIENT_USER="-N"						# To check with Guest login using selected protocol (e.g. SMB1)
#SMBCLIENT_USER="-U%$_PASSWORD"			# To check with UserName%password and using selected Protocol

#------------ end SMB PROTOCOL LEVEL IMPORTANT!!!!!!!!! -----------
#
######## !!!!!!!!!!!!!! DON'T MODIFY ANYTHING BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING !!!!!!!!!!!!!! ##########
######## !!!!!!!!!!!!!! DON'T MODIFY ANYTHING BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING !!!!!!!!!!!!!! ##########
#
#-------Functions -----------------------------------------------------------------------------
#------ yad test -------------- Not used in this script.. It is Just a testbed

function yad-test () {

OUT=$(yad --on-top  --center --window-icon $YAD_ICON --image $YAD_ICON --geometry=800x800\
	--center --on-top --close-on-unfocus --skip-taskbar --align=right --text-align=center --buttons-layout=spread --borders=25 \
	--separator="," \
	--list --radiolist \
       	--columns=4 \
      	--title "Select Share" \
	--button="Select":2  \
	--button="Cancel":1 \
	--column "Sel" \
	--column "Server" \
	--column "Share" \
	--column "Comment" \
      	True "List contents of your Documents Folder" 'ls $HOME/Documents' "comment"\
      	False "List contents of your Downloads folder" 'ls $HOME/Downloads' "Comment" \
      	False "List contents of your Videos folder" 'ls $HOME/Videos' "Comment"
	)	
	if [ $? = "1" ]
		then exit
	fi
	
	OUT=$(echo "$OUT" \
	| cut -d "|" -s -f2,3 \
	| paste -s -d"|" \
	)
	echo "" \
	echo "The output from Yad is  '$OUT'" \
	; echo ""

	}
#------ end yad test -------
#-------save-vars-----------
function save-vars() {
# Save the defaults into the .ini or .last file

if [ -z $1 ]; then					# Checks if any params.
	VAREXTN="ini"					# default extension is .ini
else
	VAREXTN="$1"					# Take the extension from the arguments
fi

echo "# This file contains the variables to match your system and is included into the main script at runtime">$_PNAME.$VAREXTN	# create the file
echo "# if this file does not exist you will get the option to create it from the defaults in the main script">>$_PNAME.$VAREXTN
echo "">>$_PNAME.$VAREXTN

echo '_IP="'"$_IP"'"		# e.g. 192.168.1.100' >>$_PNAME.$VAREXTN
echo '_VOLUME="'"$_VOLUME"'"	# Whatever you named the Volume share' >>$_PNAME.$VAREXTN
echo '_USER="'"$_USER"'"		# The User id ON THE SMB server' >>$_PNAME.$VAREXTN
echo '_PASSWORD="'"$_PASSWORD"'"	# Password for the Above SMB Server User' >>$_PNAME.$VAREXTN
echo '_MOUNT_POINT="'"$_MOUNT_POINT"'"	# Base folder for mounting (/media recommended but could be /mnt or other choice)' >>$_PNAME.$VAREXTN
echo "">>$_PNAME.$VAREXTN
echo "#-- Created `date` by `whoami` ----">>$_PNAME.$VAREXTN
chown --reference $_PNAME $_PNAME.$VAREXTN			# Give ownership to the caller

} # NOTE : The user name is not saved (commented out) to enable the hostname to be set next time around. Uncomment the line in the .ini file if a specific user name is required

#-------------END save-vars-----------
#------------ do-exit ------------------
function do-exit () {

	zenity --warning --no-wrap --width=250 --timeout=1\
		--title="Restart" \
		--text="<span foreground='red'><big><big><b>Restarting</b></big></big></span><span><b>\n\nResart for changes to take effect</b></span>"

	_UID=$(echo $_UID|tr ',' ' ')		# Replace the comma with a space (as was passed originally)
	exec "$_MY_PNAME" "$_UID" "$_PNAME"	# Restart the script with new possible changes in the files

#		exit 0				# Shutdown -- Go no further
}
#------------ END do-exit
#------------- edit-file --------------------
function edit-file() {
# Edit a support file
# Inputs $1=The file extension $2=A narrative/Instructions message
_FILE="$_PNAME.$1"

DOsave="N"				# Assume No Save

	if [ -n "$2" ]; then				# Display a Narrative/Instructions Dialog
		zenity --info --width=350 --timeout=$YADTIMEOUTDELAY \
		--title="Edit : $_FILE" \
		--text="$2"
	fi

	if [ -f $_FILE ]			# read the contents of the file if it exists
	then
		_FILE_CONTENTS=$(cat $_FILE)
	else
		_FILE_CONTENTS=""
	fi

EDIT_TXT=$(zenity --text-info --width=350 --height=500 \
	--title="Edit : $_FILE" \
	--editable \
	--checkbox="Save $_FILE?" \
	 <<<$_FILE_CONTENTS \
	)

	case $? in			# $? is the zenity return code
		0)DOsave="Y" ;;		# zenity/yad returns 0 for OK so save the  file
		1|70) ;;		# zenity/yad returns 1 for Cancel (Timeout or Close if --default-cancel is set)
		-1|252|255) ;;		# Just here to consider any other exit return codes (see zenity and yad documentation)
	esac
					# Exit with three variables set
					# DOsave = "Y" or "N"
					# EDIT_TXT = whatever was returned from the edit *"" if Cancelled*
					# _FILE = Name of the file to save
}
# ------------ END edit-file ---------
#------------- edit-subnets --------------------
function edit-subnets() {

	_NARRATIVE="<span foreground='blue'><b><big>Enter subnets in the format xxx.xxx.xxx.xxx/mm\nor xxx.xxx.xxx.xxx or xxx.xxx.xxx\n\n</big>ie 192.168.1.0/24\nor 172.162.2.0\nor 10.0.3</b></span>"
	edit-file subnets "$_NARRATIVE"

if [ $DOsave = "Y" ]; then
	_FILE_OUT=$(echo "$EDIT_TXT" \
	|grep -o -E '([0-9]{1,3}\.){2}[0-9]{1,3}' \
	|awk -v mask=".0/24" 'BEGIN{OFS=""} {print $1,mask ;} ' \
	|sort -u \
	)
	echo "$_FILE_OUT"| sed -e '/^$/d' >$_FILE	# Save any valid input to $_FILE ignoring blanks
	chown --reference $_PNAME $_FILE		# Give ownership to the caller

fi
}
# ------------ END edit-subnets ---------
#------------- edit-servers --------------------
function edit-servers() {

	_NARRATIVE="<span foreground='blue'><b><big>Enter servers in the format xxx.xxx.xxx.xxx,name\n\n</big>ie 192.168.1.106,Nas1\nor 172.162.2.6	Server2</b>\n\nSeparate the two fields with <b>ONE</b> comma (,) or <b>ONE</b> TAB\n\nPut each server on a separate line</span>"
	edit-file servers "$_NARRATIVE"

	if [ $DOsave = "Y" ]; then
		_FILE_OUT=$(echo -n "$EDIT_TXT" \
		|grep -E '\b((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.)){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))\b' \
		|awk 'BEGIN{FS="[,\t]";OFS=""} {print $1,",",$2,"\n" ;} ' \
		|sort -u -t "," -k1,1 \
		)			# grep extracts only Valid IP addresses and discards invalid

		echo "$_FILE_OUT"| sed -e '/^$/d' >$_FILE	# Save valid input to $_FILE ignoring blanks
		chown --reference $_PNAME $_FILE		# Give ownership to the caller
	fi
}
# ------------ END edit-servers ---------
#------------- scan-subnets --------------
# We scan subnets with nmap. This is slower than arp-scan and could take 30-40 seconds per subnet
function scan-subnets() {
local M_PROCEED='no'						# Not yet scanned
while [ "$M_PROCEED" ]					# Keep going until scan finished
do
# look for subnets file

	if [ -f $_PNAME.subnets ]; then
		SCAN_SUBNETS=$(cat $_PNAME.subnets |grep -v $_SUBNET|sort -u ) # remove any current entry for this subnet and select only unique lines (No duplicates)
	fi

	if [ -n "$SCAN_SUBNETS" ]; then
		if [ -z "$_SERVERS_AND_NAMES" ]; then
			SCAN_KNOWN_SERVERS="None"
		else
			SCAN_KNOWN_SERVERS=$_SERVERS_AND_NAMES
		fi
		SCAN_SUBNETS=$(awk 'BEGIN{FS="\n";OFS=""} {print "FALSE\n",$1 ;} '<<<$SCAN_SUBNETS)

		OUT=$(yad --list --geometry=500x500 --separator="|" --on-top --close-on-unfocus --skip-taskbar --align=right --text-align=center --buttons-layout=spread --borders=25 \
			--window-icon $YAD_ICON --image $YAD_ICON \
			--checklist \
			--multiple \
			--title="Subnets to Scan" \
			--text="<span><b><big><big>Contents of $_PNAME.subnets\n\n</big>Select Any that you want to Scan\nthen Proceed to scan selected Subnets</big></b></span>\n\nWe can already see these servers\n$SCAN_KNOWN_SERVERS\n" \
			--columns=2 \
			--column="Sel" \
			--column="Subnet" \
			--button="Edit Subnets":4 \
			--button="Don't scan any":3 \
			--button="Scan Selected":2 \
			<<< "$SCAN_SUBNETS"
			)
		if [ $? = "4" ]
		then
			edit-subnets				# edit the subnets file
		else
			M_PROCEED=''				# Attempt the scan and leave the function
		fi						# Falls though to selection below

		if [ -n "$OUT" ]					# if anything was selected
			then
			SCAN_SUBNETS=$(echo "$OUT" \
			| awk 'BEGIN{FS="|";OFS=""} {print $2;} '  \
			)						# Select the subnets to scan

			Stmp_out=$(mktemp --tmpdir `basename $_PNAME`.XXXXXXX)	# Somewhere to store output

			while IFS= read -r S_SN; do
				show-progress "Scanning" "Finding Servers on $S_SN" \
				"nmap -n -oG $Stmp_out --append-output -sn -PS$NC_PORT $S_SN" 	# find out what machines are available on the other subnets
			done <<<$SCAN_SUBNETS
	
			_SUBNET_IPS=$(cat "$Stmp_out" \
			|grep "Status: Up" \
			|grep -o -E '([0-9]{1,3}\.){3}[0-9]{1,3}' \
			|sort -u
			)
			
			rm -f $Stmp_out			# delete temp file after reading content

			_SUBNET_SERVERS=""

			for S_IP in $(echo "$_SUBNET_IPS")
			do
				echo "# Scanning ... $S_IP"			# Tell zenity what we are doing 
#				_TMP=$(nc -n -zw1 $S_IP $NC_PORT 2>&1)
				_TMP=$(smbclient -g -L $S_IP -N 2>&1)	# This is much faster than NC and gives the same return code (0-Sucess 1-Fail)
				if [ $? = "0" ]				# if connected sucessfully add this IP as an SMB server
				then
					S_NAME=$(nmblookup -A $S_IP |grep "<00>"|grep -vi '<group>'|cut -d" " -s -f1|tr -d '\t')	#Find the NETBIOS name |tr -d '\t' removes the leading tab characters
					_SUBNET_SERVERS=$(echo "$_SUBNET_SERVERS\n$S_IP,$S_NAME")
				fi
			done> >(zenity --progress --pulsate  --width=250 --auto-close --no-cancel \
				--title="Scanning for SMB servers" \
				--text="Scanning .." \
				--percentage=0)					# Track progress on screen


			if [ -n "$_SUBNET_SERVERS" ]; then

				_SERVERS_FILE=""
				if [ -f $_PNAME.servers ]; then # Get all from the existing .servers file
					_SERVERS_FILE=$(cat $_PNAME.servers)
 				fi
				_NEW_SERVERS=$(echo -e "$_SERVERS_FILE\n$_SUBNET_SERVERS"|sort -u -t "," -k1,1) # remove any duplicates				
			# Append new Servers found to Servers file for later processing, Ignore blank lines
				echo "$_NEW_SERVERS"|sed -e '/^$/d'|sort -u -t "," -k1,1 > $_PNAME.servers
				chown --reference $_PNAME $_PNAME.servers	# Give ownership to the caller
			fi
		fi
	else
		zenity	--question --no-wrap \
			--title="No subnets found" \
			--text="No subnets found in $_PNAME.subnets\n\nEdit the $_PNAME.subnets file\nand try again?"
		if [ $? = "0" ]
		then
			edit-subnets				# edit the subnets file
		else
			M_PROCEED=''				# Ignore and leave the function
		fi
	fi							# end scan subnets
done
}
#------------ END scan-subnets--------
#------------ show-progress ----------
# A function to show a progress countdown for a command that might not be intantanious (Return the output from that command in the temp file $SPtmp_out
function show-progress() {

# args == "$1=DialogTitle", "$2=Text to display", $3="command to execute"
# Accept an agrument of a command to execute and wrap the progress bar around it
# open tmp file to accept the output from the command
# use zenity progress bar to execute command with progress bar, close progress bar when complete
# read output from the command and return to the caller in the var $SP_RTN
	
	SPtmp_out=$(mktemp --tmpdir `basename $_PNAME`.XXXXXXX)			# Somewhere to store any error message or output *(zenity/yad eats any return codes from any command)
	
	bash -c "$3 2>&1" \
	| tee $SPtmp_out \
	| zenity --progress --pulsate --auto-close --no-cancel --title="$1" --text="$2"

	SP_RTN=$(cat $SPtmp_out) 			# Read any error message or output from command ($3) from the tmp file 
	rm -f $SPtmp_out				# delete temp file after reading content
} 					# return the output from the command in the variable  $SP_RTN	
# ---------- unmount -------------------
# ---------- umount and trap any error message

function unmount() {
		show-progress "unMounting" "Attempting to unmount $1" \
		"umount '$1'"

		ERR=$(echo "$SP_RTN")							# Read any error message

# --- end umount (any error message is in $ERR
		
		if [ -z "$ERR" ] ; then
			UNMOUNT_ERR=false						#Sucess
			
			if [ "$1" != "$MOUNT_POINT_ROOT" ]; then		# Dont remove the mount root is mount point is not set correcly
				rmdir "$1"					# Happened during testing DUHHH
			fi

			zenity	--warning --no-wrap \
			--title="Unmounted Volume" \
			--text="$1\nVolume was previously mounted.... Unmounted it!!  " \
			--timeout=1							# sucess message timeout 1 second
			
		else									# unmount failed
			UNMOUNT_ERR=true

			zenity	--error --no-wrap \
			--title="$1\nVolume is STILL Mounted" \
			--text="Something went wrong!!...  \n\n $ERR \n\nFailed to umount Volume $1 try again  " \
			--timeout=$TIMEOUTDELAY
		fi 									
	
	}
# -------------- END unmount ----------------
#--------------- set-netbiosname -------------
function set-netbiosname() {

	_NETBIOSNAME=$(echo "$_SERVERS_AND_NAMES" \
		|grep -iw $1 \
		|cut -d" " -s -f2 \
		|sed 's/\t//' \
		)											#1. Find the NETBIOS name "|sed 's/\t//' removes any tab characters 
	_LASTSERVERONLINE=true
	if [ -z "$_NETBIOSNAME" ]; then
		_NETBIOSNAME="<span foreground='red'>*OFFLINE*</span>"  				# If name not found, it is probably offline
		_LASTSERVERONLINE=false								# Show it as offline
	fi
}
# -------------- END set-netbiosname -------
#--------------- select-mounted -------------
function select-mounted() {
	M_PROCEED=''
# Find out what is currently mounted
	show-progress "Initializing" "Finding mounted Shares" \
	"mount"												# find out what SMB/CIFS shares are currently mounted
													# Parse a list of IP addresses and mount points
	MOUNTED_VOLS=$(echo "$SP_RTN" \
		|grep  -w cifs \
		|sort \
		|sed 's+ on /+\t/+g' \
		|sed 's+ /+\t/+g' \
		|awk 'BEGIN{FS=" type cifs ";OFS=""} {print $1;} '  \
		|awk 'BEGIN{FS="\t";OFS=""} {print "FALSE\n",$1,"\n",$2;} '				# make 3 columns (FALSE MountedVol MOUNTPOINT)
		)
# if anything is mounted  $MOUNTED_VOLS now looks like this
# FALSE
# //192.168.1.2/Movies
# /media/Movies
# FALSE
# //192.168.1.106/Music
# /media/Music
# 
# every field on seperate lines

	if [ -n "$MOUNTED_VOLS" ]									# if anything is mounted switch the IP address to be the NETBIOSNAME
	then
		while IFS= read -r VOL; do
#
			M_IP=$(echo $VOL \
			|grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' \
			)										# pull the IP address of the mounted volume line

			if [ -n "$M_IP" ]
				then MOUNTED_SERVERS="$MOUNTED_SERVERS $M_IP"
			fi										# append to the list of mounted servers if found

		done <<<$MOUNTED_VOLS

		if [ -n "$MOUNTED_SERVERS" ]
	       		then 
			for S_IP in $(echo "$MOUNTED_SERVERS" | sed -e '/^$/d' )		# Find all servers that have something mounted | sed -e '/^$/d' ignores blank lines
			do									
				set-netbiosname $S_IP						# Get the netbios name into _NETBIOSNAME
				MOUNTED_VOLS=$(sed 's+//'"$S_IP"'+'"$_NETBIOSNAME"'+g' <<<$MOUNTED_VOLS)	#switch the IP address for the NETBIOS name remove the leading double slashes
			done
		fi			

# Now $MOUNTED_VOLS looks like this
# FALSE
# hpRyanLD/Movies
# /media/Movies
# FALSE
# HHPCLOUDNAS/Music
# /media/Music

# IP addresses changed to be NETBIOSNAME
#
		OUT=$(yad --list --geometry=700x500 --separator="|" --center --on-top --close-on-unfocus --skip-taskbar --align=right --text-align=center --buttons-layout=spread --borders=25 \
		       		--window-icon $YAD_ICON --image $YAD_ICON \
				--checklist \
				--multiple \
				--title="Mounted CIFS Voumes" \
				--text="<span><b><big><big>Currently Mounted Volumes\n\n</big>Select Any that you need to UnMount\nOr just Proceed to the mount option</big></b></span>\n" \
				--columns=3 \
				--column="Sel" \
				--column="Share" \
				--column="MountPoint" \
				--button="uMount Selected":2 \
				--button="Proceed":3 \
				<<< "$MOUNTED_VOLS"
		)

		if [ -n "$OUT" ]						# if anything was selected
			then 
			VOLS2UMOUNT=$(echo "$OUT" \
			| awk 'BEGIN{FS="|";OFS=""} {print $3;} '  \
			)							# Select the third field 'the mount point' from each selected item
										# add single quotes in case there is a space in the volume name
			while IFS= read -r VOL; do
				unmount "$VOL"					# Unmount the selected volume(s)
				M_PROCEED='no'					# force us to be called again
										# if anything is unmounted
			done <<<$VOLS2UMOUNT
		fi								# endif anything selected for unmount

	fi									# endif anything mounted
}
# --------------- END select-mounted --------------
#---------------- select-share -------------
function select-share() {

	set-netbiosname $_IP						# Get the NETBIOS name of the last used/selected server into _NETBIOSNAME

	YAD_DLG_TEXT=$(echo "<span><big><b><big>Select the Server and Volume data</big>\nPress Escape to use the last mounted volume</b></big>\n\n" "$_IP - $_VOLUME" "\n$_NETBIOSNAME" "</span>")

# Put the last used server and share at the top of the list
	SELECT_VOLS=$(echo -e "TRUE\n$_IP\n$_NETBIOSNAME\n$_VOLUME")

	for S_IP in $(echo "$_SERVERS" | sed -e '/^$/d' )				# Find all available shares on all servers | sed -e '/^$/d' ignores blank lines
	do										# Parse a list of IP addresses and NETBIOS names (2 columns IP and NETBIOS name)
		set-netbiosname $S_IP							# Get the netbios name into _NETBIOSNAME

		CHECK_VOLS=$(echo "$AVAILABLE_VOLS" | grep -iw $S_IP | grep -iwv "$_VOLUME")	# Get available vols for this IP address. (Ignore last used as it is already to the top of the list

		if [ -n "$CHECK_VOLS" ]							# if we found anything
		then
			CHECK_VOLS=$(awk -v sname="$_NETBIOSNAME" 'BEGIN{FS="|";OFS=""} {print "FALSE\n",$1,"\n",sname,"\n",$2;} '<<<$CHECK_VOLS) # make 3 columns (IP NETBIOSNAME SHARENAME)
			SELECT_VOLS=$(echo -e "$SELECT_VOLS\n$CHECK_VOLS")
		fi
	done

	OUT=$(yad --on-top  --center --window-icon $YAD_ICON --image $YAD_ICON --geometry=800x800\
		--center --on-top --close-on-unfocus --skip-taskbar --align=right --text-align=center --buttons-layout=spread --borders=25 \
		--separator="|" \
      		--title "Select Share" \
		--text="$YAD_DLG_TEXT" \
		--list --radiolist\
       		--columns=4 \
		--button="Exit":1 \
		--button="Edit Servers":4 \
		--button="Scan Subnets":3 \
		--button="Select":2 \
		--column "Sel" \
		--column "IP" \
		--column "Server" \
		--column "Share" \
	 	<<<"$SELECT_VOLS"
	)
	case $? in					# $? is the return code from the zenity/yad call
		0|2) ;;					# zenity/yad returns 0 for OK 2 is Select Button
		1|70) exit ;;				# Exit Button Selected

		3) scan-subnets	;do-exit;;		# Scan the subnets and Restart the script with any 
							# new possible server(s) in the .servers file
							# *WILL RESTART THE WHOLE SCRIPT*

		4) edit-servers ;do-exit;;		# Edit .servers file directly *Will restart the script*

		-1|252|255) ;;				# Just here to consider any other exit return codes (see zenity and yad documentation)
	esac

	SP_RTN=$(echo "$OUT" \
	| cut -d "|" -s -f2,3,4 \
	)
	
	}

#---------------- end select-share -------------
#-------- select-mountpoint ------
function select-mountpoint ()
{
while [ ! -d "$_MOUNT_POINT" ]; do				# Does the mount point root exist?
		Q_OUT=$(zenity --list \
			--title="Mount Point Not defined" \
			--text "Select the root mount point" \
			--radiolist \
			--column "sel" \
			--column "Mount Point" \
			TRUE "/media" \
			FALSE "/mnt" \
			FALSE "Other"
			)
	if [ -z $Q_OUT ]; then				# Most likely cancel was selected or dialog closed
		Q_OUT="Other"				# set to Other and manually collect input
	fi

	NEW_MOUNT_POINT="$Q_OUT"

	if [ "$NEW_MOUNT_POINT" = "Other" ]; then

		NEW_MOUNT_POINT=$(zenity --forms --width=500 --height=200 --title="Mount Point Not defined" \
				--text="\nSelect the root mount point\n\nSuggested choices are '/media or /mnt'" \
				--add-entry="Root Mount Point - "$_MOUNT_POINT \
				--cancel-label="Exit" \
				--ok-label="Select This Mount Point" \
			)
	fi

	if [ -n "$NEW_MOUNT_POINT" ]; then
		_MOUNT_POINT="$NEW_MOUNT_POINT"				# Get the user input
	else
		exit							# Exit whole process
	fi
done

if [ ! -z $_PNAME ] ; then
	MOUNT_POINT_ROOT=$_MOUNT_POINT"/$_PNAME"	# Append the user calling user name if set as $2
	if [ ! -d $MOUNT_POINT_ROOT ]; then
		mkdir $MOUNT_POINT_ROOT			# make the mountpoint directory if required.
		chown --reference $_PNAME $MOUNT_POINT_ROOT	# Give ownership to the caller
	fi
fi
}
#---------- END select-mountpoint --------

export -f select-mounted select-share select-mountpoint

# ------------End functions---------------------

# -- Proceed with Main()

# -- Check Dependancies -----

# We need to have
# 1. cifs-utils/samba-client to allow the searching for, mounting and manipulation of cifs volumes
# 2. nmblookup and smbclient to snoop what volumes are shared on the SMB servers available
# 3. yad to give functional and usable dialog inputs

NOTINSTALLED_MSG=""						# Start with a blank message
#1.. Look for nmblookup

which nmblookup >>/dev/null 2>&1				# see if nmblookup is installed
if [ $? != "0" ]; then
	NOTINSTALLED_MSG=$NOTINSTALLED_MSG"nmblookup\n"		# indicate not installed	
fi

#2.. Look for smbclient

which smbclient >>/dev/null 2>&1				# see if smbclient is installed
if [ $? != "0" ]; then
       	NOTINSTALLED_MSG=$NOTINSTALLED_MSG"smbclient\n"		# indicate not installed		
fi

#3.. Look for nmap

which nmap >>/dev/null 2>&1					# see if nmap is installed
if [ $? != "0" ]; then
       	NOTINSTALLED_MSG=$NOTINSTALLED_MSG"nmap\n"		# indicate not installed		
fi


#4.. Look for yad

which yad >>/dev/null 2>&1					# see if yad is installed
if [ $? != "0" ]; then
	YADNOTINSTALLED_MSG="yad not found!\nInstall yad package\n Using\n\n 'sudo dnf install yad' (Fedora/RedHat)\n\n'sudo apt install yad' UBUNTU/Debian"

	zenity	--warning --no-wrap \
	--title="YAD Missing" \
	--text="$YADNOTINSTALLED_MSG" \

fi

if [ -n "$NOTINSTALLED_MSG" ]; then
	NOTINSTALLED_MSG=$NOTINSTALLED_MSG"not found!\n\nInstall cifs-utils and/or samba-client packages\n Using\n\n 'sudo dnf install samba-client nmap' (Fedora/RedHat)\n\n'sudo apt install cifs-utils smbclient nmap' UBUNTU/Debian"

	zenity	--error --no-wrap \
	--title="Missing Dependancies" \
	--text="$NOTINSTALLED_MSG" \

	exit							# exit and fail to run	
fi
# -- END Check Dependancies -----

#----- Read $1 and set the User and Group ID for the mount command
# Since we have to run this scipt using sudo we need the actual user UID. This is set by the execution script that called us
# The UID is passed as $arg1 i.e "./mntSMB $_ID" (see the mntSMB script) comes as 'uid=nnnn gid=nnnn'
# We need to use awk to add the commas into it to use as input to mount

_MY_PNAME=$0					# Get the name of THIS script (For resarting later on)
_UID=$(awk 'BEGIN{FS=" ";OFS=""} {print $1,",",$2 ;} '  <<<$1)
_PNAME=$2					# Get the actual name of the calling user/script
#
if [ -f $_PNAME.ini ]; then
	. $_PNAME.ini				# include the variables from the .ini file (Will orerwrite the above if $2.ini found)
fi
if [ -f $_PNAME.last ]; then						
	. $_PNAME.last				# load last sucessful mounted options if they exist (Overwrites .ini)
fi

select-mountpoint				# Define to root mount point

which yad >>/dev/null 2>&1			# see if yad is installed
if [ $? = "0" ]; then
	USEYAD=true 				# Use yad if we can
	export GDK_BACKEND=x11			# needed to make yad work correctly

	if [ -f $_PNAME.png ]; then
		YAD_ICON=$_PNAME.png 		# Use our Icon if we can ($0.png is an icon of a timecapsule
	       					# (Not required but just nice if we can)
	else
		YAD_ICON=gnome-fs-smb		# Default Icon in the YadDialogs from system
#		YAD_ICON=gnome-fs-ftp				# Default Icon in the YadDialogs from system
#		YAD_ICON=gnome-fs-nfs				# Default Icon in the YadDialogs from system
#		YAD_ICON=drive-harddisk				# Default Icon in the YadDialogs from system
#		YAD_ICON=network-server				# Default Icon in the YadDialogs from system

	fi
	export YAD_ICON
else 
	USEYAD=false						# yad is not installed, fall back to zenity
fi

# Start Processing

# look for subnets file
# if it doesnt't exist make one and add our subnet to it. ie. 192.168.1.0/24

_SUBNET=$(ip route | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}'/ |cut -d" " -s -f1 |grep -v 169.254 )

if [ -f $_PNAME.subnets ]; then
	_CURRENT_SUBNETS=$(cat $_PNAME.subnets |grep -v $_SUBNET ) # remove any current entry for this subnet
fi

echo -e "$_SUBNET\n$_CURRENT_SUBNETS" > $_PNAME.subnets 	# recreate .subnets Add this subnet at the top
chown --reference $_PNAME $_PNAME.subnets			# Give ownership to the caller

# Find the available Servers on this subnet
	show-progress "Initializing" "Finding Servers" \
	"nmblookup '*'"									# find out what SMB servers are available on this subn
		
	_SERVERS_FILE=""
	if [ -f $_PNAME.servers ]; then	# Get all from the existing .servers file
		_SERVERS_FILE=$(cat $_PNAME.servers)
	fi
	_SERVERS=$(echo -e "$SP_RTN\n$_SERVERS_FILE" \
		|grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' \
		|sort -u -t "," -k1,1
		)
									# Parse a list of ONLY the IP Addresses (grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}')
#Find the available Shares/Volumes on the Servers found above
	AVAILABLE_VOLS=""								# Clear the variables
	_SERVERS_AND_NAMES=""

	for S_IP in $(echo "$_SERVERS" | sed -e '/^$/d' )			# Find all available shares on all servers | sed -e '/^$/d' ignores blank lines
	do									# Parse a list of IP addresses and NETBIOS names (2 columns IP and NETBIOS name)
		show-progress "Initializing" "Finding Shares on $S_IP" \
		"smbclient -g -L $S_IP $SMBCLIENT_USER"

		_VOLS=$(echo "$SP_RTN" | grep -i disk |sort)				# Select only rows with "Disk" (In first column) (take First and second fields)
		_VOLS=$(sed 's/Disk/'"$S_IP"'/g' <<<$_VOLS)			# Replace the word "Disk" with the IP of the concerned server $S_IP
		AVAILABLE_VOLS=$(echo -e "$_VOLS\n$AVAILABLE_VOLS")			# Append available servers shares to this servers shares 

		S_NAME=$(nmblookup -A $S_IP |grep "<00>"|grep -vi '<group>'|cut -d" " -s -f1|tr -d '\t')	#1. Find the NETBIOS name
		_SERVERS_AND_NAMES=$(echo -e -n "$_SERVERS_AND_NAMES\n$S_IP $S_NAME")	#2. Append the IP address and NETBIOS name to the list in $_SERVERS_AND_NAMES
	done

#	First of all .. Present a total list of any mounted volumes and give options to umount if required
	M_PROCEED='no'
	while [ "$M_PROCEED" ]
	do
		select-mounted								# Present a list of currently mounted volumes
	done								# repeatedly until nothing is mounted or Proceed button selected
#	Then .. Present a total list of any shares available on the subnet for preliminary selection
	select-share									# Select a server and share from the selection list (Returns IP|NETBIOSNAME|SHARE)
		if [ -n "$SP_RTN" ]; then
			IFS="|" read  _IP _NETBIOSNAME _VOLUME tTail<<< "$SP_RTN"  # tTail picks up any spare seperators
		fi
# Get user input to confirm default or selected values
InputPending=true									# Haven't got valid user input yet
while $InputPending
do
		if $USEYAD ; then							# Use zad if we can (Maybe suggest to install later ..note to self.. TBD)
# Format the server list for YAD dropdown list
		CHECK_SRV=""								# Start with a blank list
		if [ -n "$_SERVERS_AND_NAMES" ]; then				# if we found any servers
			CHECK_SRV=$(echo "$_SERVERS_AND_NAMES" \
			| sed -e '/^$/d' \
			| grep -iwv $_IP \
			| awk ' { print $1, $2 } ' OFS=" - " \
			| paste -s -d"!" \
			) 		# select only and ALL lines except the last mounted Server IP
		fi
					# grep -iv ignores the last sucessful mounted server
					# the last mounted server. is added at the top of the list later
					# sed -e '/^$/d' \ removes any blank lines
					# Paste into one row delimited by '!' 
		if [ -n "$CHECK_SRV" ]; then
			CHECK_SRV="!$CHECK_SRV"		# if something found add a delimeter before it 
		fi

		set-netbiosname $_IP			# Get the NETBIOS name of the last used/selected server into _NETBIOSNAME
							# if it is offline dont include the pango markup set by set-netbiosname
		if ! $_LASTSERVERONLINE ; then
		_NETBIOSNAME="**OFFLINE**"  		# Server is offline
	fi

# finally make the drop down list (Remember to consider that we changed the ' ' for '-' when we parse the result below	
		SEL_AVAILABLE_SERVERS=$(echo $_IP" - "$_NETBIOSNAME$CHECK_SRV'!other' )
		# Add the last used server at the top, append "other" to allow input of a server not found above
		# Replace the one space seperator (' ') with ' - ' (Make it pretty) like the awk paste OFS above
#Format the Volumes list											
		CHECK_VOLS=$(echo "$AVAILABLE_VOLS" \
		| sed -e '/^$/d' \
		| grep -iw $_IP \
		| grep -iv "$_VOLUME" \
		| cut -d"|" -s -f2 \
		| paste -s -d"!" \
		)			# select only and ALL lines for the selected Server IP the second field (Sharename)
					# | sed -e '/^$/d' \ ignores any blank lines
					# grep -iv ignores the last sucessful mounted volume to avoid duplicates in the list
					# the last mounted vol. is added at the top of the list later
					# Paste into one row delimited by '!' i.e TimeCapsule!BigDisk
		if [ -n "$CHECK_VOLS" ]; then
			CHECK_VOLS="!$CHECK_VOLS"	# if something found add a delimeter before it 
		fi
		SEL_AVAILABLE_VOLS="$_VOLUME$CHECK_VOLS!other"			# Add the last used volume at the top and append "other" to allow input of a share not found above

# Get the input
		Voldetail=$(yad --form --width=700 --separator="," --center --on-top --skip-taskbar --align=right --text-align=center --buttons-layout=spread --borders=25 \
		       		--window-icon $YAD_ICON --image $YAD_ICON \
				--title="Server/Share details" \
				--text="\n<span><b><big><big>Enter the Server and Volume data</big>\n</big></b></span>\n" \
				--field="IP Address of SMB Server ":CBE "$SEL_AVAILABLE_SERVERS" \
				--field="Volume/Share to mount ":CBE "$SEL_AVAILABLE_VOLS" \
				--field="User " "$_USER" \
				--field="Password ":H "$_PASSWORD" \
				--field="\n<b>Select 'Ignore' to ignore any changes here and proceed to mount with default values\n \
				\nOtherwise select 'Mount' to accept any changes made here</b>\n":LBL \
				--field="":LBL \
				--button="Save as Default":2 --button="Ignore - Use Defaults":1 --button="Mount - This Volume":0 \
			 )
		else  									# else revert to zenity

		Voldetail=$(zenity --forms --width=500 --title="SMB Server details" --separator=","  \
				--text="\nSelect Cancel or Timeout in $YADTIMEOUTDELAY Seconds will ignore any changes here and proceed to mount with default values\n" \
				--add-entry="IP Address of SMB Server - "$_IP \
				--add-entry="Volume/Share to mount - "$_VOLUME \
				--add-entry="User - "$_USER \
				--add-password="Password - "$_PASSWORD \
				--default-cancel \
				--ok-label="Mount - This Volume" \
				--cancel-label="Ignore - Use Defaults" \
				--timeout=$YADTIMEOUTDELAY \
			)
		fi									# end "If yad is istalled"	
# Check exit code and collect new variables from Vol detail if given
		case $? in
			0) ;;						# OK so collect input else leave all vars asis
			70) InputPending=false ; exit ;;		# 70=Timed out no change to $default set variables *drop out of the while loop
			1|251)InputPending=false ; break ;;		# 1 251 User pressed Cancel use default set of variables
			2) FORCESAVEINI=true ;;				# User Selected "Save Defaults" Flag to force save defaults
			-1|252|*)  exit -1 ;;				# Some error occurred (Catchall)
		esac
# got input.. validate it

	IFS="," read  t_IP t_VOLUME t_USER t_PASSWORD tTail<<< "$Voldetail" # tTail picks up any spare seperators

	t_IP="$t_IP "					# Add a trailing space for the 'cut' commmand below
	t_IP=$(echo "$t_IP" \
		|cut -d" " -s -f1 \
		|tr -d '[:space:]')			# Get the IP address ONLY from the input
	
	ENTRYerr=""					# Collect the blank field names 
	if [ -z "$t_IP" ]; then ENTRYerr="$ENTRYerr IP,"
	fi
	if [ -z "$t_VOLUME" ]; then ENTRYerr="$ENTRYerr Volume,"
	fi
	if [ -z "$t_USER" ]; then ENTRYerr="$ENTRYerr User ID,"
	fi
	if [ -z "$t_PASSWORD" ]; then ENTRYerr="$ENTRYerr Password,"
	fi

	if [ -z "$ENTRYerr" ]; then				# no fields are blank

		if [[ "$_IP" != "$t_IP" ]] || \
		[[ "$_VOLUME" != "$t_VOLUME" ]] || \
		[[ "$_USER" != "$t_USER" ]] || \
		[[ "$_PASSWORD" != "$t_PASSWORD" ]] || \
	       	[[ $FORCESAVEINI ]]\
		; then									# If anything changed or user selected save defaults button

			if $USEYAD ; then		# Use yad if we can
				SP_RTN=$(yad --form  --separator="," --center --on-top --skip-taskbar --align=right --text-align=center --buttons-layout=spread --borders=25 \
					--image=document-save \
					--title="Save $_PNAME.ini" \
					--text="\n<span><b><big><big>Your Server/Share data Input</big></big></b></span>\n" \
					--field="IP Address of SMB Server ":RO "$t_IP" \
					--field="Volume/Share to mount ":RO "$t_VOLUME" \
					--field="User ":RO "$t_USER" \
					--field="Password ":RO "$t_PASSWORD" \
					--field="\n\n<span><b><big>Do you want to save these values as defaults?</big></b></span>\n":LBL \
					--field="":LBL \
					--button="Dont save":1 --button="Save as Default":0 \
					--timeout=$YADTIMEOUTDELAY --timeout-indicator=left
				)
			else
				SP_RTN=$(zenity --question --no-wrap \
					--title="Save $_PNAME.ini" \
					--text="\n Your Server/Share data Input \n \
						IP Address of SMB Server - "$t_IP"    \n \
						Volume/Share to mount - "$t_VOLUME"    \n \
						User ID - "$t_USER"    \n \
						Password - "$t_PASSWORD"    \n \	
						\nDo you want to save these values as defaults?    " \
					--default-cancel \
					--ok-label="Save as Default" \
					--cancel-label="Dont save" \
					--timeout=$TIMEOUTDELAY
					)
			fi					# endif USEYAD

			case $? in					# $? is the return code from the zenity/yad call
				0)DOsave_vars="Y" ;;			# zenity/yad returns 0 for OK so save the .ini file
				1|70) ;;				# zenity/yad returns 1 for Cancel (Timeout or Close if --default-cancel is set)
				-1|252|255) ;;				# Just here to consider any other exit return codes (see zenity and yad documentation)
			esac

		fi						# end check for any changes

		IFS="," read  _IP _VOLUME _USER _PASSWORD tTail<<< "$Voldetail"  # tTail picks up any spare seperators

		_IP="$_IP "					# Add a trailing space for the 'cut' commmand below
		_IP=$(echo "$_IP" \
		|cut -d" " -s -f1 \
		|tr -d '[:space:]')					# Get the IP address only from the input (remember we exchanged the ' ' for '-' when we formatted the list
	
		InputPending=false					# got the input that we wanted, None of the fields are blank, moved them into the variables and continue

		if [[ "$DOsave_vars" = "Y" ]]; then			# save the input as default for next time
			save-vars "ini"
		fi
	else								# One or more of the vars is blank
		zenity	--error --no-wrap \
			--title="Server data input error" \
			--text="Input error!!...  \n\n $ENTRYerr cannot be blank \n\nTry again  " \
			--timeout=$TIMEOUTDELAY
	fi								# Check input for errors

done

MOUNT_POINT="$MOUNT_POINT_ROOT/$_VOLUME"				# switch the mountpoint name if required
									# Where we are going to mount... no need to create the directory we, will do it as we go
_PATH="//$_IP/$_VOLUME"					# What we are trying to mount


#Start Processing mount
#Check if it (Or something else) is already mounted at $MOUNT_POINT
IS_MOUNTED=`mount 2> /dev/null | grep -w "$MOUNT_POINT" | cut -d' ' -f3`

if [[ "$IS_MOUNTED" ]] ; then

		zenity 	--question --no-wrap \
			--title="Volume Already in use" \
			--text="$_PATH or something else is currently mounted at $MOUNT_POINT   \n\nDo you want to unmount and stop using it?" \
			--default-cancel \
			--ok-label="Unmount" \
			--cancel-label="Continue Using" \
			--timeout=$TIMEOUTDELAY

		case $? in					# $? is the return code from the zenity call
    			0)ProceedToUnmount="Y"	;;		# zenity returns 0 for OK 
    			1|70)ProceedToUnmount="N"	;;	# zenity returns 1 for Cancel (Timeout or Close if --default-cancel is set)
			-1|252|255)ProceedToUnmount="N" ;;	# Just here to consider any other exit return codes (see zenity documentation)
		esac

		# $? (zenity exit code) parsed into ProceedToUnmount above in the case statement.
		# Switched 0 (OK) to "Y" and 1 (Cancel) to "N" (Just for code clarity.) 
	
	if [[ $ProceedToUnmount =~ [Yy] ]] ; then

# ---------- umount and trap any error message

		unmount "$MOUNT_POINT"							# Attempt to unmount volume

		if ! $UNMOUNT_ERR  ; then
			if [ -f "$_PNAME.last" ]; then
				rm -f "$_PNAME.last"					# Unmounted so delete last mounted vars temp file (restart next time with .ini file)
			fi
		else									# unmount failed
			exit 1
		fi 									# if umount $MOUNT_POINT
		else									# decision given to keep what is currently mounted ($ProceedToUnmount == Y)

		zenity	--info --no-wrap \
			--title="Retain mounted Volume" \
			--text="Continue to use previously mounted $MOUNT_POINT  " \
			--timeout=$TIMEOUTDELAY
	fi 										#$ProceedToUnmount decision
	
	exit 0		#Sucess

else		# Not yet mounted so Proceed to attempt mounting

		if [ "$MOUNT_POINT" != "$MOUNT_POINT_ROOT" ]; then			# Dont try to create the mount root if mount point is not set correcly

			if [ ! -d "$MOUNT_POINT" ]; then
				mkdir "$MOUNT_POINT"	# make the mountpoint directory if required.
				chown --reference $_PNAME $MOUNT_POINT	# Give ownership to the caller
			fi
		fi
# ---------- mount and trap any error message
		MNT_CMD="mount -t cifs '$_PATH' '$MOUNT_POINT' -o $_UID,user=$_USER,pass=$_PASSWORD,rw,file_mode=0777,dir_mode=0777,x-gvfs-show"
echo ..
echo $MNT_CMD						# Show the user what we are doing *CLI
echo ..
		show-progress "Mounting" "Attempting to mount $_PATH" "$MNT_CMD"
		

		ERR=$(echo "$SP_RTN")							# Read any error message

# --- end mount (any error message is in $ERR

		if [ -z "$ERR" ] ; then
			zenity	--info --no-wrap \
				--title="Volume is Mounted" \
				--text="Volume $_PATH is Mounted  \n\nProceed to use it at $MOUNT_POINT  \n\n.... Success!!" \
				--timeout=$TIMEOUTDELAY 

		save-vars "last" 							# save the as the last Volume used

		else									# if mount fails #Clean UP

			if [ "$MOUNT_POINT" != "$MOUNT_POINT_ROOT" ]; then		# Dont remove the mount root is mount point is not set correcly
				rmdir "$MOUNT_POINT"					# Happened during testing DUHHH
			fi

			zenity	--error --no-wrap \
				--title="Volume is NOT Mounted" \
				--text="Something went wrong!!...  \n\n $ERR \n\n Failed to mount SMB Volume $_PATH at $MOUNT_POINT try again  " \

			exit 1
		fi		# end if mount -t cifs $_PATH

fi		# IS_MOUNTED
exit 0
