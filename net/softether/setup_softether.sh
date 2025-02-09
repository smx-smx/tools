#!/usr/bin/env bash
VPNCMD_BIN=vpncmd

# IP where SoftEther is running
SERVER_IP="192.168.91.129"

SERVER_PASSWORD="sample_password"
HUB_PASSWORD="sample_password"
USER_PASSWORD="sample_password"

HUB_NAME=VPN
TAP_SUFFIX=soft

f_vpncmd(){
	local _saved_value="${MSYS_NO_PATHCONV}"
	# if running on msys, momentarily disable path conversion to treat / as verbatim
	export MSYS_NO_PATHCONV=1
	local cmd=""${VPNCMD_BIN}" "${SERVER_IP}" /SERVER /PROGRAMMING "$@""
	echo "=> $cmd"
	local result="$?"
	${cmd}
	export MSYS_NO_PATHCONV="${_saved_value}"
}

if [ "$1" == "-initial" ]; then
	f_vpncmd /CMD ServerPasswordSet "${SERVER_PASSWORD}"
fi

f_vpncmd /PASSWORD:"${SERVER_PASSWORD}" /IN <<EOF
HubCreate VPN /PASSWORD:"${HUB_PASSWORD}"
HubList
BridgeCreate VPN /DEVICE:soft /TAP:yes
BridgeList
Hub VPN
NatDisable
SecureNatDisable
OpenVpnEnable yes /PORTS:1194
DhcpDisable
UserCreate user /GROUP:none /REALNAME:none /NOTE:none
UserPasswordSet user /PASSWORD:${USER_PASSWORD}

EOF

