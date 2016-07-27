#!/bin/bash

finish() {
  echodelim "Done!"
  ARCHIVE="/root/$(mktemp -q -u debuginfo-XXXXXXXX.zip)"
  if [[ ! -e $FOLDER ]]; then
    vecho "Tempfolder does not exist, nothing to do."
		exit 1
  elif [[ $inclDialplan = true ]]; then
    vecho "Finishing up, zipping $FOLDER, /var/log and /etc/asterisk to $ARCHIVE"
    nice -15 ionice -c 2 -n 5 zip -qr $ARCHIVE /etc/asterisk /var/log $FOLDER/
  else
    vecho "Finishing up, zipping $FOLDER and /var/log to $ARCHIVE"
    nice -15 ionice -c 2 -n 5 zip -qr $ARCHIVE /var/log $FOLDER/
  fi

  vecho "Deleting $FOLDER"
  rm -rf "{$FOLDER:?}/"
}

rpmverification=false
javadump=false
verbose=false
quiet=false
inclDialplan=false

hw-info(){
  echodelim "Hardware"
  vecho "Identifying appliance..."
  appliance_identify.sh &>$APPLIANCE/appliance_identify.txt
  appliance_info.sh check_cards &>$APPLIANCE/appliance_cards.txt

  vecho "Checking devices"

  # ToDo Merge files
  lspci &>$APPLIANCE/pci.txt
  lspci -t &>>$APPLIANCE/pci.txt

  lsusb &>$APPLIANCE/usb.txt && lsusb -t &>>$APPLIANCE/usb.txt

  vecho "Checking free space"
  lsblk -oNAME,FSTYPE,MOUNTPOINT,TYPE,SIZE &>$APPLIANCE/lsblk.txt
  df -h &>$APPLIANCE/df.txt
  free &>$APPLIANCE/free.txt

}

os-details(){
  echodelim "OS"
  vecho Dumping processlist...
  uptime &>$OS/proc.txt
  ps aux &>>$OS/proc.txt
}

nw-details(){
  echodelim "Network"
  vecho "Gathering networking informations..."
  lsof -i &>$NET/lsof-i.txt
  netstat -tulpen &>$NET/netstat-tulpen.txt
  netstat -an &>$NET/netstat-an.txt
  ifconfig &>$NET/ifconfig.txt
  nice -15 zip -qr $NET/nw-scripts.zip /etc/sysconfig/network-scripts/
  iptables-save &>$NET/iptables-current.txt
  iptables -nvL >$NET/iptables-counters.txt
  route -n &>$NET/routes.txt

  vecho "Checking STARFACE HQ avaibility..."
  curl -sk https://license.starface.de &> $NET/https-license.txt
  curl -s http://starface.de/ip.php &> $NET/https-license.txt
}

ast-details(){
  echodelim "Asterisk"
  vecho "Enum Asterisk modules"
  asterisk -rx 'module show' &>$AST/modules.txt

  vecho "Enumerate sip peers-, registry- and channelstate"
  asterisk -rx 'sip show peers' &>$AST/peers.txt
  asterisk -rx 'sip show registry' &>$AST/registry.txt
  asterisk -rx 'sip show channels' &>$AST/sip_channels.txt

  vecho "Retrieving core information"
  asterisk -rx 'core show channels' &>$AST/core_channels.txt
  asterisk -rx 'core show threads' &>$AST/core_threads.txt
  asterisk -rx 'core show taskprocessors' &>$AST/core_taskprocessors.txt

  vecho "Retrieving ISDN configurations and alarms.."
  asterisk -rx 'pri show spans' &>$AST/pri_spans.txt
  asterisk -rx 'srx show layers' &>$AST/srx_layers.txt
}

java-details(){
  echodelim "Java"
  _javaPID="$(ps aux | awk '/[j]ava -Djavax/ { print $2 }')"
  if [ ! -z "$_javaPID" ]; then
    if [[ "$javadump" = true ]]; then
      vecho "Whats in the jStack?"
      jstack -l $_javaPID &>$FOLDER/jstack.txt
      vecho "Creating Javadump"
      nice -n -5 jmap -dump:live,format=b,file=$FOLDER/heap.bin $(jps | grep 'Bootstrap' | awk '{ print $1}')
    fi
    vecho "Getting heap summary"
    jmap -heap $_javaPID &>$FOLDER/heap.txt
  else
    vecho "No Java PID found. Skipping..."
  fi
}

config-dump(){
  echodelim "Configuration"
  vecho "Getting general settings..."
  vecho "setup-Table"
  psql asterisk -c 'SELECT * FROM setup WHERE "key" !~* '\''(pass?.)|(secret)|(auth)|(dropbox)'\'';' &>$FOLDER/db-setup.txt
  vecho "configgeneral-Table"
  psql asterisk -c 'SELECT * FROM configgeneral;' &>$FOLDER/db-configgeneral.txt
  vecho "Numberblocks"
  psql asterisk -c 'SELECT n.*, l.wirename FROM numberblocks n, lineconfiguration l WHERE l.id = n.lid;' &>$FOLDER/db-numberblocks.txt
}

rpm-details(){
  echodelim "RPM"
  echo Enumerating RPMs
  rpm -qa &>$FOLDER/rpm_qa.txt
  if [[ "$rpmverification" = true ]]; then
    echo Verifying RPMs, this will take some time. Skip with CTRL + C
    nice -10 rpm -Va &>$FOLDER/rpm_va.txt
  fi
}

showOptionsDialog(){
  exec 3>&1
  selection=$(dialog --checklist "package timing" 20 75 5 \
            "rpmverification" "Verify RPM packets (might take 5 - 20 minutes)" on \
            "inclDialplan" "Include asterisk and dahdi config"  on  \
            "javadump" "Java memorydump (Will result in a large Archive)" off \
            "verbose" "Display progress (Verbose)" on \
            "fsck" "Force filesystemcheck on next reboot" off \
            2>&1 1>&3)
  exit_status=$?
  exec 3>&-
  case $exit_status in
    $DIALOG_CANCEL)
      clear
      echo "Program terminated."
      exit
      ;;
    $DIALOG_ESC)
      clear
      echo "Program aborted." >&2
      exit 1
      ;;
  esac

	#Set options
  if [[ ! -z "$selection" ]]; then
    echo "Building those Options!"
    echo "Here's what we got so far: " $selection
    for o in $selection; do
      case $o in
        '"rpmverification"')
          rpmverification=true
          ;;
        '"javadump"')
          javadump=true
          ;;
        '"verbose"')
          verbose=true
          ;;
        '"inclDialplan"')
          inclDialplan=true
          ;;
        '"fsck"')
          touch /forcefsck
          vecho "Forcing fsck for / on next boot"
          ;;
        *)
          echo "Unkown Parameter: $o"
          ;;
        esac
    done
  else
    echo "No options picked"
		exit 255
  fi

	clear
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
  config-dump
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

if [[ -z "$@" ]]; then
	# No parameters given, present dialog.
	showOptionsDialog
	main
else
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
fi
