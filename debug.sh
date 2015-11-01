#!/bin/bash

finish() {
	echodelim "Done!"
	ARCHIVE="/root/$(mktemp -q -u debuginfo-XXXXXXXX.zip)"

	vecho "Finishing up, zipping  $FOLDER to $ARCHIVE"
  zip -qr $ARCHIVE /etc/asterisk/ /var/log $FOLDER/
	vecho "Deleting $FOLDER"
	rm -rf $FOLDER/
}

# ToDo:
# These ought to be parameters. Just set the defaults here.
rpmverification=true
javadump=true
verbose=true
quiet=false

hw-info(){
	echodelim "Hardware"
	vecho "Identifying appliance..."
	appliance_identify.sh 2>&1>$APPLIANCE/appliance_identify.txt
	appliance_info.sh check_cards 2>&1>$APPLIANCE/appliance_cards.txt

	vecho "Checking devices"
	# ToDo Merge files
	lspci 2>&1>$APPLIANCE/pci.txt
	lspci 2>&1>>$APPLIANCE/pci.txt
	# ToDo Merge files
	lsusb 2>&1>$APPLIANCE/usb.txt
	lsusb 2>&1>>$APPLIANCE/usb.txt
	df -h 2>&1>$APPLIANCE/df.txt
	lsblk -oNAME,FSTYPE,MOUNTPOINT,TYPE,SIZE 2>&1>$APPLIANCE/lsblk.txt
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
	asterisk -rx 'core show channels' 2>&1>$AST/core_channels.txt

	vecho "Retrieving ISDN configurations and alarms.."
	asterisk -rx 'pri show spans' 2>&1>$AST/pri_spans.txt
	asterisk -rx 'srx show layers' 2>&1>$AST/srx_layers.txt
}

java-details(){
	echodelim "Java"
	if [[ "$javadump" = true ]]; then
		jmap -dump:live,format=b,file=$FOLDER/heap.bin $(jps | grep 'Bootstrap' | awk '{ print $1}')
	fi
	vecho Getting heap summary
	jmap -heap $(ps aux | awk '/[j]ava -Djavax/ { print $2 }') 2>&1>$FOLDER/heap.txt

	vecho Whats in the Stack?
	jstack -Fl $(ps aux | awk '/[j]ava -Djavax/ { print $2 }') 2>&1>$FOLDER/jstack.txt
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

main
