#!/bin/bash

#
# debug.sh
# Version: 4
# Author: njanz
#

FOLDER="/tmp/performance"
NET="$FOLDER/net"
AST="$FOLDER/asterisk"

mkdir $FOLDER
mkdir $NET
mkdir $AST

echo Identifying appliance
appliance_identify.sh > $FOLDER/appliance_identify.txt
appliance_info.sh check_cards > $FOLDER/appliance_cards.txt
rpm -qi starface-asterisk

echo Dumping processes
uptime > $FOLDER/proc.txt
ps aux >> $FOLDER/proc.txt

echo Networking informations
lsof -i > $NET/lsof-i.txt
netstat -tulpen > $NET/netstat-tulpen.txt
netstat -an > $NET/netstat-an.txt
ifconfig > $NET/ifconfig.txt
tar -cvhzf $NET/nw-scripts.tar.gz /etc/sysconfig/network-scripts/ >/dev/null

#Dumping current iptables into file:
iptables-save >$NET/iptables-current.txt

echo Poking Asterisk
asterisk -rx 'module show' > $AST/modules.txt
asterisk -rx 'sip show peers' > $AST/peers.txt
asterisk -rx 'sip show registry' > $AST/registry.txt
asterisk -rx 'sip show channels' > $AST/sip_channels.txt
asterisk -rx 'core show channels' > $AST/core_channels.txt

echo Poking Java 
jmap -dump:live,format=b,file=$FOLDER/heap.bin $(jps | grep 'Bootstrap' | awk '{ print $1}')
jmap -heap $(ps aux | grep 'java -Djavax' | head -n 1 | awk '{ print $2}') > heap.txt
jstack $(ps aux | grep 'java -Djavax' | head -n 1 | awk '{ print $2}') > jstack.txt

echo Checking devices
lspci > $FOLDER/pci.txt
lsusb > $FOLDER/usb.txt
df -h > $FOLDER/df.txt

echo Gathering logs
tar -chzf $FOLDER/logs.tar.gz /var/log/ /root/install.*
tar -chzf $FOLDER/asterisk.tar.gz /etc/asterisk

echo Finishing up
tar -cvhzf /root/debuginfo.tar.gz $FOLDER/
rm -rf $FOLDER/
