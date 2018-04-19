#!/bin/bash
modprobe 8021q >> /dev/null 2>&1
s_path=$(cd "$(dirname $0)" && pwd)
source $s_path'/vm2.config'
echo 'source /etc/network/interfaces.d/*' > /etc/network/interfaces
echo 'auto lo' >> /etc/network/interfaces
echo 'iface lo inet loopback' >> /etc/network/interfaces

# config INTERNAL_IF
echo "auto $INTERNAL_IF" >> /etc/network/interfaces
echo "iface $INTERNAL_IF inet static" >> /etc/network/interfaces
echo "address $INT_IP" >> /etc/network/interfaces
echo "gateway $GW_IP" >> /etc/network/interfaces
echo "nameserver $GW_IP" >> /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf

# config VLAN
echo "auto $INTERNAL_IF.$VLAN" >> /etc/network/interfaces
echo "iface $INTERNAL_IF.$VLAN inet static" >> /etc/network/interfaces
echo "address $APACHE_VLAN_IP" >> /etc/network/interfaces
echo "vlan_raw_device $INTERNAL_IF" >> /etc/network/interfaces

ip addr flush $INTERNAL_IF.$VLAN
ip addr flush $INTERNAL_IF
systemctl restart networking.service

# install apache2
ping -c 5 -W 1 www.google.com
apt-get update >> /dev/null 2>&1
apt-get install apache2 -y >> /dev/null 2>&1
vsi=$(echo $APACHE_VLAN_IP | awk -F"/" '{print $1}')
sed -i "s/Listen 80/Listen $vsi:80/" /etc/apache2/ports.conf
service apache2 restart
