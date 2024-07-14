#!/usr/bin/env bash
# Author: Stefano Moioli <smxdev4@gmail.com>

RTSP_URL="rtsp://127.0.0.1:8554/test"

get_obs_pipeline(){
	echo rtspsrc is-live=true latency=0 \
		location="${RTSP_URL}" name=demux \
	demux. ! rtpjpegdepay ! jpegparse ! jpegdec ! videoconvert ! video. \
	demux. ! rtpL16depay ! audioconvert ! audioresample ! audio.
}

play_gstreamer(){	
	GST_DEBUG=3 gst-launch-1.0 -v rtspsrc is-live=true latency=0 \
		location="${RTSP_URL}" name=demux \
		demux. ! rtpjpegdepay \
			! jpegparse \
			! jpegdec \
			! videoconvert \
			! "video/x-raw, format=(string)BGRA" \
			! autovideosink \
		demux. ! rtpL16depay \
			! audioconvert \
			! audioresample \
			! autoaudiosink
}

play_ffmpeg(){
	ffplay -fflags nobuffer "${RTSP_URL}"
}

method="$1"
case "${method}" in
	obs)
		cat <<-EOS
		===================================================
		== Paste the following pipeline in obs-gstreamer ==
		===================================================

		EOS
		get_obs_pipeline;;
	gst) play_gstreamer;;
	ffplay) play_ffmpeg;;
	*)
		>&2 echo "Usage: $0 [obs|gst|ffplay]"
		exit 1
		;;
esac
