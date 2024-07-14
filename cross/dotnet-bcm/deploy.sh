#!/bin/bash
echo "==> Runtime"
scp artifacts/bin/runtime/net6.0-Linux-Release-armel/*.{dll,so} root@192.168.1.1:/mnt/sda1/netcore/runtime/
echo "==> Mono Libraries"
scp artifacts/bin/mono/Linux.armel.Release/*.{so,dll} root@192.168.1.1:/mnt/sda1/netcore/runtime/
echo "==> Mono Binary"
scp artifacts/obj/mono/Linux.armel.Release/out/bin/mono-sgen root@192.168.1.1:/mnt/sda1/netcore/mono-sgen
