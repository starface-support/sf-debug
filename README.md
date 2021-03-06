# sf-debug

![Maintenance](https://img.shields.io/maintenance/yes/2020.svg)![Supported STARFACE Versions](https://img.shields.io/badge/Supported%20Versions-6.0.0.0_--_6.7.2.x-f59c00.svg)\
![GitHub](https://img.shields.io/github/license/starface-support/sf-debug.svg) 
 ![GitHub file size in bytes](https://img.shields.io/github/size/starface-support/sf-debug/debug.sh.svg) ![GitHub Workflow Status](https://img.shields.io/github/workflow/status/starface-support/sf-debug/shellcheck?label=shellcheck)

## How to use this script?

### Option 1: Download and execute

- Download the script to your appliance (e.g. /root/debug.sh) and make it executable.
For that, execute\
`curl --silent https://raw.githubusercontent.com/starface-support/sf-debug/master/debug.sh > /root/debug.sh && chmod +x /root/debug.sh`\
within the shell (SSH).
- Start the script (you can use [Parameters](#Parameters)):\
`/root/debug.sh`
- Using SCP or sFTP, download the debuginfo-XXXXXXXX.zip from the /root/ folder.

### Option 2: Execute via cURL

- Execute\
`curl --silent https://raw.githubusercontent.com/starface-support/sf-debug/master/debug.sh | /bin/bash`
- Using SCP or sFTP, download the debuginfo-XXXXXXXX.zip from the /root/ folder.

### Parameters

You can change the behaviour of the script, depending on which Paramters you pass along:

```text
debug.sh [-v|q] [-j] [-r] [-a] [-h] [-u]
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

[![asciicast](https://asciinema.org/a/X33aPRHajx6HJgGFtwqjgnTeh.svg)](https://asciinema.org/a/X33aPRHajx6HJgGFtwqjgnTeh)

- You've been tasked to verify integrity of all installed RPM Pakets. You don't need a Java memory dump:\
`curl -sSL https://git.io/JJilh | /bin/bash`
- You just need the logfiles from the appliance:\
`curl -sSL https://git.io/JJilh | /bin/bash -s -- -r`
- Upload the logs to STARFACE Nextcloud share:\
`curl -sSL https://git.io/JJilh | /bin/bash -s -- -u -r`
- Upload the logs and a Javadump to STARFACE Nextcloud share:\
`curl -sSL https://git.io/JJilh | /bin/bash -s -- -j -u -r`
