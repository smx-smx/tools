#!/bin/bash
# Author: Stefano Moioli <smxdev4@gmail.com>

cleanup(){
	if [ ! -z $rtspsrv ]; then
		echo "stop rtsp"
		kill $rtspsrv
	fi
	if [ ! -z $rtpsrv ]; then
		echo "stop rtp"
		kill $rtpsrv
	fi
}

trap cleanup INT TERM

# IP Address of the Android phone running the IP Webcam application
IPCAM_ADDR="192.168.1.12:8080"

# the following pipeline consumes video and audio streams,
# encapsulates each in RTP packets,
# and pipes the resulting RTP data to separate UDP streams
gst-launch-1.0 -v \
souphttpsrc location="http://${IPCAM_ADDR}/video" \
		is-live=true do-timestamp=true \
	! "image/jpeg,framerate=30/1" \
	! jpegparse \
	! rtpjpegpay \
	! udpsink sync=false host=127.0.0.1 port=19090 \
souphttpsrc location="http://${IPCAM_ADDR}/audio.wav" \
	is-live=true do-timestamp=true \
	! wavparse ignore-length=true \
	! audioconvert \
	! rtpL16pay \
	! udpsink sync=false host=127.0.0.1 port=19091 &
rtpsrv=$!
echo "rtp server started: ${rtpsrv}"

pipeline(){
	# sadly, the current rtsp-server implementation expects the final element of these chains to be of type 'GstRTPBasePayload' with name "pay0", "pay1", ..., "payN"
	# this means we cannot pipe the 'udpsrc' as-is, as it wouldn't have the "pt" (payload-type) element, even if the caps-string includes it ("payload=(int)26")
	# we also cannot avoid using RTP in the "sender" pipeline since we need chunking (or the UDP packets might be too big and would be dropped)
	# the workaround i came up with is to add a redundant decode-encode step which likely wastes some time (decode RTP and re-encode it)
	# let me know if you find a better way
	echo udpsrc uri="udp://127.0.0.1:19090" \
		! "application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)JPEG, a-framerate=(string)\"30\,000000\", payload=(int)26" \
		! rtpjpegdepay ! rtpjpegpay name=pay0 \
	udpsrc uri="udp://127.0.0.1:19091" \
		! "application/x-rtp, media=(string)audio, clock-rate=(int)44100, encoding-name=(string)L16, encoding-params=(string)1, channels=(int)1, payload=(int)96" \
		! rtpL16depay ! rtpL16pay name=pay1
}
./rtsp-server.exe "$(pipeline)" &
rtspsrv=$!

wait $rtpsrv
wait $rtspsrv
