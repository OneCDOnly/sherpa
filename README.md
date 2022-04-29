![icon](images/sherpa.wide.png)

<p align="center"><i>The world's first multiple-action CLI package-manager!</i></p>

## Description

A mini-package-manager for QNAP NAS.

Package management via **sherpa** provides extra features like easy application backup and upgrading, and operations may be automated via cron.

---
## Applications available
[![ClamAV](images/ClamAV.gif)](https://www.clamav.net/) [![Deluge](images/Deluge-web.gif)](https://dev.deluge-torrent.org/) [![duf](images/duf.gif)](https://github.com/muesli/duf) [![Entware](images/Entware.gif)](https://github.com/Entware/Entware/wiki) [![Headphones](images/Headphones.gif)](https://github.com/rembo10/headphones) [![HideThatBanner](images/HideThatBanner.gif)](https://github.com/OneCDOnly/HideThatBanner) [![LazyLibrarian](images/LazyLibrarian.gif)](https://lazylibrarian.gitlab.io/) [![Medusa](images/OMedusa.gif)](https://github.com/pymedusa/Medusa) [![Mylar3](images/Mylar3.gif)](https://github.com/mylar3/mylar3)
[![NZBGet](images/NZBGet.gif)](https://nzbget.net/) [![nzbToMedia](images/nzbToMedia.gif)](https://github.com/clinton-hall/nzbToMedia) [![Par2](images/Par2.gif)](https://github.com/Parchive/par2cmdline) [![RunLast](images/RunLast.gif)](https://github.com/OneCDOnly/RunLast) [![SABnzbd](images/SABnzbd.gif)](https://sabnzbd.org/wiki/) [![sha3sum](images/sha3sum.gif)](https://github.com/maandree/sha3sum) [![SickGear](images/OSickGear.gif)](https://github.com/SickGear/SickGear/wiki) [![SortMyQPKGs](images/SortMyQPKGs.gif)](https://github.com/OneCDOnly/SortMyQPKGs) [![Transmission](images/OTransmission.gif)](https://transmissionbt.com/)

---
## Requirements

- Any model QNAP NAS running QTS 4.0 or-later.

- The ClamAV package will require at-least 1.5GB RAM installed.

---
## Usage

1) Install the **sherpa** QPKG, available [here](https://github.com/OneCDOnly/sherpa/tree/main/QPKGs/sherpa/build).

2) [SSH](https://www.qnap.com/en/how-to/knowledge-base/article/how-to-access-qnap-nas-by-ssh/) into your NAS,

3) Then at the command prompt, run:

```
sudo sherpa
```

... and follow the help from there.

If `sudo` is unavailable in your version of QTS, please SSH into your NAS as the 'admin' user instead, and run:
```
sherpa
```

---
Checkout the wiki for more information: [https://github.com/OneCDOnly/sherpa/wiki](https://github.com/OneCDOnly/sherpa/wiki)