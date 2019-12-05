#!/bin/bash

finish() {
  echodelim "Done!"
  _ARCHIVE="/root/$(mktemp -q -u debuginfo-XXXXXXXX.zip)"
  _folders="/var/log"

  if [[ ! -e $FOLDER ]]; then
    vecho "Tempfolder does not exist, nothing to do."
		exit 1
  else
    if [[ -e "/var/spool/hylafax/log/" ]]; then _folders+=" /var/spool/hylafax/log/"; fi
    if [[ -e "/var/coredumps/" ]]; then _folders+=" /var/coredumps/"; fi
    if [[ "$inclDialplan" = true ]]; then _folders+=" /etc/asterisk/ -x etc/asterisk/key*"; fi

    vecho "Finishing up, zipping $FOLDER and $_folders to $_ARCHIVE"
    # Word splitting should absolutely happen here
    # shellcheck disable=2086
    nice -n 15 ionice -c 2 -n 5 zip -qr "$_ARCHIVE" "$FOLDER/" $_folders
  fi

  if [[ "$uploadNextcloud" = true ]]; then upload-nc "$_ARCHIVE"; fi

  vecho "Deleting $FOLDER"
  rm -rf "{$FOLDER:?}/"
}

rpmverification=false
javadump=false
verbose=false
quiet=false
inclDialplan=false
uploadNextcloud=false
uploadURI=

hw-info(){
  echodelim "Hardware"
  vecho "Identifying appliance..."
  appliance_identify.sh &>"$APPLIANCE/appliance_identify.txt"
  appliance_info.sh check_cards &>"$APPLIANCE/appliance_cards.txt"
  vecho "Checking devices"

  # ToDo Merge files
  lspci &>"$APPLIANCE/pci.txt"
  lspci -t &>>"$APPLIANCE/pci.txt"

  lsusb &>"$APPLIANCE/usb.txt" &&\
   lsusb -t &>>"$APPLIANCE/usb.txt"

  vecho "Checking free space"
  lsblk -oNAME,FSTYPE,MOUNTPOINT,TYPE,SIZE &>"$APPLIANCE/lsblk.txt"
  df -h &>"$APPLIANCE/df.txt"
  free &>"$APPLIANCE/free.txt"
}

os-details(){
  echodelim "OS"
  vecho Dumping processlist...
  uptime &>"$OS/proc.txt"
  ps aux &>>"$OS/proc.txt"
}

nw-details(){
  echodelim "Network"
  vecho "Gathering networking informations..."
  lsof -i &>"$NET/lsof-i.txt"
  ss -tulpen &>"$NET/netstat-tulpen.txt"
  ss -an &>"$NET/netstat-an.txt"
  ip -a &>"$NET/ifconfig.txt"
  nice -15 zip -qr "$NET/nw-scripts.zip" "/etc/sysconfig/network-scripts/"
  iptables-save &>"$NET/iptables-current.txt"
  iptables -nvL >"$NET/iptables-counters.txt"
  ip r &>"$NET/routes.txt"

  vecho "Checking STARFACE HQ avaibility..."
  curl -sik https://license.starface.de &> "$NET/https-license.txt"
  curl -s http://starface.de/ip.php &>> "$NET/https-license.txt"
}

ast-details(){
  echodelim "Asterisk"
  vecho "Enum Asterisk modules"
  asterisk -rx 'module show' &>"$AST/modules.txt"

  vecho "Enumerate sip peers-, registry- and channelstate"
  asterisk -rx 'sip show peers' &>"$AST/peers.txt"
  asterisk -rx 'sip show registry' &>"$AST/registry.txt"
  asterisk -rx 'sip show channels' &>"$AST/sip_channels.txt"

  vecho "Retrieving core information"
  asterisk -rx 'core show channels' &>"$AST/core_channels.txt"
  asterisk -rx 'core show threads' &>"$AST/core_threads.txt"
  asterisk -rx 'core show taskprocessors' &>"$AST/core_taskprocessors.txt"

  vecho "Retrieving ISDN configurations and alarms.."
  asterisk -rx 'pri show spans' &>"$AST/pri_spans.txt"
  asterisk -rx 'srx show layers' &>"$AST/srx_layers.txt"
}

java-details(){
  echodelim "Java"

  # Determine STARFACE Version
  if [[ -s "/var/starface/fs-interface/version" ]]; then
    release="$(cat /var/starface/fs-interface/version)"
  else
    release="$(rpm -q --queryformat '%{VERSION}' starface-pbx | tr -d .)"
  fi

  vecho "This is STARFACE v$release"

  if test "$(echo -e "6.4.3.0\n$release" | sort -V | head -n 1)" != "$release"; then
    # Tomcat has its own service user
    userid=$(id -u tomcat)
    pid=$(pgrep -U "$userid" java)

    chmod -R o+rwx "$FOLDER"
    
    vecho "Creating threaddump of $pid"
    
    # Disable "sudo doesn't affect redirects.", as the redirect has more privileges than the command executed.
    # shellcheck disable=SC2024
    sudo -u tomcat jstack -l "$pid" > "$FOLDER/jstack.$pid.$(date +%F_%R:%S)"

    if [[ "$javadump" = true ]]; then
      vecho "Creating heapdumps of $pid"
      sudo -u tomcat jmap -dump:live,format=b,file="$FOLDER/live.bin.$pid" "$pid"
      sudo -u tomcat jmap -dump:format=b,file="$FOLDER/memory_dead.bin.$pid" "$pid"
    fi
  else
    pid="$(ps aux | awk '/[j]ava -Djavax/ { print $2 }')"
    vecho "Creating threaddump of $pid"
    jstack -l "$pid" &>"$FOLDER/jstack.$pid"

    if [[ "$javadump" = true ]]; then
      vecho "Creating heapdumps of $pid"
      jmap -dump:live,format=b,file="$FOLDER/live.bin.$pid" "$pid"
      jmap -dump:format=b,file="$FOLDER/memory_dead.bin.$pid" "$pid"
    fi
  fi
}

