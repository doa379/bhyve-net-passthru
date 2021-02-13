#! /bin/sh

apk add wpa_supplicant
wpa_supplicant -i wlan0 -c /mnt/wpa.conf &
udhcpc -i wlan0
cp /mnt/repositories /etc/apk
cp /mnt/interfaces /etc/network
apk update
apk add iptables
apk add ufw
ufw enable
ufw allow from 192.168.0.0/24 to any port 22
ufw allow from 192.168.0.0/24 to any port 2210
ufw allow from 172.24.1.49 to any port 22
ufw reload
/etc/init.d/networking restart
apk add openssh
/etc/init.d/sshd restart
apk add rsync

# Reverse Tunnel ssh (from remote)
# ssh -vfN -R 2210:localhost:22 192.168.0.15