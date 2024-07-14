#!/bin/bash
export GNUTERM="x11"

function trim(){
	local text="$*"
	echo -ne "${text//[$'\b\t\r\n']}"
}

read -r -d '' adb_script << 'EOF'
while true; do
read uvbatt < /sys/class/power_supply/battery/voltage_now;
echo ${uvbatt};
sleep 0.2;
done
EOF

adb shell "su -c '${adb_script}'" | \
	while read line; do
		vbatt=$(( $(trim ${line}) / 1000))
		echo "${vbatt}"
	done | \
feedgnuplot \
	--lines \
	--stream \
	--xlabel seconds \
	--legend 0 "millivolts"
