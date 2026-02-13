# docker build -t ubuntu-vpn .
FROM ubuntu:24.04

RUN apt update && apt -y install \
    openconnect \
    openvpn openssh-client openssh-server \
    python3-pip \
    bind9 bind9-utils bind9-dnsutils bind9-host \
    curl \
    supervisor \
    libxml2 libgtk2.0-bin \
    net-tools iptables network-manager policykit-1
RUN pip install --break-system-packages pproxy[accelerated]

# Fix Cannot open "/proc/sys/net/ipv4/route/flush": Read-only file system
# See https://serverfault.com/questions/878443/when-running-vpnc-in-docker-get-cannot-open-proc-sys-net-ipv4-route-flush 
# RUN rm -f /etc/vpnc/vpnc-script \
#     && wget https://gitlab.com/openconnect/vpnc-scripts/-/raw/master/vpnc-script -O /etc/vpnc/vpnc-script \
#     && chmod +x /etc/vpnc/vpnc-script

# create the root user's .ssh directory
# unlock the root account
RUN mkdir -p /root/.ssh \
    && chmod 0700 /root/.ssh \
    && sed -i 's/^root:*:20299:0:99999:7:::/root::20299:0:99999:7:::/' /etc/shadow

COPY docker-entrypoint.sh /
COPY etc/ssh/sshd_config /etc/ssh/
COPY etc/supervisord.conf /etc/

# COPY cisco-secure-client-linux64-5.1.10.233-core-vpn-webdeploy-k9.sh /cisco.sh
# RUN sh /cisco.sh && rm /cisco.sh

# From https://aur.archlinux.org/packages/cisco-secure-client
# COPY cisco-secure-client-linux64-*.tar.gz /cisco.tar.gz
# RUN tar -xzf /cisco.tar.gz -C /opt && rm /cisco.tar.gz
# RUN cd /opt && mkdir /opt/cisco && mv /opt/cisco-secure-client-linux64*/vpn /opt/cisco/secureclient

# From https://bluelink.ca/ftp/CiscoVPN/
COPY cisco-secure-client-linux64-5.1.12.146-predeploy-deb-k9.tar.gz /cisco.tar.gz
RUN mkdir /tmp_cisco \
    && cd /tmp_cisco \
    && tar -xzf /cisco.tar.gz \
    && dpkg -i cisco-secure-client-vpn-cli_*.deb \
    && cd / \
    && rm -r /tmp_cisco /cisco.tar.gz

ENTRYPOINT ["/docker-entrypoint.sh"]

VOLUME /etc/ssh/
EXPOSE 22
EXPOSE 1080
EXPOSE 1088
