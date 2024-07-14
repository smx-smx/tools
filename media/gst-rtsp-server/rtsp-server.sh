#!/usr/bin/env sh
libs="gstreamer-rtsp-server-1.0 gstreamer-1.0 glib-2.0"
gcc `pkg-config --cflags $libs` rtsp-server.c -o rtsp-server `pkg-config --libs $libs`
