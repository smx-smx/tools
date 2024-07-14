#!/bin/bash
export GNUTERM="x11"

function trim(){
	local text="$*"
	echo -ne "${text//[$'\b\t\r\n']}"
}

read -r -d '' adb_script << 'EOF'
while true; do
read macharge < /sys/class/power_supply/battery/current_now;
echo ${macharge};
sleep 0.2;
done
EOF

adb shell "su -c '${adb_script}'" | \
	while read line; do
		abatt=$(( $(trim ${line}) ))
		echo ${abatt}
	done | \
feedgnuplot \
	--lines \
	--stream \
	--xlabel seconds \
	--legend 0 "charge rate (mA)"
