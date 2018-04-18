#!/bin/bash
modprobe 8021q >> /dev/null 2>&1
s_path=$(cd "$(dirname $0)" && pwd)
source $s_path'/vm1.config'
echo 'source /etc/network/interfaces.d/*' > /etc/network/interfaces
echo 'auto lo' >> /etc/network/interfaces
echo 'iface lo inet loopback' >> /etc/network/interfaces

# config EXTERNAL_IF
if [ $EXT_IP = 'DHCP' ] 
then
echo "auto $EXTERNAL_IF" >> /etc/network/interfaces
echo "iface $EXTERNAL_IF inet dhcp" >> /etc/network/interfaces
else
echo "auto $EXTERNAL_IF" >> /etc/network/interfaces
echo "iface $EXTERNAL_IF inet static" >> /etc/network/interfaces
echo "address $EXT_IP" >> /etc/network/interfaces
echo "gateway $EXT_GW" >> /etc/network/interfaces
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
fi

# config INTERNAL_IF
echo "auto $INTERNAL_IF" >> /etc/network/interfaces
echo "iface $INTERNAL_IF inet static" >> /etc/network/interfaces
echo "address $INT_IP" >> /etc/network/interfaces

# config VLAN
echo "auto $INTERNAL_IF.$VLAN" >> /etc/network/interfaces
echo "iface $INTERNAL_IF.$VLAN inet static" >> /etc/network/interfaces
echo "address $VLAN_IP" >> /etc/network/interfaces
echo "vlan_raw_device $INTERNAL_IF" >> /etc/network/interfaces

ip addr flush $EXTERNAL_IF
ip addr flush $INTERNAL_IF
systemctl restart networking.service

# install nginx
apt-get update >> /dev/null 2>&1
apt-get install nginx -y >> /dev/null 2>&1 

# gen cert
inet=$(ifconfig $EXTERNAL_IF | grep 'inet addr' | awk '{print $2}' | awk -F":" '{print $2}')
fqdn=$(hostname -f)
echo '[req]' > /tmp/openssl.cnf
echo 'prompt = no' >> /tmp/openssl.cnf
echo 'encrypt_key = no' >> /tmp/openssl.cnf
echo 'distinguished_name = dn' >> /tmp/openssl.cnf
echo 'req_extensions = ext' >> /tmp/openssl.cnf
echo '[dn]' >> /tmp/openssl.cnf
echo 'C = UA' >> /tmp/openssl.cnf
echo 'L = Kharkiv' >> /tmp/openssl.cnf
echo "CN = $fqdn" >> /tmp/openssl.cnf
echo 'O = aqvila2k18 Inc' >> /tmp/openssl.cnf
echo '[ext]' >> /tmp/openssl.cnf
echo "subjectAltName = IP:$inet" >> /tmp/openssl.cnf

openssl req -new -newkey rsa:4096 -nodes -keyout /etc/ssl/root-ca.key -x509 -days 180 -subj "/C=UA/ST=Kharkiv/O=aqvila2k18 Cert Service/CN=aqvila2k18 Authority" -out /etc/ssl/certs/root-ca.crt>> /dev/null 2>&1
openssl genrsa -out /etc/ssl/web.key 4096 >> /dev/null 2>&1
openssl req -new -config /tmp/openssl.cnf -newkey rsa:2048 -keyout /etc/ssl/web.key -out /etc/ssl/web.csr >> /dev/null 2>&1
openssl x509 -req -days 30 -in /etc/ssl/web.csr -CA /etc/ssl/certs/root-ca.crt -CAkey /etc/ssl/root-ca.key -set_serial 01 -out /etc/ssl/certs/web.crt -extfile /tmp/openssl.cnf -extensions ext >> /dev/null 2>&1
cat /etc/ssl/certs/root-ca.crt >> /etc/ssl/certs/web.crt
rm /tmp/openssl.cnf

# conf gateway
iptables --flush
iptables --table nat --flush
iptables --delete-chain
iptables --table nat --delete-chain
iptables -A FORWARD -i $EXTERNAL_IF -o $INTERNAL_IF -s $INT_IP -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A POSTROUTING -t nat -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward

# config nginx
cp $s_path'/default' /etc/nginx/sites-enabled/
sed -i "s/APACHE_VLAN_IP/$APACHE_VLAN_IP/" /etc/nginx/sites-enabled/default
sed -i "s/NGINX_PORT/$NGINX_PORT/" /etc/nginx/sites-enabled/default
