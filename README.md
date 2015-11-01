# How to use this script?
## Pre-Flight checklist
### Required

- [ ] [SSH Access](http://wiki.starface.de/index.php/SSH) to the STARFACE Appliance
- [ ] [Root password](http://wiki.starface.de/index.php/Root_Passwort). [Lost your root password?](#fn1)
- [ ] An SSH / sFTP client, if you're using Windows consider [BitVise (Tunnelier)](https://www.bitvise.com/download-area)

## Option 1: Download and execute
- Download the script to your appliance (e.g. /root/debug.sh) and make it executable.
For that, execute<br>
`curl -k --silent https://raw.githubusercontent.com/sf-janz/sf-debug/master/debug.sh > /root/debug.sh && chmod +x /root/debug.sh`<br>within the shell (SSH).
- Start the script (you can use [Parameters](#Parameters)):<br>
`/root/debug.sh`
* Using SCP or sFTP, download the debuginfo-XXXXXXXX.zip from the /root/ folder.

## Option 2: Execute via cURL
This saves your the steps of downloading and chmoding the script. Also, the script is always up to date.

* Execute<br>`curl -k --silent https://raw.githubusercontent.com/sf-janz/sf-debug/master/debug.sh | /bin/bash`<br>in the shell.
* Using SCP or sFTP, download the debuginfo-XXXXXXXX.zip from the /root/ folder.

## <a name="Paramters"></a>Parameters (see #9)
You can change the behaviour of the script, depending on which Paramters you pass along:
```
debug.sh [-v|q] [-j] [-r] [-a] [-h]
-v: Verbose output (inner function calls)
-q: Minimum output (quiet)
-j: No Java memorydump
-r: Dont verify RPMs, may save a lot of time if unnecessary
-a: Dont include /etc/asterisk
-h: Help (this screen)
```

### Examples
* You've been tasked to verify integrity of all installed RPM Pakets. You don't need a Java memory dump:<br>
`./debug.sh -j`
* You just need the logfiles from the appliance:<br>
`./debug.sh -j -r -a`
* You don't want to include the passwords of the SIP accounts:<br>
`./debug.sh -a`

<a name="fn1"></a>Root password recory:<br>
Boot into [Single User Mode](http://wiki.starface.de/index.php/Single_user_mode) to change it or reinstall :(
