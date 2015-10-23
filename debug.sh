#!/bin/bash

finish() {
	ARCHIVE="/root/$(mktemp -q -u debuginfo-XXXXXXXX.zip)"
	echo Finishing up, zipping $FOLDER to $ARCHIVE
	
    zip -r $ARCHIVE "$FOLDER" "/etc/asterisk/" "/var/log"
	rm -rf $FOLDER/
}

FOLDER="$(mktemp -q -d)"
AST="$FOLDER/asterisk"
APPLIANCE="$FOLDER/appliance"
OS="$APPLIANCE/os"
NET="$OS/net"

trap finish EXIT

mkdir $AST $APPLIANCE $OS $NET

echo Identifying appliance
appliance_identify.sh >$APPLIANCE/appliance_identify.txt
appliance_info.sh check_cards >$APPLIANCE/appliance_cards.txt

echo Dumping processes
uptime > $OS/proc.txt
ps aux >> $OS/proc.txt

echo Networking informations
lsof -i > $NET/lsof-i.txt
netstat -tulpen > $NET/netstat-tulpen.txt
netstat -an > $NET/netstat-an.txt
ifconfig > $NET/ifconfig.txt
zip -r $NET/nw-scripts.zip /etc/sysconfig/network-scripts/ >/dev/null
iptables-save >$NET/iptables-current.txt

echo Checking SF avaibility
curl -k https://license.starface.de 2>&1> >$NET/https-license.txt
curl -k http://starface.de 2>&1> >$NET/https-license.txt

echo Poking Asterisk
asterisk -rx 'module show' > $AST/modules.txt
asterisk -rx 'sip show peers' > $AST/peers.txt
asterisk -rx 'sip show registry' > $AST/registry.txt
asterisk -rx 'sip show channels' > $AST/sip_channels.txt
asterisk -rx 'core show channels' > $AST/core_channels.txt

echo Poking Java
jmap -dump:live,format=b,file=$FOLDER/heap.bin $(jps | grep 'Bootstrap' | awk '{ print $1}')
jmap -heap $(ps aux | awk '/[j]ava -Djavax/ { print $2 }') > $FOLDER/heap.txt
jstack $(ps aux | awk '/[j]ava -Djavax/ { print $2 }') > $FOLDER/jstack.txt

echo Checking devices
lspci > $FOLDER/pci.txt
lsusb > $FOLDER/usb.txt
df -h > $FOLDER/df.txt

echo Verifying RPMs, this will take some time. Skip with CTRL + C
rpm -qa > $FOLDER/rpm_qa.txt
rpm -Va > $FOLDER/rpm_va.txt

finish
