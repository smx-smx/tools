# DVA-5592

This folder contains custom init scripts for the DVA-5592 modem (made by ADB Broadband)

# Installation

First, upload `smx.sh` via scp. Install it like this:

```shell
root@dlinkrouter:~# cp /tmp/smx.sh /etc/init.d/smx.sh
root@dlinkrouter:~# cd /etc/rc.d
root@dlinkrouter:/etc/rc.d# ln -s ../init.d/smx.sh S50smx.sh
```

Now grab a USB pendrive and create a folder called `yaps-rootfs` on it.\
Copy all the remaining scripts to it, and make sure they are executable (`chmod +x`).\
The purpose of `yaps-rootfs` is to contain a build of [bcm63138-buildroot](https://github.com/smx-smx/bcm63138-buildroot), but you can also just put custom init scripts there.

You can now move the USB pendrive to the router and reboot it.\
The scripts should now run on boot, and before XDSL is online
