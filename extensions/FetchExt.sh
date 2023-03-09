#!/bin/sh
# Script to download an extension and its dependencies written by Richard A. Rost July 7,2019
# Special thanks go out to GNUser for his time and effort spent testing and providing
# helpful suggestions and feedback.
#
# The script downloads to the directory you are in when you start the script.
# There are no Tinycore specific commands, variables, or directories required so it should work
# on any Linux box.
# Some error checking is done, though it might not be as thorough as it should be.
# The script downloads the  .tcz,  .tcz.dep,  and  .tcz.md5.txt  files for each extension.
# MD5 is verified.
# File ownership is changed to tc:staff.
# A running timestamped log is kept in  ./Log.txt
# ./Dependency.list  is a sorted  .tree  file with duplicates removed of the last extension downloaded.
#
# Usage:
#
#	FetchExt.sh ExtensionName ExtensionName ExtensionName
#						Fetches the extension(s) and its dependencies. ExtensionName is
#						case sensitive. Including  .tcz  is optional.
#
#	FetchExt.sh info	Fetches the list of available extensions in the listed repository
#						and displays it using  less  in a new terminal.
#
#
# --------------------------------- Change Log --------------------------------- #
# Version None Jul 7,2019
# Initial release.
# Version 0.2 Apr 3.2022
# Added version numbers.
# You can now specify multiple extensions in one command.
# It no longer matters whether or not you include .tcz in the extension name.
# When multiple kernel versions of an extension exist, they all get fetched.
#    The operating system will use the correct extension and the user does
#    not need to spend time typing incorrect version strings.
# Changed  #!/bin/bash  to  #!/bin/sh. Not sure why it was bash, hope nothing breaks.
# Major cleanup. Some code moved into functions. Logic changes. More comments added.
# Replaced excess screen output with dots to indicate progress. ./Log.txt has history.
#
# Version 0.3 Apr 7.2022
# Added UserID to User variables. Thank you GNUser
# Added sudo handling. Thank you GNUser
# Created separate function to change file ownership attributes. Thank you GNUser
# Changed == and != to -eq and -ne for integer comparisions. Thank you GNUser
# Added Usage message.
#
# Version 0.4 Apr 8.2022
# Changed echo -e to multiple echo commands for systems that don't support -e. Thank you GNUser
#
# Version 0.5 Apr 9.2022
# Added some messages at end of script to inform user of status.
# Added UpdateLog() to write to log file and set variables when DATE or Error:
#    messages get written.
#
# ------------------------------------------------------------------------------ #
#

# ------------------------------ Define Variables ------------------------------ #
# User variables ***************************************************************

# Website to download from.
ADDR="http://repo.tinycorelinux.net"

# Tinycore version. Versions always end in  .x , there are no minor version digits.
TC="13.x"

# Processor architecture, current options are  x86  x86_64  armv6  armv7  armv7l  aarch64
ARCH="x86"

# User that should own the downloaded files. UID of the default tc user is 1001. 
# If you use the "user=somebody" boot code you may prefer UserID 1000 (but 1001 would still work).
UserID=1000

# End of user variables ********************************************************


# Program variables start here. Do not touch. **********************************

# This is the repository the extensions get downloaded from.
URL="$ADDR/$TC/$ARCH/tcz/"

# This is a running log of all downloads
Log="Log.txt"

# REGEX for finding kernel version strings. Set by  BuildVersionsList()
# Used by  BuildVersionsList()  and  BuildDependencyList().
KString=""

# List of all extensions in repository. Used to create a list of available
# kernel versions.
InfoFile="info.lst"

# File containing list of available kernel versions in the current repository.
VersionsList="Versions.list"

# Maximum age of info.lst in seconds before it is considered to be stale and
# needs to be redownloaded.
MaxAge=3600

# Name of each extension to be processed.
ExtName=""

# Processed copy of extension.tcz.tree. It has been sorted and duplicate entries
# are removed. Kernel module entries have been updated to include all kernel
# versions available from the current repository.
DependencyList="Dependency.list"

# This is the user ID you are currently running as.
WhoIam=`id -u`

# Tells ChangeOwnership() whether it needs sudo for chown command.
UseSudo="No"

# Gets set if user wants to view $InfoFile or $Log
ViewFile=""

# Provides feedback to the user when the script runs to completion. OK or Error.
ExitMessage="OK"

# Timestamp of extension tree currently being processed.
TimeStamp=""

# Timestamp of when the first error of this session shows up in Log.
ErrorTime=""

# -------------------------------- End Variables ------------------------------- #


# ------------------------------ Define Functions ------------------------------ #

