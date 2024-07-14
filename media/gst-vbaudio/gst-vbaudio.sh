#!/bin/sh
cleanup(){
	if [ ! -z $rtpsrv ]; then kill $rtpsrv; fi
}

trap cleanup INT TERM

gst-launch-1.0 -v \
 wasapisrc device="\{0.0.1.00000000\}.\{3b0ac205-7d2e-4c39-82b6-fde906d514bb\}" \
 ! audioconvert \
 ! rtpL16pay \
 ! udpsink host=192.168.0.6 port=9091 &
rtpsrv=$!
echo "rtp server started: ${rtpsrv}"

pipeline(){
	echo udpsrc uri="udp://192.168.0.6:9091" \
		! "application/x-rtp, media=(string)audio, payload=(int)96, clock-rate=(int)48000, encoding-name=(string)L16, encoding-params=(string)2" \
		! queue max-size-buffers=0 name=pay0
}
./rtsp-server.exe "$(pipeline)"
