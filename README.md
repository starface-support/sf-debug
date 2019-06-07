# sf-debug

![Maintenance](https://img.shields.io/maintenance/yes/2019.svg) ![GitHub file size in bytes](https://img.shields.io/github/size/sf-janz/sf-debug/debug.sh.svg) ![Supported STARFACE Versions](https://img.shields.io/badge/Supported%20Versions-6.0.0.0--6.6.0.20-f59c00.svg)

## How to use this script?

### Pre-Flight checklist

#### Required

- [ ] [SSH Access](http://wiki.starface.de/index.php/SSH) to the STARFACE Appliance
- [ ] [Root password](http://wiki.starface.de/index.php/Root_Passwort). [Lost your root password?](#fn1)
- [ ] An SSH / sFTP client

### Option 1: Download and execute

- Download the script to your appliance (e.g. /root/debug.sh) and make it executable.
For that, execute\
`curl -k --silent https://raw.githubusercontent.com/sf-janz/sf-debug/master/debug.sh > /root/debug.sh && chmod +x /root/debug.sh`\
within the shell (SSH).
- Start the script (you can use [Parameters](#Parameters)):\
`/root/debug.sh`
- Using SCP or sFTP, download the debuginfo-XXXXXXXX.zip from the /root/ folder.

### Option 2: Execute via cURL

- Execute\
`curl -k --silent https://raw.githubusercontent.com/sf-janz/sf-debug/master/debug.sh | /bin/bash`\
- Using SCP or sFTP, download the debuginfo-XXXXXXXX.zip from the /root/ folder.

### Parameters

You can change the behaviour of the script, depending on which Paramters you pass along:

```text
debug.sh [-v|q] [-j] [-r] [-a] [-h]
-v: Verbose output (inner function calls)
-q: Minimum output (quiet)
-j: Create Java memorydump
-r: Dont verify RPMs, may save a lot of time if unnecessary
-a: Dont include /etc/asterisk
-fs: Force fsck for the root partition on the next boot
-h: Help (this screen)
```

#### Examples

- You've been tasked to verify integrity of all installed RPM Pakets. You don't need a Java memory dump:\
`./debug.sh`
- You just need the logfiles from the appliance:\
`./debug.sh -r -a`
- You don't want to include the passwords of the SIP accounts:\
`./debug.sh -a`
