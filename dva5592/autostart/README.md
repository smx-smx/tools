# DVA-5592

This folder contains custom init scripts for the DVA-5592 modem (made by ADB Broadband)

# Installation

First, upload `smx.sh` via scp. Install it like this:

```shell
root@dlinkrouter:~# cp /tmp/smx.sh /etc/init.d/smx.sh
root@dlinkrouter:~# cd /etc/rc.d
root@dlinkrouter:/etc/rc.d# ln -s ../init.d/smx.sh S50smx.sh
```

Then, copy the remaining files to a USB pendrive and make sure they are executable.

Connect the USB pendrive to the router and reboot it.\
The scripts should now run on boot, and before XDSL is online
