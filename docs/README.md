![icon](images/sherpa.readme.png)

<p align="center"><i>The world's first multi-action CLI package-manager!</i></p>


## Description

A mini-package-manager for QNAP NAS.

Package management via **sherpa** provides extra features like easy application backup, upgrading, service and daemon management, self-checking and repair, and all operations may be automated via cron.

<b>[Click here for available packages](https://github.com/OneCDOnly/sherpa/wiki/Packages)</b>


## Installation

1) [Click here to download the **sherpa** QPKG](https://github.com/OneCDOnly/sherpa/releases/download/v230227/sherpa_230227.qpkg).

2) Install the QPKG manually through your QTS App Center UI. This QPKG is not digitally signed, so you'll need to allow unsigned packages to be installed in your App Center before installing it. It can "sign" itself (and all supported QPKGs) after installation.


## Usage

1) [SSH](https://www.qnap.com/en/how-to/faq/article/how-do-i-access-my-qnap-nas-using-ssh) into your NAS,

2) Then at the command prompt, run:

```
$ sudo sherpa
```

... and follow the help from there.

Checkout the wiki for more information: [https://github.com/OneCDOnly/sherpa/wiki](https://github.com/OneCDOnly/sherpa/wiki)