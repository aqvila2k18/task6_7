#!/bin/bash
modprobe 8021q >> /dev/null 2>&1
s_path=$(cd "$(dirname $0)" && pwd)
source $s_path'/vm1.config'
echo 'source /etc/network/interfaces.d/*' > /etc/network/interfaces
echo 'auto lo' >> /etc/network/interfaces
echo 'iface lo inet loopback' >> /etc/network/interfaces

# Config INTERNAL_IF

echo "auto $INTERNAL_IF" >> /etc/network/interfaces
echo "iface $INTERNAL_IF inet static" >> /etc/network/interfaces
echo "address $INT_IP" >> /etc/network/interfaces

# Config VLAN

echo "auto $INTERNAL_IF.$VLAN" >> /etc/network/interfaces
echo "iface $INTERNAL_IF.$VLAN inet static" >> /etc/network/interfaces
echo "address $VLAN_IP" >> /etc/network/interfaces
echo "vlan_raw_device $INTERNAL_IF" >> /etc/network/interfaces

ip addr flush $EXTERNAL_IF
ip addr flush $INTERNAL_IF
systemctl restart networking.service
