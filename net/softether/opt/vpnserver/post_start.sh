#!/usr/bin/env bash
dev_name=tap_soft
found=0
nm_conn_name=nm-bridge
bridge_name=nm-bridge

tap_ipaddr=192.168.7.1/24

for((i=0; i<10; i++)); do
        if [ -e /sys/devices/virtual/net/$dev_name ]; then
                found=1
                break
        fi
        sleep 1
done

if [ $found -ne 1 ]; then
        exit 1
fi

# assign an IP address to the TAP interface
ip addr add ${tap_ipaddr} dev $dev_name

# bring up the bridge
nmcli con up ${nm_conn_name}

# add the TAP interface to the bridge
ip link set ${dev_name} master ${bridge_name}
