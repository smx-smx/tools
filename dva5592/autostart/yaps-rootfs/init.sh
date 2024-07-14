#!/bin/sh
dnat_tcp(){
        iptables -I SmxIn -p tcp -m tcp --dport $1 -j ACCEPT
        iptables -t nat -I PREROUTING -p tcp -m tcp ! -s 192.168.0.0/23 --dport $1 -j DNAT --to=$2
}
dnat_udp(){
        iptables -I SmxIn -p udp -m udp --dport $1 -j ACCEPT
        iptables -t nat -I PREROUTING -p udp -m udp ! -s 192.168.0.0/23 --dport $1 -j DNAT --to=$2
}
mount_ifnot(){
        local src="$1"
        local dst="$2"
        local opts="$3"

        grep -q "$dst" /proc/mounts || (
                echo "mounting $dst ..."
                mount $opts "$src" "$dst"
        )
}
init_chroot(){
        mount_ifnot /dev $root/dev "-o bind"
        mount_ifnot devpts $root/dev/pts "-t devpts"
        mount_ifnot proc $root/proc "-t proc"
        mount_ifnot sysfs $root/sys "-t sysfs"

        #mount_ifnot /tmp $root/yaps-tmp "-o bind"
}
fake_fwver(){
        cmclient SET Device.DeviceInfo.SoftwareVersion DVA-5592_A1_WI_20180823
}

setup_firewall(){
        ## Short circuit INPUT
        iptables -P INPUT DROP
        iptables -I INPUT -j DROP

        iptables -N SmxIn
        iptables -I INPUT -j SmxIn

        ## Allowance
        iptables -A SmxIn -i lo -j ACCEPT
        iptables -A SmxIn -m state --state RELATED,ESTABLISHED -j ACCEPT
        #iptables -A SmxIn -m iprange --dst-range 224.0.0.0-239.255.255.255 -j ACCEPT
        iptables -A SmxIn -s 127.0.0.1/8 ! -i lo -j DROP
        iptables -A SmxIn -i br0 -j ACCEPT
        
        # DLink Voip Stack
        iptables -A SmxIn -p udp -m udp --dport 5060 -j ACCEPT
        # Asterisk
        iptables -A SmxIn -p udp -m udp --dport 5062 -j ACCEPT
        # Asterisk RTP
        iptables -A SmxIn -p udp -m udp --dport 10000:10100 -j ACCEPT

        # StrongSwan forwarding
        iptables -A SmxIn -p esp -j ACCEPT
}

export TERM=linux
root=$PWD
init_chroot
fake_fwver
setup_firewall
# continue without blocking boot
nohup ./init_post.sh &>/dev/null 2>&1 &
