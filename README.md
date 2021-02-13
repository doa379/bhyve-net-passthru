This is a prescription to setup a LinuxVM on a FreeBSD host using Bhyve, and then to passthrough network traffic from the VM to the host.
The motivation for doing this is to be able to give the FreeBSD host gateway access over WIFI using the Linux VM. 
I am using an Intel 8260 WIFI chipset. The hardware platform is supported under FreeBSD. However connection protocols are limited to 802.11g (54Mbps). 
The platform however has a supported ecosystem under Linux and that allows WIFI connections over the 802.11n band for faster speeds. 
The prescription for this setup is as follows:

1. Setup a LinuxVM (client) under FreeBSD (host) using Bhyve
2. Disable WIFI adapter under host
3. Give the client full access to WIFI adapter
4. Create a bridge and tap device under host
5. Configure host gateway to the birdge
6. Configure client to access WIFI
7. Create a static network interface on the client
8. Passthrough network traffic on the client from the WIFI adapter to the static network interface.

## A. Prerequisites

References:

https://docs.freebsd.org/en/books/handbook/virtualization/#virtualization-host-bhyve

https://www.davidschlachter.com/misc/t480-bhyve-wifi-pci-passthrough

I will be using Alpine Linux as the client. The distribution is small and simple using busybox and will run in under 196MB of RAM, with one vcore.
https://alpinelinux.org/downloads/
NB. With a 64-bit host one will need to use a 64-bit client too. A 32-bit (x86) client fails to run on a x86-64 host. 

## B. Configure Host

We need grub2-bhyve:

`$ sudo pkg install grub2-bhyve`

The client will be spawned using the `vm_run` script. The client will be killed using the `vm_kill` script. The file `device map` must contain the
path and filename to the client iso. We simply boot the iso in RAM and won't be installing anything. 
`-s 3,ahci-cd,/mnt/alpine-standard-3.13.0-x86_64.iso`
There is one caveat however, that Bhyve still needs a vdisk image in order to boot (even though we won't be using it).
`-s 4,virtio-blk,/mnt/vm_bhyve/linuxguest/disk0.img`
Creation of a vdisk is described in the FreeBSD wiki link (above) using the `truncate` program.
We passthrough the network adapter (number 4 in this case) using the argument `-s 5,passthru,4/0/0`
The pci address of the adapter on the host can be found using `sudo pciconf -lv`.

We then have to add the following entries to `/boot/loader.conf`:

```
vmm_load="YES"
nmdm_load="NO"
if_bridge_load="YES"
if_tap_load="YES"
pptdevs="4/0/0"                 #Corresponding to PCI address of net adapter
```

In order to configure networking we will set the following entries in `/etc/rc.conf`:

```
#Disable any local networking
#wpa_supplicant_enable="YES"
#synchronous_dhclient="YES"
#wlans_iwm0="wlan0"
#ifconfig_wlan0="WPA DHCP"
#create_args_wlan0="country GB"
#netwait_enable="YES"           # Enable rc.d/netwait (or NO)
#netwait_if="wlan0"             # Wait for active link on each intf in this list.
#netwait_if_timeout="60"        # Total number of seconds to monitor link state.
firewall_enable="NO"
firewall_type="simple"

#vm_enable="NO"                 # Setting for vm-bhyve management system
#vm_dir="/mnt/vm_bhyve"         # Setting for vm-bhyve management system
cloned_interfaces="bridge0 tap0"
ifconfig_bridge0="inet 172.24.1.49 netmask 255.255.255.0 addm tap0 up"
defaultrouter="172.24.1.1"
```

Also set in `/etc/sysctl.conf`: `net.link.tap.up_on_open=1`

`ifconfig -a` thus shows the following configuration:

```
em0: flags=8802<BROADCAST,SIMPLEX,MULTICAST> metric 0 mtu 1500
        options=81249b<RXCSUM,TXCSUM,VLAN_MTU,VLAN_HWTAGGING,VLAN_HWCSUM,LRO,WOL_MAGIC,VLAN_HWFILTER>
        ether c8:5b:76:91:21:b4
        media: Ethernet autoselect
        status: no carrier
        nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> metric 0 mtu 16384
        options=680003<RXCSUM,TXCSUM,LINKSTATE,RXCSUM_IPV6,TXCSUM_IPV6>
        inet6 ::1 prefixlen 128
        inet6 fe80::1%lo0 prefixlen 64 scopeid 0x2
        inet 127.0.0.1 netmask 0xff000000
        groups: lo
        nd6 options=21<PERFORMNUD,AUTO_LINKLOCAL>
bridge0: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500
        ether 02:32:7d:a2:b5:00
        inet 172.24.1.49 netmask 0xffffff00 broadcast 172.24.1.255
        id 00:00:00:00:00:00 priority 32768 hellotime 2 fwddelay 15
        maxage 20 holdcnt 6 proto stp-rstp maxaddr 2000 timeout 1200
        root id 00:00:00:00:00:00 priority 32768 ifcost 0 port 0
        member: tap0 flags=143<LEARNING,DISCOVER,AUTOEDGE,AUTOPTP>
                ifmaxaddr 0 port 4 priority 128 path cost 2000000
        groups: bridge
        nd6 options=9<PERFORMNUD,IFDISABLED>
tap0: flags=8943<UP,BROADCAST,RUNNING,PROMISC,SIMPLEX,MULTICAST> metric 0 mtu 1500
        options=80000<LINKSTATE>
        ether 58:9c:fc:10:ff:fa
        groups: tap
        media: Ethernet autoselect
        status: active
        nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>
        Opened by PID 1660
```

The host will have a local IP address of 172.24.1.49. The client will be on 172.24.1.1.


## C. Configure Client

We won't be using the vdisk for any installation as we'll be running the client from RAM. We will however use the vdisk for a
persistant configuration. After booting and logging into the client the `run.sh` script prepares the client's configuration. The WIFI adapter
appears as `wlan0` and the bridge/tap device as `eth0`.

```
eth0      Link encap:Ethernet  HWaddr 00:A0:98:D2:16:22  
          inet addr:172.24.1.1  Bcast:0.0.0.0  Mask:255.255.255.0
          inet6 addr: fe80::2a0:98ff:fed2:1622/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:274778754 errors:0 dropped:0 overruns:0 frame:0
          TX packets:368519079 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:59858515881 (55.7 GiB)  TX bytes:240310573907 (223.8 GiB)

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:837762 errors:0 dropped:0 overruns:0 frame:0
          TX packets:837762 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:7760999674 (7.2 GiB)  TX bytes:7760999674 (7.2 GiB)

wlan0     Link encap:Ethernet  HWaddr F0:D5:BF:1B:E2:16  
          inet addr:192.168.0.21  Bcast:0.0.0.0  Mask:255.255.255.0
          inet6 addr: fe80::f2d5:bfff:fe1b:e216/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:364593421 errors:0 dropped:18466 overruns:0 frame:0
          TX packets:247868138 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:240023131195 (223.5 GiB)  TX bytes:64574345178 (60.1 GiB)
```

The `nat.sh` forwards everything from `wlan0` to `eth0` and vice versa.


## D. SSHing

It's possible to log into the client via ssh, but since the host is now on another network, we need to forward ssh connections.
First we need to make sure that `/etc/ssh/sshd_config` has enabled `AllowTcpForwarding yes` on the host as well as on the client.
Also set `GatewayPorts yes` on the client. Then on the host run `ssh -vfN -R 2210:localhost:22 192.168.0.21`. 
The host will then be available on port 2210 on the client's network.
