![icon](images/sherpa.wide.png)

## Description

This script package can install **SABnzbd+**, **SickRage**, **CouchPotato** or **LazyLibrarian** on your QNAP NAS. It's the advanced version of the [sabnzbd-installer](https://forum.qnap.com/viewtopic.php?f=133&t=129696) script that I've been working on with much valuable feedback from the community. Development has now ceased on the older script so I can concentrate on this one.

It's able to install each of the apps shown above but will only install **ONE app** at a time. For those looking to setup a new NAS, suggest you start with SABnzbd+ first, then SickRage. This will allow SickRage to be properly configured with the API details from SABnzbd.

If you have an existing SABnzbd installed through one of Clinton Hall's wrapper scripts, this script will backup your current settings, queue and history, remove SABnzbd, reinstall it, then restore the settings, queue and history.

Each of these packages continues the idea of 'self-update-on-launch' that was used in Clinton Hall's wrapper scripts. These scripts are my own version and require a few packages to be installed via Entware (this is what sherpa does). Updating them is easy - just restart each package via its init script. Each application is pulled from GitHub and from that application's current 'master' branch.

The information contained therein was constructed from the efforts of many community members, both here and on the SABnzbd forum. Thank you to everyone who has contributed.


## Current status

STABLE

Initial installation of each app is OK. The SABnzbd re-install has been well-tested and is considered stable.

TESTING

The re-installs for LazyLibrarian, SickRage and CouchPotato are fairly new and seems to work properly, but could do with some further testing by the community.


## Known issues

1) If there is an existing installation of Entware-ng, sometimes the Sherpa installer will fail to complete. If this happens, suggest you uninstall Entware-ng and allow Sherpa to reinstall Entware and configure it.


## Installation

1) SSH / PuTTY into your NAS as the 'admin' user,

2) Change to the Public share directory:

```
cd /share/Public
```

3) Download & extract the archive file (copy and paste at the command line):

```
curl -O https://raw.githubusercontent.com/onecdonly/sherpa/master/sherpa.sh && chmod +x sherpa.sh
```

4) Then, to (re)install SABnzbd+:

```
./sherpa.sh SABnzbdplus
```

Or:

```
./sherpa.sh SickRage

./sherpa.sh CouchPotato2

./sherpa.sh LazyLibrarian
```
