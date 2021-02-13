#! /bin/sh

ipt=/sbin/iptables

#Local rules
#$ipt -A INPUT -p tcp --dport 22 -s 192.168.0.0/24 -j ACCEPT
#$ipt -A INPUT -p tcp --dport 22 -s 127.0.0.0/8 -j ACCEPT
#$ipt -A INPUT -p tcp --dport 22 -j DROP

# Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
$ipt -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
$ipt -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
$ipt -A FORWARD -i eth0 -o wlan0 -j ACCEPT