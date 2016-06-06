#!/bin/bash

finish() {
	echodelim "Done!"
	ARCHIVE="/root/$(mktemp -q -u debuginfo-XXXXXXXX.zip)"

	if [[ $inclDialplan = true ]]; then
		vecho "Finishing up, zipping $FOLDER, /var/log and /etc/asterisk to $ARCHIVE"
		zip -qr $ARCHIVE /etc/asterisk/ /var/log $FOLDER/
	else
		vecho "Finishing up, zipping $FOLDER and /var/log to $ARCHIVE"
		zip -qr $ARCHIVE /var/log $FOLDER/
	fi

	vecho "Deleting $FOLDER"
	rm -rf $FOLDER/
}

rpmverification=true
javadump=false
verbose=true
quiet=false
inclDialplan=true

hw-info(){
	echodelim "Hardware"
	vecho "Identifying appliance..."
	appliance_identify.sh 2>&1>$APPLIANCE/appliance_identify.txt
	appliance_info.sh check_cards 2>&1>$APPLIANCE/appliance_cards.txt

	vecho "Checking devices"

	# ToDo Merge files
	lspci 2>&1>$APPLIANCE/pci.txt
	lspci -t 2>&1>>$APPLIANCE/pci.txt

	# ToDo Merge files
	lsusb 2>&1>$APPLIANCE/usb.txt

	vecho "Checking free space"
	lsblk -oNAME,FSTYPE,MOUNTPOINT,TYPE,SIZE 2>&1>$APPLIANCE/lsblk.txt
	df -h 2>&1>$APPLIANCE/df.txt

}

os-details(){
	echodelim "OS"
	vecho Dumping processlist...
	uptime 2>&1>$OS/proc.txt
	ps aux 2>&1>>$OS/proc.txt
}

nw-details(){
	echodelim "Network"
	vecho "Gathering networking informations..."
	lsof -i 2>&1>$NET/lsof-i.txt
	netstat -tulpen 2>&1>$NET/netstat-tulpen.txt
	netstat -an 2>&1>$NET/netstat-an.txt
	ifconfig 2>&1>$NET/ifconfig.txt
	zip -qr $NET/nw-scripts.zip /etc/sysconfig/network-scripts/
	iptables-save 2>&1>$NET/iptables-current.txt
	route -n 2>&1>$NET/routes.txt

	vecho "Checking STARFACE HQ avaibility..."
	curl -k https://license.starface.de 2>&1> $NET/https-license.txt
	curl http://starface.de 2>&1> $NET/https-license.txt
}

ast-details(){
	echodelim "Asterisk"
	vecho "Enum Asterisk modules"
	asterisk -rx 'module show' 2>&1>$AST/modules.txt

	vecho "Enumerate sip peers-, registry- and channelstate"
	asterisk -rx 'sip show peers' 2>&1>$AST/peers.txt
	asterisk -rx 'sip show registry' 2>&1>$AST/registry.txt
	asterisk -rx 'sip show channels' 2>&1>$AST/sip_channels.txt

  vecho "Retrieving core information"
	asterisk -rx 'core show channels' 2>&1>$AST/core_channels.txt
	asterisk -rx 'core show threads' 2>&1>$AST/core_threads.txt
	asterisk -rx 'core show taskprocessors' 2>&1>$AST/core_taskprocessors.txt

	vecho "Retrieving ISDN configurations and alarms.."
	asterisk -rx 'pri show spans' 2>&1>$AST/pri_spans.txt
	asterisk -rx 'srx show layers' 2>&1>$AST/srx_layers.txt
}

java-details(){
	echodelim "Java"
	_javaPID="$(ps aux | awk '/[j]ava -Djavax/ { print $2 }')"
	if [ ! -z "$_javaPID" ]; then
		if [[ "$javadump" = true ]]; then
			vecho "Whats in the jStack?"
			jstack -l $_javaPID 2>&1>$FOLDER/jstack.txt
			vecho "Creating Javadump"
			jmap -dump:live,format=b,file=$FOLDER/heap.bin $(jps | grep 'Bootstrap' | awk '{ print $1}')
		fi
		vecho "Getting heap summary"
		jmap -heap $_javaPID 2>&1>$FOLDER/heap.txt
	else
		vecho "No Java PID found. Skipping..."
	fi
}

rpm-details(){
	echodelim "RPM"
	echo Enumerating RPMs
	rpm -qa 2>&1>$FOLDER/rpm_qa.txt
	if [[ "$rpmverification" = true ]]; then
		echo Verifying RPMs, this will take some time. Skip with CTRL + C
		rpm -Va 2>&1>$FOLDER/rpm_va.txt
	fi
}

# Stdout the start of a new function
echodelim() {
	if [[ $quiet = false ]]; then
		echo "========= " $1 " ========="
	fi
}

# Verbose output on stdout
vecho() {
	if [[ $verbose = true ]] && [[ $quiet = false ]]; then
		echo $1
	fi
}

main() {
	FOLDER="$(mktemp -q -d)"
	AST="$FOLDER/asterisk"
	APPLIANCE="$FOLDER/appliance"
	OS="$APPLIANCE/os"
	NET="$OS/net"

	mkdir $AST $APPLIANCE $OS $NET

	# We have created folders,
	# don't exit the script without cleaning up.
	trap finish EXIT

	hw-info
	os-details
	nw-details
	ast-details
	java-details
	rpm-details
}

printHelp() {
	echo "debug.sh [-v|q] [-j] [-r] [-a] [-h]"
	echo "-v: Verbose output (inner function calls)"
	echo "-q: Minimum output (quiet)"
	echo "-j: Create Java memorydump"
	echo "-r: Dont verify RPMs, may save a lot of time if unnecessary"
	echo "-a: Dont include /etc/asterisk"
	echo "-fs: Force fsck for the root partition on the next boot"
	echo "-h: Help (this screen)"
}

for i in "$@"
do
	case $i in
	    -v)
	    verbose=true
	    ;;
	    -q)
	    quiet=true
	    ;;
	    -j)
	    javadump=true
	    ;;
	    -r)
	    rpmverification=false
	    ;;
			-a)
			inclDialplan=false
			;;
			-h)
			printHelp
			exit
			;;
			-fs)
			touch /forcefsck
			vecho "Forcing fsck for / on next boot"
			;;
	    *)
	    ;;
	esac
done

main