BuildDependencyList()
{
# This uses the  .tree  file and the  $VersionsList  file to build
# a complete dependency list of the extension being processed.

TmpFile="Extension.tmp"
rm -f "$DependencyList"

# awk '$1=$1' removes all whitespace, sort -u sorts alphabetically and removes duplicate entries.
awk '$1=$1' $ExtName.tree | sort -u > $TmpFile
# Replace  -kernelversion.tcz  with  -KERNEL.tcz
sed -i -E 's|'$KString'|-KERNEL.tcz|g' $TmpFile

for E in `cat $TmpFile`
do
	case $E in
		*-KERNEL.tcz) # Kernel module extensions are handled here.
			# Strip off -KERNEL.tcz from end of extension name.
			E=${E%\-KERNEL.tcz}
			for V in `cat $VersionsList`
			do
				# Create an entry for each kernel version listed in this repository.
				echo $E$V >> $DependencyList
			done
		;;
		*) # Regular extensions are handled here.
			echo $E >> $DependencyList
		;;
	esac
done

rm -f "$TmpFile"
rm -f "$ExtName.tree"
}


BuildVersionsList()
{
# Scans the info.lst file to create a list of available kernel versions.
# for this repository.

case $ARCH in
	# REGEX notes:
	# First - is escaped so it's not treated as an option by grep.
	# Wildcard needs to be preceded with a period like this:  .*

	x86*) # REGEX for finding Intel kernel strings.
		KString="\-[0-9]+.[0-9]+.[0-9]+-tinycore.*.tcz"
	;;
	armv*|aarch*) # REGEX for finding ARM kernel strings.
		KString="\-[0-9]+.[0-9]+.[0-9]+-piCore.*.tcz"
	;;
	*) echo "Invalid architecture specified."
	   Cleanup 1
	;;
esac

# Searches for -kernelversion.tcz and prints only the part of a line that matches -kernelversion.tcz.
grep -oE $KString $InfoFile > Versions.tmp
# awk '$1=$1' removes all whitespace, sort -u sorts alphabetically and removes duplicate entries.
awk '$1=$1' Versions.tmp | sort -u > $VersionsList

rm -f Versions.tmp
}


ChangeOwnership()
{
# Change User:Group attributes of a file.
#
# $1  File to change.
# $2  Optional, user ID to use in place of the default.
#
# Numeric values used because foreign Linux box won't have tc:staff.

# Default ID to use.
UseID=$UserID
# Test if an alternate ID was passed in.
[ -n "$2" ] && UseID=$2

if [ "$UseSudo" = "Yes" ]
then
	sudo chown $UseID:50 "$1"
else
	chown $UseID:50 "$1"
fi
}


CheckSudo()
{
# Make sure we can run without user interaction.
if [ `id -u` -ne 0 ]
then
	# User is not root.
	UseSudo="Yes"
	sudo -nv > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		# sudo either requires a password or does not exist.
		echo "You must run $0 as root on this system."
		# This is the only time you should exit directly.
		# Use Cleanup() everywhere else.
		exit 1
	fi
fi

# Make sure the current user can modify/access these files if they exist.
[ -f "$InfoFile" ] && ChangeOwnership "$InfoFile" "$WhoIam"
[ -f "$Log" ] && ChangeOwnership "$Log" "$WhoIam"
[ -f "$DependencyList" ] && ChangeOwnership "$DependencyList" "$WhoIam"
}


Cleanup()
{
# Every exit point except CheckSudo() should pass through here.
# Make sure the end user ($UserID) can modify/access these files if they exist.
[ -f "$InfoFile" ] && ChangeOwnership "$InfoFile"
[ -f "$Log" ] && ChangeOwnership "$Log"
[ -f "$DependencyList" ] && ChangeOwnership "$DependencyList"

# Remove unneeded files.
rm -f "$VersionsList"

exit $1
}


FetchTreeFile()
{
# Remove previous copy of file if it exists so that  wget  doesn't create numbered backups.
rm -f "$ExtName.tree"

Tree="$URL$ExtName.tree"
wget -q "$Tree" > /dev/null 2>&1
if [ $? -ne 0 ]
then
	wget -q --spider "$URL$ExtName" > /dev/null 2>&1	# No .tcz.tree found, check for .tcz
	if [ $? -eq 0 ]
	then	# Extension exists but has no dependencies so create a tree file.
		echo "$ExtName" > "$ExtName.tree"
	else
		# Extension does not exist, log an error.
		# Update the log file with newline, timestamp, URL, extension name being processed.
		UpdateLog ""
		UpdateLog "DATE"
		UpdateLog "$URL"
		UpdateLog "  Error:  Processing $ExtName failed."
		# Setting this to an empty string informs the caller an error occurred.
		ExtName=""
	fi
fi
}


RefreshInfoList()
{
# This downloads a fresh copy of info.lst if any of the following are true:
# 1. The file is not in the current directory.
# 2. The file is older than 1 hour (3600 seconds).
# 3. This script has been modified and is newer than info.lst.

# Make sure  info.lst  exists.
if [ -f "$InfoFile" ]
then
	# Compute number of seconds since this script modified (edited).
	ThisScript=$(( $(date +%s) - $(date -r "$0"  +%s) ))
	# Compute number of seconds since info.list modified (downloaded).
	Age=$(( $(date +%s) - $(date -r "$InfoFile"  +%s) ))
	if [ $Age -lt $ThisScript ]
	then
		# info.lst is more recent than this script, no need to update.
		if [ $Age -lt $MaxAge ]
		then
			# File is recent enough to use.
			return
		fi
	fi
	# File is too old, delete it.
	rm -f "$InfoFile"
fi
# Fetch a fresh copy of the file.
wget -q "$URL$InfoFile"
if [ $? -ne 0 ]
then
	echo "Download failed for: $URL$InfoFile"
	Cleanup 1
fi
}


