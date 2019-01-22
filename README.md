![icon](images/sherpa.wide.png)

## Description

A BASH script to install various Usenet apps into a QNAP NAS.

**sherpa** is able to install several Usenet-related search and download apps but will only install **ONE app** at a time. If you elect to install an app that is already installed, the app will be fully reinstalled. This means the app configuration and settings are saved, the old app is uninstalled, a new version is installed, then the original settings are restored.

To install additional apps, run it again.

If the installer script is successful, your requested package and any required packages will be installed. Any existing installation of Entware will be used automatically. If Entware is not installed, a version appropriate to your NAS will be installed.

---
## Current status

STABLE


---
## Known issues

1) Sometimes, it seems existing installations of Entware can become "difficult" to work with. So, I've included an option to re-install Entware, but this should only be used as a last resort. Using:

```
./sherpa.sh sab --force-entware-reinstall
```

... will force **sherpa** to uninstall your existing Entware QPKG, then install a new one. Please note: Entware will be reverted back to default, and only the IPKGs required to support your installed **sherpa** apps will be installed.


2) **sherpa** is incompatible with existing installs of Optware-NG as various required packages cannot be installed through it.

---
## Usage

1) [SSH](https://wiki.qnap.com/wiki/How_to_SSH_into_your_QNAP_device) / [PuTTY](http://www.putty.org/) into your NAS as the 'admin' user,

2) Change to the **Public** share directory:

```
cd /share/Public
```

3) Download the installer script and make it executable:

```
curl -skLO https://git.io/sherpa.sh && chmod +x sherpa.sh
```

4) Then, to install (or reinstall) an app, run **sherpa.sh** with the name of your required app as an argument.

So, to install SABnzbd:

```
./sherpa.sh SABnzbd
```

... and then/or:

```
./sherpa.sh SickChill

./sherpa.sh CouchPotato

./sherpa.sh OWatcher3

./sherpa.sh LazyLibrarian

./sherpa.sh Medusa

./sherpa.sh Headphones
```

---
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

---
## Firmware compatibility

* QTS 4.3.x - **OK**
* QTS 4.2.x - **OK**
* QTS 4.1.x or earlier - **Unknown** (let me know if it works)

---
## Notes

* The information contained therein was constructed from the efforts of many community members, both here and on the [SABnzbd forum](https://forums.sabnzbd.org/). Thank you to everyone who has contributed.

* Existing installations of Clinton Hall's **SABnzbdplus** or QNAP_Stephane's **QSabNZBdPlus** will be replaced with **SABnzbdplus**. Configuration will be retained.

* Existing installations of Clinton Hall's **CouchPotato2** will be replaced with **CouchPotato2**. Configuration will be retained.

* Existing active installations of **SickRage** will be replaced with **SickChill**. Configuration will be retained.

* Each of these packages continues the idea of 'self-update-on-launch' that was used in Clinton Hall's wrapper scripts. These scripts are my own version and require a few packages to be installed via Entware (this is what **sherpa** does). Updating an app is easy - just restart the app via its init script. Each app is updated from GitHub and from that application's current 'master' branch.

* For those looking to setup a new NAS, suggest you start with SABnzbd+ first, then install a TV show finder like SickChill or Medusa.

* **Medusa** will appear as 'OMedusa' in your App Center to avoid conflict with the existing **Medusa** package available in the Qnapclub Store.

* **Watcher3** will appear as 'OWatcher3' in your App Center to avoid conflict with the existing **Watcher3** package available in the Qnapclub Store.
