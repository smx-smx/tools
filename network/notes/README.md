# Allow packets originating from the router itself to reach ipsec clients

Apply SNAT to packets originating from the router (`192.168.1.1`) and going to the VPN subnet (`10.10.10.0/24`), so that they will have the proper source address (instead of WAN/IPSEC)

```shell
iptables -t nat -I POSTROUTING -d 10.10.10.0/24 -j SNAT --to-source=192.168.1.1
```

# NAT reflection

Let's say we have a client on the LAN that exposes a public facing service through port forwarding (e.g. a game server)
Then we have another client (which could be the same server) which wants to use the service by using the public-facing (external) IP address, rather than the local IP address (this might be a requirement of the program, to use external IPs).

To make this scenario work, we create an internal NAT rule (PREROUTING) to route the external IP:port to the internal IP that is hosting the service.

Then, we make a MASQUERADE rule to hide the LAN IPs to the server


```shell
wan_addr=foo.dlinkddns.com
lan_port=80
lan_server=192.168.0.123
lan_subnet=192.168.0.0/23
lan_iface=br0
proto=tcp
iptables -t nat -I PREROUTING \
    -p $proto -m $proto \
    -i $lan_iface \
    -s $lan_subnet \
    -d $wan_addr --dport $lan_port \
    -j DNAT --to $lan_server:$lan_port
iptables -t nat -I POSTROUTING \
    -s $lan_subnet -d $lan_server \
    -p $proto -m $proto \
    --dport $lan_port -j MASQUERADE
```
