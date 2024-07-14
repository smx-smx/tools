#!/bin/bash
export GNUTERM="x11"

function trim(){
	local text="$*"
	echo -ne "${text//[$'\b\t\r\n']}"
}

read -r -d '' adb_script << 'EOF'
while true; do
read uvbatt < /sys/class/power_supply/battery/batt_vol;
echo ${uvbatt};
sleep 1;
done
EOF

adb shell "${adb_script}" | \
	while read line; do
		IFS='-' read -d '' uvbatt < <(trim $line)
		vbatt=$(( $(trim ${uvbatt}) / 1000))
		echo "${vbatt}"
	done | \
feedgnuplot \
	--lines \
	--stream \
	--xlabel seconds \
	--legend 0 "millivolts"
