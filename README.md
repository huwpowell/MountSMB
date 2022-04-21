# MountSMB
# Mount SAMBA/SMB/CIFS volumes Linux

# Purpose: 
Check if there is an SMB Server in your network and mount shares from it
If a share is already mounted prompt and Unmount it if it is no longer required.
The mount point is created and destroyed after use 
(to prevent filling the mount directory if the device is not mounted)

Runs on all GNU/Linux distros (install cifs-utils) (maybe required. Try without first HHP 20200513)
UNUNTU needs cifs-utils and smb-client (apt install cifs-utils smb-client)

Authors: Huw Hamer Powell <huw@huwpowell.com> and Daniel Graziotinand

1) Install cifs-utils (sudo dnf install cifs-utils) (probably not required in FC32 but try without first) HHP 20200509
2)If you want to use the full functionality of nice dialog boxes install yad . otherwise we default to zenity *not so nice but it works)
3) Change the first four variables according to your configuration. Or maintain a .ini file with the four variables. Can be created by the script if neccessary
4) Run this program at login or from your $HOME  when your network is ready
a mntSMB.desktop file is provided (Copy to $HOME/Desktop)
(need to use sudo.. so run the skeleton script mntSMB which will call te script (mntSMB.sh) using sudo... Or from the CLI or Gnome Desktop

# Ensure that you are an valid sudoer and add this line to /etc/sudoers
# %wheel	ALL=(ALL)	NOPASSWD: ALL
# %sudoers	ALL=(ALL)	NOPASSWD: ALL
#W hichever works for you. This will prevent having to enter the sudo password each time it is run

Also, run it on logoff to umount any mounted shares (Will remove the mount point directory).
It does not matter if you don't , Just cleaner if you do :)

# ----------------------------------------------
Version 3, enhanced for Ubuntu 13.X+, Fedora 35+, and similar distros.
Runs on all GNU/Linux distros (install cifs-utils)

Version 4, Crafted a mod for FC32+ and added some visible interactions using zenity/yad ..Else silent) HHP 20210509
Added the use of zenity/yad to produce dialog in Gnome
Added proper mount options to cope with SMB Vers=1.0 and x display icons for mounted drives
# ----------------------------------------------

This program is free software. It comes without any warranty, to
the extent permitted by applicable law. You can redistribute it
and/or modify it under the terms of the "Do What The Fuck You Want To"
Public License, Version 2, December 2004, as published by Sam Hocevar.
See http://sam.zoy.org/wtfpl/COPYING for more details.
or https://en.wikipedia.org/wiki/WTFPL
