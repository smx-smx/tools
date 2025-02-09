#!/usr/bin/env bash
bridge_name=nm-bridge
eth_iface_name=enp3s0

nmcli con add ifname ${bridge_name} type bridge con-name ${bridge_name}
nmcli con add type bridge-slave ifname ${eth_iface_name} master ${bridge_name}
nmcli con modify ${bridge_name} bridge.stp no
# interface is manually brought up by post_start.sh
nmcli con modify ${bridge_name} autoconnect no