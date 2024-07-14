#!/bin/sh /etc/rc.common
START=50

init_chroot(){
        local root="$1"

        [ -f "$root/init.sh" ] && [ -x "$root/init.sh" ] && (
                echo "running init.sh on $root ..."
                cd $root
                sh init.sh
        )
}

mount_usbdevs(){
        for sysdev in `ls -1d /sys/block/sd*`; do
                # safety check
                [ ! -e "$sysdev/queue" ] && continue

                dev=$(basename "$sysdev")
                echo "probing $dev ..."
                for syspart in `ls -1d $sysdev/sd*`; do
                        # safety check
                        [ ! -e "$syspart/partition" ] && continue

                        part=$(basename "$syspart")

                        [ ! -d /mnt/$part ] && mkdir /mnt/$part
                        grep -q /mnt/$part /proc/mounts || (
                                echo "mounting $part ..."
                                mount /dev/$part /mnt/$part
                                [ -d /mnt/$part/yaps-rootfs ] && init_chroot /mnt/$part/yaps-rootfs
                        )
                done
        done
}

boot(){
        mount_usbdevs
}
