![icon](images/sherpa.wide.png) 

## Description

With this script package, you can install **SABnzbd+**, **SickRage** or **CouchPotato**. It's the advanced version of the [sabnzbd-installer](https://forum.qnap.com/viewtopic.php?f=133&t=129696) script that I've been working on with much valuable feedback from the community. Development has now ceased on the older script so I can concentrate on this one. 

As it's in 'beta' state, there may be problems. Need some brave people to test it. Those who provided valuable assistance with the SAB installer will know what to expect.

It's able to install each of the apps shown above but will only install **ONE app** at a time. For those looking to setup a new NAS, suggest you start with SABnzbd+ first, then SickRage. This will allow SickRage to be properly configured with the API details from SABnzbd.

If you have an existing SABnzbd installed through one of Clinton Hall's wrapper scripts, this script will backup your current settings, queue and history, remove SABnzbd, reinstall it, then restore the settings, queue and history.

The information contained therein was constructed from the efforts of many community members, both here and on the SABnzbd forum. Thank you to everyone who has contributed.


## Installation

1) SSH / PuTTY into your NAS as the 'admin' user,

2) Change to the Public share directory:

```
cd /share/Public
```

3) Download & extract the archive file (copy and paste at the command line):

```
curl -O https://raw.githubusercontent.com/onecdonly/sherpa/master/sherpa.tar.gz && tar -zxvf sherpa.tar.gz
```

4) Then, to (re)install SABnzbd+:

```
./SABnzbdplus
```

Or to install a new SickRage or CouchPotato:

```
./SickRage

./CouchPotato2
```
