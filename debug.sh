#!/bin/bash

finish() {
	ARCHIVE="$(mktemp -q -u debuginfo-XXXXXXXX.zip)"
    zip -r /root/$ARCHIVE $FOLDER
	rm -rf $FOLDER/
}

FOLDER="$(mktemp -q -d)"
NET="$FOLDER/net"
AST="$FOLDER/asterisk"

trap finish EXIT

mkdir $NET
mkdir $AST

echo Identifying appliance
appliance_identify.sh >$FOLDER/appliance_identify.txt
appliance_info.sh check_cards >$FOLDER/appliance_cards.txt

echo Dumping processes
uptime > $FOLDER/proc.txt
ps aux >> $FOLDER/proc.txt

echo Networking informations
lsof -i > $NET/lsof-i.txt
netstat -tulpen > $NET/netstat-tulpen.txt
netstat -an > $NET/netstat-an.txt
ifconfig > $NET/ifconfig.txt
zip -r $NET/nw-scripts.tar.gz /etc/sysconfig/network-scripts/ >/dev/null

iptables-save >$NET/iptables-current.txt

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

echo Verifying RPMs
rpm -qa > $FOLDER/rpm_qa.txt
rpm -Va > $FOLDER/rpm_va.txt

echo Gathering logs
zip -r $FOLDER/logs.zip /var/log /root/install.*
zip -r $FOLDER/asterisk.zip /etc/asterisk

echo Finishing up
finish
