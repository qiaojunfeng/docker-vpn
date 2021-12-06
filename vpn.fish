#!/usr/bin/env fish

function dockervpn-openvpn  --description "Use openvpn in docker-vpn"
    set vpnName "$argv[1]"
    if test -z "$vpnName"
        echo "VPN name must be provided"
        return
    end
    # listen on localhost by default
    set bindIf "$BIND_INTERFACE"
    test -n "$bindIf" || set bindIf 127.0.0.1
    set socksPort "$SOCKS_PORT"
    test -n "$socksPort" || set socksPort 1080
    set sshPort "$SSH_PORT"
    test -n "$sshPort" || set sshPort 2222
    set authorizedKeys "$AUTHORIZED_KEYS"
    
    set vpnConfig "$HOME/.vpn"
    set dockerImage "ethack/vpn"
    
    # AUTHORIZED_KEYS not specified. Use some defaults.
    if test -z "$authorizedKeys"
        set authorizedKeys (dockervpn-get-authorized-keys | string collect -N)
    end

    set dockerCmd "docker" "run"
    set vpnCmd "openvpn"
    set -a dockerCmd "--rm" "--name" "vpn-$vpnName"
    set -a dockerCmd "--hostname" "vpn-$vpnName"
    set -a dockerCmd "--interactive" "--tty"
    set -a dockerCmd "--cap-add" "NET_ADMIN"
    set -a dockerCmd "--device" "/dev/net/tun"
    set -a dockerCmd "--publish" "$bindIf:$sshPort:22"
    set -a dockerCmd "--publish" "$bindIf:$socksPort:1080"
    set -a dockerCmd "--env" "AUTHORIZED_KEYS=\"$authorizedKeys\""
    if test -f "$vpnConfig/$vpnName.ovpn"
        set -a dockerCmd "--mount" "type=bind,src=$vpnConfig/$vpnName.ovpn,dst=/vpn/config,readonly=true"
        set -a vpnCmd "--config" "/vpn/config"
    end
    if test -f "$vpnConfig/$vpnName.creds"
        set -a dockerCmd "--mount" "type=bind,src=$vpnConfig/$vpnName.creds,dst=/vpn/creds,readonly=true"
        set -a vpnCmd "--auth-user-pass" "/vpn/creds"
        set -a vpnCmd "--auth-retry" "interact"
    end
    set -a dockerCmd "$dockerImage"

    # append any extra args provided
    set -a vpnCmd $argv[2..]
    # display help if there are no arguments at this point
    if test (count $vpnCmd) -eq 1
        set -a vpnCmd "--help"
    end

    dockervpn-setup-ssh-config.d
    dockervpn-ssh-config "$vpnName" "$sshPort" > "$HOME/.ssh/config.d/vpn-$vpnName"
    chmod 600 "$HOME/.ssh/config.d/vpn-$vpnName"

    echo "============================================"
    echo "SSH Port: $sshPort (customize with SSH_PORT)"
    echo "SOCKS Proxy Port: $socksPort (customize with SOCKS_PORT)"
    echo "Use: ssh $vpnName"
    echo "============================================"

    $dockerCmd $vpnCmd
end

function dockervpn-openconnect  --description "Use openconnect in docker-vpn"
    set vpnName "$argv[1]"
    if test -z "$vpnName"
        echo "VPN name must be provided"
        return
    end
    # listen on localhost by default
    set bindIf "$BIND_INTERFACE"
    test -n $bindIf || set bindIf 127.0.0.1
    set socksPort "$SOCKS_PORT"
    test -n $socksPort || set socksPort 1080
    set sshPort "$SSH_PORT"
    test -n $sshPort || set sshPort 2222
    set authorizedKeys "$AUTHORIZED_KEYS"
    
    set vpnConfig "$HOME/.vpn"
    set dockerImage "ethack/vpn"
    
    # AUTHORIZED_KEYS not specified. Use some defaults.
    if test -z "$authorizedKeys"
        set authorizedKeys (dockervpn-get-authorized-keys | string collect -N)
    end

    set dockerCmd "docker" "run"
    set vpnCmd "openconnect"
    set -a dockerCmd "--rm" "--name" "vpn-$vpnName"
    set -a dockerCmd "--hostname" "vpn-$vpnName"
    set -a dockerCmd "--interactive" "--tty"
    set -a dockerCmd "--cap-add" "NET_ADMIN"
    set -a dockerCmd "--device" "/dev/net/tun"
    set -a dockerCmd "--publish" "$bindIf:$sshPort:22"
    set -a dockerCmd "--publish" "$bindIf:$socksPort:1080"
    set -a dockerCmd "--env" "AUTHORIZED_KEYS=\"$authorizedKeys\""
    if test -f "$vpnConfig/$vpnName.xml"
        set -a dockerCmd "--mount" "type=bind,src=$vpnConfig/$vpnName.xml,dst=/vpn/config,readonly=true"
        set -a vpnCmd "--xmlconfig" "/vpn/config"
    end
    set -a dockerCmd "$dockerImage"

    # append any extra args provided
    set -a vpnCmd $argv[2..]
    # display help if there are no arguments at this point
    if test (count $vpnCmd) -eq 1
        set -a vpnCmd "--help"
    end

    dockervpn-setup-ssh-config.d
    dockervpn-ssh-config "$vpnName" "$sshPort" > "$HOME/.ssh/config.d/vpn-$vpnName"
    chmod 600 "$HOME/.ssh/config.d/vpn-$vpnName"

    echo "============================================"
    echo "SSH Port: $sshPort (customize with SSH_PORT)"
    echo "SOCKS Proxy Port: $socksPort (customize with SOCKS_PORT)"
    echo "Use: ssh $vpnName"
    echo "============================================"

    $dockerCmd $vpnCmd
end

# Create and configure the .ssh/config.d directory if it's not already
function dockervpn-setup-ssh-config.d
    if ! grep -qFi -e 'Include config.d/*' -e 'Include ~/.ssh/config.d/*' "$HOME/.ssh/config"
        echo >> "$HOME/.ssh/config"
        # This allows the Include to be at the end of the file (i.e. not nested in a Host directive)
        echo 'Match all' >> "$HOME/.ssh/config"
        echo 'Include config.d/*' >> "$HOME/.ssh/config"
    end
    mkdir -p "$HOME/.ssh/config.d/"
end

# Print the SSH config entry for the given name and port
function dockervpn-ssh-config
    set name "$argv[1]"
    set sshPort "$argv[2]"
    set user "root"
    set host "127.0.0.1"

    echo "\
Host vpn-$name $name
    Hostname $host
    User $user
    Port $sshPort
    NoHostAuthenticationForLocalhost yes
\
"
end

function dockervpn-get-authorized-keys
    set authorizedKeys ""
    # add any key allowed to ssh in as the current user
    if test -f "$HOME/.ssh/authorized_keys"
        cat "$HOME/.ssh/authorized_keys"
    end
    # add all keys currently registered with ssh-agent
    ssh-add -L 2>/dev/null
    # append any public key files found in the user's .ssh directory
    find "$HOME/.ssh/" -type f -name '*.pub' -exec cat {} \;
end
