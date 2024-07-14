#!/bin/sh
ROOT=$PWD
export LD_LIBRARY_PATH="${ROOT}/lib:${ROOT}/usr/lib"

wait_xdsl_link(){
        while true; do
                local status=`xdslctl info --state | grep ^Status: | cut -d ' ' -f2`
                if [ "$status" == "Showtime" ]; then
                        break
                fi
                sleep 2
        done
}

run_ddns_monitor(){
        cd "${ROOT}/ipchange"
        nohup ./monitor &>/dev/null 2>&1 &
}

# a bug in cm resets the EWAN port status to disabled on each reboot
# since i use it as a normal ethernet port, it must be manually re-enabled
enable_eth5(){
        cmclient SET Device.Ethernet.Interface.5.Enable true
}

sleep 5
chroot $ROOT /bin/sh -c '/init_local.sh'

wait_xdsl_link
run_ddns_monitor
sleep 20
enable_eth5
