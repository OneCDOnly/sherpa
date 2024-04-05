![icon](images/sherpa.readme.png)

sherpa: a mini-package-manager for QNAP NAS
============================================

![GitHub Release](https://img.shields.io/github/v/release/OneCDOnly/sherpa) ![GitHub Downloads (all assets, latest release)](https://img.shields.io/github/downloads/OneCDOnly/sherpa/latest/total) ![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/OneCDOnly/sherpa) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

The world's first multi-action CLI package-manager!

Package management via **sherpa** provides extra features like easy application backup, upgrading, service and daemon management, self-checking and repair, and all operations may be automated via cron.

> [!CAUTION]
> This is a command-line package and service manager, it's in beta status, and packages have been known to break due to auto-upgrades going wrong. If you would like-to (and are able-to) help by diagnosing and providing logs, and don't mind things breaking from time-to-time, please use this package. If you're looking for complete stability and want a "set-and-forget" solution, it won't be found here just yet. <b>Do not</b> use sherpa in production environments, unless you're pretty-handy with the CLI and debugging bash and Python scripts, and/or can afford for applications to be out-of-order for extended periods of time.
>
> That said: the majority of development is now complete, and I'm currently working-on increasing stability during auto-package upgrades. So, <b>sherpa</b> will work beautifully on a fresh (or new) system, but can experience issues when individual application updates are released.

<b>[Click here for available packages](https://github.com/OneCDOnly/sherpa/wiki/Packages)</b>


## Installation

1) [Click here to download the latest **sherpa** QPKG](https://github.com/OneCDOnly/sherpa/releases/latest/download/sherpa.qpkg).

2) Install the QPKG manually through your QTS App Center UI. This QPKG is not digitally signed, so you'll need to allow unsigned packages to be installed in your App Center before installing it. It can "sign" itself (and all supported QPKGs) after installation.


## Usage

1) [SSH](https://www.qnap.com/en/how-to/faq/article/how-do-i-access-my-qnap-nas-using-ssh) into your NAS,

2) Then at the command prompt, run:

```
$ sudo sherpa
```

... and follow the help from there.

Checkout the wiki for more information: [https://github.com/OneCDOnly/sherpa/wiki](https://github.com/OneCDOnly/sherpa/wiki)
