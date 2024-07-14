#!/bin/bash
export GNUTERM="x11"

function trim(){
	local text="$*"
	echo -ne "${text//[$'\b\t\r\n']}"
}

read -r -d '' adb_script << 'EOF'
while true; do
read uvbatt < /sys/class/power_supply/battery/voltage_now;
read uabatt < /sys/class/power_supply/battery/current_now;
echo ${uvbatt}-${uabatt};
sleep 1;
done
EOF

adb shell "${adb_script}" | \
	while read line; do
		IFS='-' read -d '' uvbatt uabatt < <(trim $line)
		vbatt=$(( $(trim ${uvbatt}) / 1000))
		abatt=$(( $(trim ${uabatt}) / 1000))
		echo "${vbatt} ${abatt}"
	done | \
feedgnuplot \
	--lines \
	--stream \
	--xlabel seconds \
	--legend 0 "millivolts" \
	--legend 1 "milliamps"
