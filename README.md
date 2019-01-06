![icon](images/sherpa.wide.png)

## Description

A BASH script to install various Usenet apps into a QNAP NAS.

**sherpa** is able to install several Usenet-related search and download apps but will only install **ONE app** at a time. If you elect to install an app that is already installed, the app will be fully reinstalled. This means the app configuration and settings are saved, the old app is uninstalled, a new version is installed, then the original settings are restored.

To install additional apps, run it again.

After running the installer, you'll have several new packages. Any existing installation of Entware will be used automatically. If Entware is not installed, a version appropriate to your NAS will be installed.


## Current status

STABLE

Initial installation of each app is OK. Re-installation of each is also OK except as shown in Testing.

TESTING

I've recently added a basic download progress display for IPKGs. Please advise if you see it doing anything weird. Screenshots are very helpful.

Headphones installer/reinstaller is very new, so I'll be tweaking it for a while to integrate it with SABnzbd.


## Known issues

1) If there is an existing installation of Entware-ng, sometimes the sherpa installer will fail to complete. If this occurs, suggest you uninstall Entware-ng and allow sherpa to install a current Entware.

2) **sherpa** is incompatible with existing installs of Optware-NG as various required packages cannot be installed through it.

## Installation

1) [SSH](https://wiki.qnap.com/wiki/How_to_SSH_into_your_QNAP_device) / [PuTTY](http://www.putty.org/) into your NAS as the 'admin' user,

2) Change to the **Public** share directory:

```
cd /share/Public
```

3) Download & extract the archive file (copy and paste at the command line):

```
curl -ksO https://raw.githubusercontent.com/onecdonly/sherpa/master/sherpa.sh && chmod +x sherpa.sh
```

4) Then, to (re)install an app, run **sherpa.sh** with the name of your required app as an argument.

So, to reinstall SABnzbd:

```
./sherpa.sh SABnzbd
```

Or:

```
./sherpa.sh SickChill

./sherpa.sh CouchPotato

./sherpa.sh OWatcher3

./sherpa.sh LazyLibrarian

./sherpa.sh Medusa

./sherpa.sh Headphones
```

## Problems?

This will happen from time-to-time as the environment changes. If it's not shown above in '**Known issues**' then you may have found something new, so please add to this thread with the details of the problem you encountered. Diagnose where you can and provide a solution if you're able. The functions in this script are a community effort. ;)

Sometimes the debug log will be required. This is always created. You can view this with:

```
cat sherpa.debug.log
```

Or run the installer in debug-mode to see it realtime. e.g.:

```
./sherpa.sh SABnzbd --debug
```

## Firmware compatibility

* QTS 4.3.x - **OK**
* QTS 4.2.x - **OK**
* QTS 4.1.x or earlier - **Unknown** (let me know if it works)


## Notes

* The information contained therein was constructed from the efforts of many community members, both here and on the [SABnzbd forum](https://forums.sabnzbd.org/). Thank you to everyone who has contributed.

* Existing installations of Clinton Hall's **SABnzbdplus** or QNAP_Stephane's **QSabNZBdPlus** will be replaced with **SABnzbdplus**. Configuration will be retained.

* Existing installations of Clinton Hall's **CouchPotato2** will be replaced with **CouchPotato2**. Configuration will be retained.

* Existing active installations of **SickRage** will be replaced with **SickChill**. Configuration will be retained.

* Each of these packages continues the idea of 'self-update-on-launch' that was used in Clinton Hall's wrapper scripts. These scripts are my own version and require a few packages to be installed via Entware (this is what **sherpa** does). Updating an app is easy - just restart the app via its init script. Each app is updated from GitHub and from that application's current 'master' branch.

* For those looking to setup a new NAS, suggest you start with SABnzbd+ first, then install a TV show finder like SickChill or Medusa. This will allow SickRage to be properly configured with the API details from SABnzbd.

* Medusa is named 'OMedusa' in the App Center to avoid conflict with the existing Medusa package available in the Qnapclub Store.

* Watcher3 is named 'OWatcher3' in the App Center to avoid conflict with the existing Watcher3 package available in the Qnapclub Store.
