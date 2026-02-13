#!/bin/sh

if [ -s /root/docker-vpn_keys ]; then
    echo "Copying keys to /root/.ssh/authorized_keys"
    cp -v /root/docker-vpn_keys /root/.ssh/authorized_keys
fi

if [ ! -s /root/.ssh/authorized_keys ]; then
    if [ -z "${AUTHORIZED_KEYS}" ]; then
        echo "Need your ssh public key as AUTHORIZED_KEYS env variable. Abnormal exit ..."
        exit 1
    fi

    echo "Populating /root/.ssh/authorized_keys with the value from AUTHORIZED_KEYS env variable ..."
    echo "${AUTHORIZED_KEYS}" > /root/.ssh/authorized_keys
fi

chown root /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# echo "Generating new host keys as necessary..."
# ssh-keygen -A
echo "Generating new host keys as necessary..."
ssh-keygen -A

# move internal key so that ssh localhost works inside the container
cp /etc/ssh/ssh_host_ed25519_key /root/.ssh/id_ed25519
cat /etc/ssh/ssh_host_ed25519_key.pub >> /root/.ssh/authorized_keys

echo "Starting supervisor..."
/usr/bin/supervisord --configuration=/etc/supervisord.conf --logfile=/dev/null

# https://www.cisco.com/c/en/us/support/docs/security/secure-client-5/223124-configure-secure-client-vpn-for-use-in.html
# Start cisco service
# See supervisord.conf
# echo "Starting Cisco Secure Client service..."
# /opt/cisco/secureclient/bin/vpnagentd

# Cisco client is at /opt/cisco/secureclient/bin/vpn
# Use the following for debugging
# export CSC_LOGGING_OUTPUT=STDOUT

# Execute the command passed to docker (likely a VPN connection command)
exec "$@"
