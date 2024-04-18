![icon](images/sherpa.readme.png)

sherpa: a mini-package-manager for QNAP NAS
============================================

[![Latest Release](https://img.shields.io/github/v/release/OneCDOnly/sherpa?logo=github&label=latest%20release)](https://github.com/OneCDOnly/sherpa/releases/latest) ![GitHub Downloads (all assets, latest release)](https://img.shields.io/github/downloads/OneCDOnly/sherpa/latest/total?logo=github) ![Project Launch](https://img.shields.io/date/1494050732?logo=github&label=project%20launch)

The world's first multi-action CLI package-manager!

Package management via **sherpa** provides features like easy application backup, upgrading, service and daemon management, multi-threaded operation, self-checking and repair, and all operations may be automated via cron.

> [!IMPORTANT]
> This is a command-line package and service manager, it's in beta status, and packages have been known to break due to auto-upgrades going wrong. If you would like-to (and are able-to) help by diagnosing and providing logs, and don't mind things breaking from time-to-time, please use this package. If you're looking for complete stability and want a "set-and-forget" solution, it won't be found here just yet. <b>Do not</b> use <b>sherpa</b> in production environments, unless you're comfortable with the CLI and debugging bash and Python scripts, and/or can afford for applications to be out-of-order for extended periods of time.
>
> That said: the majority of development is now complete, and I'm currently working-on increasing stability during auto-package upgrades. So, <b>sherpa</b> will work beautifully on a fresh (or new) system, but can experience issues when individual application updates are released.

<b>[Click here for installable packages](https://github.com/OneCDOnly/sherpa/wiki/Packages)</b>


## Installation

- [SSH](https://www.qnap.com/en/how-to/faq/article/how-do-i-access-my-qnap-nas-using-ssh) into your NAS, and install the QPKG manually at the command-prompt:
```
curl -skL https://tinyurl.com/get-sherpa > /share/Public/sherpa.qpkg;
sudo sh /share/Public/sherpa.qpkg
```

## Usage


- At the command-prompt, run:

```
sudo sherpa
```

... and follow the help from there.

Checkout the wiki for more information: [https://github.com/OneCDOnly/sherpa/wiki](https://github.com/OneCDOnly/sherpa/wiki)
