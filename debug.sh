#!/bin/bash

finish() {
	ARCHIVE="/root/$(mktemp -q -u debuginfo-XXXXXXXX.zip)"
	
	echo Finishing up, zipping $FOLDER to $ARCHIVE	
    zip -qr $ARCHIVE /etc/asterisk/ /var/log $FOLDER/
	rm -rf $FOLDER/
}

FOLDER="$(mktemp -q -d)"
AST="$FOLDER/asterisk"
APPLIANCE="$FOLDER/appliance"
OS="$APPLIANCE/os"
NET="$OS/net"

trap finish EXIT

mkdir $AST $APPLIANCE $OS $NET

echo Identifying appliance...
appliance_identify.sh 2>&1>$APPLIANCE/appliance_identify.txt
appliance_info.sh check_cards 2>&1>$APPLIANCE/appliance_cards.txt

echo Dumping processlist...
uptime 2>&1>$OS/proc.txt
ps aux 2>&1>>$OS/proc.txt

echo Gathering networking informations...
lsof -i 2>&1>$NET/lsof-i.txt
netstat -tulpen 2>&1>$NET/netstat-tulpen.txt
netstat -an 2>&1>$NET/netstat-an.txt
ifconfig 2>&1>$NET/ifconfig.txt
zip -qr $NET/nw-scripts.zip /etc/sysconfig/network-scripts/
iptables-save 2>&1>$NET/iptables-current.txt
route -n 2>&1>$NET/routes.txt

echo Checking STARFACE HQ avaibility...
curl -k https://license.starface.de 2>&1> $NET/https-license.txt
curl http://starface.de 2>&1> $NET/https-license.txt

echo Poking Asterisk
asterisk -rx 'module show' 2>&1>$AST/modules.txt
asterisk -rx 'sip show peers' 2>&1>$AST/peers.txt
asterisk -rx 'sip show registry' 2>&1>$AST/registry.txt
asterisk -rx 'sip show channels' 2>&1>$AST/sip_channels.txt
asterisk -rx 'core show channels' 2>&1>$AST/core_channels.txt
asterisk -rx 'pri show spans' 2>&1>$AST/pri_spans.txt
asterisk -rx 'srx show layers' 2>&1>$AST/srx_layers.txt

echo Poking Java...
jmap -dump:live,format=b,file=$FOLDER/heap.bin $(jps | grep 'Bootstrap' | awk '{ print $1}')
jmap -heap $(ps aux | awk '/[j]ava -Djavax/ { print $2 }') 2>&1>$FOLDER/heap.txt
jstack $(ps aux | awk '/[j]ava -Djavax/ { print $2 }') 2>&1>$FOLDER/jstack.txt

echo Checking devices
lspci 2>&1>$FOLDER/pci.txt
lsusb 2>&1>$FOLDER/usb.txt
df -h 2>&1>$FOLDER/df.txt

echo Verifying RPMs, this will take some time. Skip with CTRL + C
rpm -qa 2>&1>$FOLDER/rpm_qa.txt
rpm -Va 2>&1>$FOLDER/rpm_va.txt