config-dump(){
  echodelim "Configuration"
  vecho "Getting general settings..."
  vecho "setup-Table"
  psql asterisk -c 'SELECT * FROM setup WHERE "key" !~* '\''(pass?.)|(secret)|(auth)|(dropbox)'\'';' &>"$FOLDER/db-setup.txt"
  vecho "configgeneral-Table"
  psql asterisk -c 'SELECT * FROM configgeneral;' &>"$FOLDER/db-configgeneral.txt"
  vecho "Numberblocks"
  psql asterisk -c 'SELECT n.*, l.wirename FROM numberblocks n, lineconfiguration l WHERE l.id = n.lid;' &>"$FOLDER/db-numberblocks.txt"
}

rpm-details(){
  echodelim "RPM"
  echo Enumerating RPMs
  rpm -qa &>"$FOLDER/rpm_qa.txt"
  if [[ "$rpmverification" = true ]]; then
    echo Verifying RPMs, this will take some time. Skip with CTRL + C
    nice -10 rpm -Va &>"$FOLDER/rpm_va.txt"
  fi
}

# TODO This entire method needs more robustness against wrong or malicious input
upload-nc(){
  echodelim "Nextcloud Upload"
  
  if [[ -z "$uploadURI" ]]; then
    vecho "No URI, opening dialog"
    exec 3>&1
    uploadURI=$(dialog --inputbox "STARFACE Support upload URI (files.starface.de):" 20 75 2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case $exit_status in
    $DIALOG_CANCEL)
      echo "Canceled URI input"
      return
      ;;
    esac
  fi

  vecho "uploadURI=$uploadURI"

  # TODO There has to be a better way than using `echo | awk`...
  # shellcheck disable=SC2086
  nextcloudShare=$(echo $uploadURI | awk 'match($0, "[^/]*$") { print substr( $0, RSTART, RLENGTH) }')

  curl -k -T "$1" -u "$nextcloudShare:" https://files.starface.de/public.php/webdav/
}

showOptionsDialog(){
  exec 3>&1
  selection=$(dialog --checklist "Select options" 20 75 6 \
            "rpmverification" "Verify RPM packets (might take 5 - 20 minutes)" on \
            "inclDialplan" "Include asterisk and dahdi config"  on  \
            "javadump" "Java memorydump (Will result in a large Archive)" off \
            "verbose" "Display progress (Verbose)" on \
            "fsck" "Force filesystemcheck on next reboot" off \
            "nextcloud" "Upload the archive to a Nextcloud share?" off \
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
  if [[ -n "$selection" ]]; then
    vecho "Building those Options!"
    vecho "Here's what we got so far: $selection"
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
        '"nextcloud"')
          uploadNextcloud=true
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
    echo "=========  $1  ========="
  fi
}

# Verbose output on stdout
vecho() {
  if [[ $verbose = true ]] && [[ $quiet = false ]]; then
    echo "$1"
  fi
}

main() {
  FOLDER="$(mktemp -q -d)"
  AST="$FOLDER/asterisk"
  APPLIANCE="$FOLDER/appliance"
  OS="$APPLIANCE/os"
  NET="$OS/net"

  mkdir "$AST" "$APPLIANCE" "$OS" "$NET"

  # We have created folders, don't exit the script without cleaning up.
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
  echo "debug.sh [-v|q] [-j] [-r] [-a] [-h] [-u]"
  echo "-v: Verbose output (inner function calls)"
  echo "-q: Minimum output (quiet)"
  echo "-j: Create Java memorydump"
  echo "-r: Dont verify RPMs, may save a lot of time if unnecessary"
  echo "-a: Include /etc/asterisk"
  echo "-fs: Force fsck for the root partition on the next boot"
  echo "-u: Upload the resulting file to a STARFACE Nextcloud share (requries URI from the support)" # TODO this needs an extra parameter for the URI
  echo "-h: Help (this screen)"
}

if [[ -z "$*" ]]; then
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
	      inclDialplan=true
	      ;;
	      -h)
	      printHelp
	      exit
	      ;;
	      -fs)
	      touch /forcefsck
	      vecho "Forcing fsck for / on next boot"
        ;;
        -u)
        uploadNextcloud=true
	      ;;
	      *)
	      ;;
	  esac
	done

	main
fi
