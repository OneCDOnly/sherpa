![icon](images/sherpa.wide.png)

## Description

With this, you can install **SABnzbd+**, **SickRage**, **CouchPotato** or **LazyLibrarian** on your QNAP NAS.

**sherpa** is able to install each of the apps shown above but will only install **ONE app** at a time. If you elect to install an app that is already installed, the app will be fully reinstalled. This means the app configuration and settings are saved, the old app is uninstalled, a new version is installed, then the original settings are restored.


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

## Problems?

This will happen from time-to-time as the environment changes. If it's not shown above in 'Known issues' then you may have found something new, so please add to this thread with the details of the problem you encountered. Diagnose where you can and provide a solution if you're able. The functions in this script are a community effort. ;)

Sometimes the debug log will be required. This is always created. You can view this with:

```
cat sherpa.debug.log
```

Or run the installer in debug-mode to see it realtime. e.g.:

```
./sherpa.sh SABnzbd --debug
```

## Firmware compatibility

    QTS 4.3.x - OK
    QTS 4.2.x - OK
    QTS 4.1.x or earlier - Unknown (let me know if it works)


## Notes

The information contained therein was constructed from the efforts of many community members, both here and on the SABnzbd forum. Thank you to everyone who has contributed.

If you have an existing SABnzbd (like Clinton Hall's SABnzbdplus or QNAP_Stephane's QSabNZBdPlus package and you choose to install the SABnzbd package via sherpa, your existing settings, queue & history will be converted to suit this new package, and the original SAB will be uninstalled.

Each of these packages continues the idea of 'self-update-on-launch' that was used in Clinton Hall's wrapper scripts. These scripts are my own version and require a few packages to be installed via Entware (this is what sherpa does). Updating an app is easy - just restart the app via its init script. Each app is updated from GitHub and from that application's current 'master' branch.

For those looking to setup a new NAS, suggest you start with SABnzbd+ first, then SickRage. This will allow SickRage to be properly configured with the API details from SABnzbd.
