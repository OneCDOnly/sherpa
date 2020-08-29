![icon](images/sherpa.wide.png)

## Description

A mini-package-manager to install various media-management apps into QNAP NAS.

**sherpa** is able to install several search and download apps but will only install **ONE app** at a time. If you elect to install an app that is already installed, the app will be fully reinstalled. App configuration will be retained.

To install additional apps, run it again.

If the installer is successful, your requested package and any required packages will be installed. Any existing installation of Entware will be used automatically. If Entware is not installed, a version appropriate to your NAS will be installed.

---
## Before you begin

This is a **command-line** package manager. If you're not comfortable using the BASH command shell, then please look at some of the fine GUI-only packaged alternatives available from the [Qnapclub Store](https://qnapclub.eu/en). You'll have a much better user-experience.


---
## Current status

STABLE - except for SickChill. The devs are hard-at-work migrating it to Python3. This is causing a few breakages. :(

---
## Requirements

Any model QNAP NAS with at-least 1GB RAM and running QTS 4.0 or-later.

---
## Usage

1) [SSH](https://wiki.qnap.com/wiki/How_to_SSH_into_your_QNAP_device) / [PuTTY](http://www.putty.org/) into your NAS as the 'admin' user,

2) Change to the **Public** share directory:

```
cd /share/Public
```

3) Download the installer script and make it executable (you'll only have to do this once):

```
curl -skLO https://git.io/sherpa.sh && chmod +x sherpa.sh
```

4) Then, to install (or reinstall) an app, run **sherpa.sh** with the name of your required app as an argument.

So, to install SABnzbd, use:

```
./sherpa.sh SABnzbd
```

... and then/or:

```
./sherpa.sh nzbToMedia

./sherpa.sh LazyLibrarian

./sherpa.sh Medusa

./sherpa.sh SickChill

./sherpa.sh SickGear

./sherpa.sh Mylar3

./sherpa.sh NZBGet

./sherpa.sh Transmission
```

---
## Known issues

1) Python 2.7.16 is no-longer available via Entware/OpenWRT so the **Headphones** QPKG can no-longer be installed. I'll need to find another Python2 source with installable modules, but I'm not hopeful.

2) Sometimes, it seems existing installations of OpenWRT can become "difficult" to work with. So, Entware can also be reinstalled, but this should only be used as a last resort. Using:

```
./sherpa.sh Entware
```

... will force **sherpa** to uninstall your existing Entware QPKG, then install a new one. **Note:** OpenWRT will be reverted back to default, and only the IPKGs required to support your installed **sherpa** apps will be installed. All **sherpa** installed applications will be restarted afterward.


3) **sherpa** is incompatible with Optware-NG as it's missing a few required packages.


4) All the latest issues can be seen on GitHub: [https://github.com/OneCDOnly/sherpa/issues](https://github.com/OneCDOnly/sherpa/issues)

---
## Problems?

This will happen from time-to-time as the environment changes. If it's not shown above in '**Known issues**' then you may have found something new, so please add to [this thread](https://forum.qnap.com/viewtopic.php?f=320&t=132373) with the details of the problem you encountered. Diagnose where you can and provide a solution if you're able. The functions in this script are a community effort. ;)

Sometimes the debug log will be required. This is always created. You can view this with:

```
./sherpa.sh --log
```

Or run the installer in debug-mode to see it realtime. e.g.:

```
./sherpa.sh SABnzbd --debug
```
NEW! Your debug log can now be posted online courtesy of [https://termbin.com](https://termbin.com):

```
./sherpa.sh --paste
```

A link will be generated to view this log online. Share it here if you need assistance.

**Note:** your log will be **publicly accessible** to anyone who knows the link details. It will be automatically deleted after 1 month. The debug log typically won't contain any personally-identifiable information. Your public and private IP addresses, email address and so-on are not recorded. However, there is a chance some info may leak if an app generates a backtrace and this is pasted into the sherpa debug log. So, check it first before pasting online.

There's now an option to check that all application dependencies have been satisfied. This will install any additional QPKGs or IPKGs to support any sherpa-installed applications present on your NAS:

```
./sherpa.sh --check
```


---
## Firmware compatibility

* QTS 4.4.x - **OK**
* QTS 4.3.x - **OK**
* QTS 4.2.x - **OK**
* QTS 4.1.x or earlier - **Unknown**

---
## Notes

Supports application configuration-only backup and restore via the 'backup' and 'restore' arguments. This can be scripted via cron to create a regular backup of each app.

QPKG (configuration-only) backups will be stored in a new hidden directory located under your default userdata volume called [.qpkg_config_backup/]. Hopefully, QNAP won't mess with this location (I'm looking at you Malware Remover).

To jump to this path:

```
cd $(getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
```

Each QPKG has a single [config.tar.gz] file to backup into. Each new backup replaces the old one (so, no versioning available).

Example: to backup SABnzbd:

```
/etc/init.d/sabnzbd3.sh backup
```
Example: to restore SABnzbd:
```
/etc/init.d/sabnzbd3.sh restore
```
This will 'stop' the QPKG, restore from the backup file (if it exists), then 'start' the QPKG again.

* The information contained therein was constructed from the efforts of many community members, both here and on the [SABnzbd forum](https://forums.sabnzbd.org/). Thank you to everyone who has contributed.

* Each of these packages continues the idea of 'self-update-on-launch' that was used in Clinton Hall's wrapper scripts. These scripts are my own version and require a few packages to be installed via Entware (this is what **sherpa** does). Updating an app is easy - just restart the app via its init script. Each app is updated from GitHub and from that application's current 'master' branch.

* **Medusa** will appear as 'OMedusa' in your App Center to avoid conflict with the existing **Medusa** package available in the Qnapclub Store.

* **SickGear** will appear as 'OSickGear' in your App Center to avoid conflict with the existing **SickGear** package available in the Qnapclub Store.

* **Transmission** will appear as 'OTransmission' in your App Center to avoid conflict with the existing **Transmission** packages available.