UpdateLog()
{
Message="$1"

case "$Message" in
	"  Error:"*)
			if [ "$ErrorTime" = "" ]
			then
				# These get set the first time an Error: message gets sent.
				# They get used at the end of the script prior to exiting.
				ErrorTime="$TimeStamp"
				ExitMessage="One or more errors occurred. See $Log after timestamp:"
			fi
	;;

	"DATE")
			TimeStamp="`date`"
			Message="$TimeStamp"
	;;
esac

echo "$Message" >> $Log

}


Usage()
{

echo " Usage:

	$0 ExtensionName ExtensionName ExtensionName
				Fetches the extension(s) and its dependencies.
				ExtensionName is case sensitive.
				Including  .tcz  is optional.

	$0 info	Fetches the list of available extensions in the
				listed repository and displays it using less in
				a new terminal.

	$0 Log	Displays the Log.txt file (if it exists) using less
				in a new terminal.

	Please see the User variables section of this script for
	setting the version and architecture you will download for."

Cleanup 1
}

# -------------------------------- End Functions ------------------------------- #


# ----------------------------- Program starts here ---------------------------- #

# User failed to request an extension, info or Log.
[ $# -eq 0 ] && Usage

# See if user is requesting -h or --help, or wants to view info or Log.
case "$1" in
	-*) Usage;;
	info) ViewFile="$InfoFile";;
	Log) ViewFile="$Log";;
esac

# Make sure we don't need passwords for sudo.
CheckSudo

# See if we need a newer copy of info.lst.
RefreshInfoList

# First see if the user wants to look through $InfoFile or $Log.
# Make sure the string is not zero length.
if [ -n "$ViewFile" ]
then
	# Make sure the file exists.
	if [ -f "$ViewFile" ]
	then	# Display the $ViewFile in a terminal using the  less  command.
		xterm +tr +sb -T "$ViewFile" -e less "$ViewFile" &
		Cleanup 0
	else
		echo "$ViewFile not found."
		Cleanup 1
	fi
fi

# Create list of available kernel versions in the current repository.
BuildVersionsList

# Process extensions requested one at a time.
for ExtName in $@
do
	# Sanitize ExtName so we can accept extension or extension.tcz for input.
	# Inside the braces removes .tcz if it exists. The .tcz at the end appends .tcz.
	ExtName="${ExtName%.tcz}.tcz"

	FetchTreeFile
	# If an error occurred, we continue by skipping this extension.
	if [ -z "$ExtName" ]
	then
		continue
	fi

	# Process the  .tree  file and the  $VersionsList  file to build
	# a complete dependency list.
	BuildDependencyList

	# Update the log file with newline, timestamp, URL, extension name being processed.
	UpdateLog ""
	UpdateLog "DATE"
	UpdateLog "$URL"
	UpdateLog "Processing $ExtName"

	# Download the extension and all of its dependencies.
	for Entry in `cat $DependencyList`
	do
		# Visual feedback so user knows something is happening.
		echo -n "."

		# See if extension already exists.
		if [ -f "$Entry" ]
		then
			UpdateLog "$Entry already downloaded."
			continue
		fi

		# Fetch extension.
		wget -q "$URL$Entry" > /dev/null 2>&1
		if [ $? -ne 0 ]
		then
			UpdateLog "  Error:  $Entry download failed."
		else
			UpdateLog "$Entry downloaded."
			ChangeOwnership "$Entry"
		fi

		# Fetch dependency file if one exists.
		wget -q "$URL$Entry.dep" > /dev/null 2>&1
		if [ $? -eq 0 ]
		then
			UpdateLog "$Entry.dep downloaded."
			ChangeOwnership "$Entry.dep"
		fi

		# Fetch MD5.
		wget -q "$URL$Entry.md5.txt" > /dev/null 2>&1
		if [ $? -ne 0 ]
		then
			UpdateLog "  Error:  $Entry.md5.txt download failed."
			# No point in verifying the MD5.
			continue
		else
			UpdateLog "$Entry.md5.txt downloaded."
			ChangeOwnership "$Entry.md5.txt"
		fi

		# Verify MD5.
		md5sum -c "$Entry.md5.txt" > /dev/null 2>&1
		if [ $? -ne 0 ]
		then
			UpdateLog "  Error:  $Entry md5 checksum failed."
		fi

	done

done

echo "."

# ExitMessage contains either OK or an error message. If it contains
# an error message, ErrorTime will be set to the time of the first error.
echo "$ExitMessage"
[ -n "$ErrorTime" ] && echo "$ErrorTime"
echo

Cleanup 0
