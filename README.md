# sf-debug

![Maintenance](https://img.shields.io/maintenance/yes/2019.svg) ![GitHub](https://img.shields.io/github/license/starface-support/sf-debug.svg) ![Supported STARFACE Versions](https://img.shields.io/badge/Supported%20Versions-6.0.0.0_--_6.7.0.x-f59c00.svg)\
 ![CircleCI](https://img.shields.io/circleci/build/gh/starface-support/sf-debug/master.svg) ![GitHub file size in bytes](https://img.shields.io/github/size/starface-support/sf-debug/debug.sh.svg)

## How to use this script?

### Pre-Flight checklist

#### Required

- SSH Access to the STARFACE Appliance
- [Root password](https://knowledge.starface.de/pages/viewpage.action?pageId=33784144)
- An SSH / sFTP client

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
`curl -k --silent https://raw.githubusercontent.com/sf-janz/sf-debug/master/debug.sh | /bin/bash`
- Using SCP or sFTP, download the debuginfo-XXXXXXXX.zip from the /root/ folder.

### Parameters

You can change the behaviour of the script, depending on which Paramters you pass along:

```text
debug.sh [-v|q] [-j] [-r] [-a] [-h]
-v: Verbose output (inner function calls)
-q: Minimum output (quiet)
-j: Create Java memorydump
-r: Dont verify RPMs, may save a lot of time if unnecessary
-a: Include /etc/asterisk
-fs: Force fsck for the root partition on the next boot
-u: Upload the resulting file to a STARFACE Nextcloud share (requries URI from the support)
-h: Help (this screen)
```

#### Examples

- You've been tasked to verify integrity of all installed RPM Pakets. You don't need a Java memory dump:\
`./debug.sh`
- You just need the logfiles from the appliance:\
`./debug.sh -r -a`
- You don't want to include the passwords of the SIP accounts:\
`./debug.sh -a`
- Upload the logs to STARFACE Nextcloud share:
`./debug.sh -u`
