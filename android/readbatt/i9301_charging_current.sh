#!/bin/bash
export GNUTERM="x11"

function trim(){
	local text="$*"
	echo -ne "${text//[$'\b\t\r\n']}"
}

read -r -d '' adb_script << 'EOF'
while true; do
read uabatt < /sys/class/power_supply/battery/current_now;
echo ${uabatt};
sleep 0.2;
done
EOF

adb shell "${adb_script}" | \
	while read line; do
		abatt=$(( $(trim ${line}) / 1000 ))
		# less than 0    --> charging rate
		# greater than 0 --> discharge rate
		# so we invert it
		echo $(( -${abatt} ))
	done | \
feedgnuplot \
	--lines \
	--stream \
	--xlabel seconds \
	--legend 0 "charge rate (mA)"
