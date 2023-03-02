![icon](images/sherpa.readme.png)

<p align="center"><i>The world's first multi-action CLI package-manager!</i></p>


## Description

A mini-package-manager for QNAP NAS.

Package management via **sherpa** provides extra features like easy application backup and upgrading, service management, self-checking and repair, and operations may be automated via cron.

<b>[Click here for available packages](https://github.com/OneCDOnly/sherpa/wiki/Packages)</b>

## Requirements

- Any model QNAP NAS running QTS 4.0 or-later.


## Usage

1) [SSH](https://www.qnap.com/en/how-to/faq/article/how-do-i-access-my-qnap-nas-using-ssh) into your NAS,

2) Then at the command prompt, run:

```
$ sudo sherpa
```

... and follow the help from there.

If `sudo` is unavailable in your version of QTS, please SSH into your NAS as the 'admin' user instead, and run:
```
# sherpa
```

Checkout the wiki for more information: [https://github.com/OneCDOnly/sherpa/wiki](https://github.com/OneCDOnly/sherpa/wiki)