#!/usr/bin/env fish
# First build the image
#   docker build -t ethack/vpn .
# Then
#   cp vpn.fish ~/.config/fish/conf.d/

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
    set httpProxyPort "$HTTP_PROXY_PORT"
    test -n "$httpProxyPort" || set httpProxyPort 1088
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
    set -a dockerCmd "--publish" "$bindIf:$httpProxyPort:3128"
    set -a dockerCmd "--env" "AUTHORIZED_KEYS=$authorizedKeys"
    if test -f "$vpnConfig/$vpnName.ovpn"
        set -a dockerCmd "--mount" "type=bind,src=$vpnConfig/$vpnName.ovpn,dst=/vpn/config,readonly=true"
        set -a vpnCmd "--config" "/vpn/config"
    end
    if test -f "$vpnConfig/$vpnName.creds"
        set -a dockerCmd "--mount" "type=bind,src=$vpnConfig/$vpnName.creds,dst=/vpn/creds,readonly=true"
        set -a vpnCmd "--auth-user-pass" "/vpn/creds"
        set -a vpnCmd "--auth-retry" "interact"
    end
    if test -f "$vpnConfig/$vpnName.env"
        set -a dockerCmd "--env-file" "$vpnConfig/$vpnName.env"
    end
    # add custom hosts
    if test -f "$vpnConfig/$vpnName.hosts"
        set -a dockerCmd (dockervpn-read-hosts "$vpnConfig/$vpnName.hosts")
    end
    # add custom mounts
    if test -f "$vpnConfig/$vpnName.mounts"
        set -a dockerCmd (dockervpn-read-mounts "$vpnConfig/$vpnName.mounts")
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
    echo "HTTP Proxy Port: $httpProxyPort (customize with HTTP_PROXY_PORT)"
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
    set httpProxyPort "$HTTP_PROXY_PORT"
    test -n $httpProxyPort || set httpProxyPort 1088
    set sshPort "$SSH_PORT"
    test -n $sshPort || set sshPort 2222
    set authorizedKeys "$AUTHORIZED_KEYS"

    set vpnConfig "$HOME/.vpn"
    set vpnProfile "$vpnConfig/$vpnName.profile"
    set vpnSecret "$vpnConfig/$vpnName.secret"
    set dockerImage "ethack/vpn"

    # AUTHORIZED_KEYS not specified. Use some defaults.
    if test -z "$authorizedKeys"
        set authorizedKeys (dockervpn-get-authorized-keys | string collect -N)
    end

    set dockerCmd "docker" "run"
    set vpnCmd "openconnect"
    # comment out next line for debugging
    set -a dockerCmd "--rm"
    set -a dockerCmd "--name" "vpn-$vpnName"
    set -a dockerCmd "--hostname" "vpn-$vpnName"
    set -a dockerCmd "--cap-add" "NET_ADMIN"
    set -a dockerCmd "--device" "/dev/net/tun"
    set -a dockerCmd "--publish" "$bindIf:$sshPort:22"
    set -a dockerCmd "--publish" "$bindIf:$socksPort:1080"
    set -a dockerCmd "--publish" "$bindIf:$httpProxyPort:1088"
    set -a dockerCmd "--env" "AUTHORIZED_KEYS=$authorizedKeys"
    if test -f "$vpnConfig/$vpnName.config"
        set -a dockerCmd "--mount" "type=bind,src=$vpnConfig/$vpnName.config,dst=/vpn/openconnect.config,readonly=true"
        set -a vpnCmd "--config" "/vpn/openconnect.config"
    end
    if test -f "$vpnConfig/$vpnName.env"
        set -a dockerCmd "--env-file" "$vpnConfig/$vpnName.env"
    end
    # add custom hosts
    if test -f "$vpnConfig/$vpnName.hosts"
        set -a dockerCmd (dockervpn-read-hosts "$vpnConfig/$vpnName.hosts")
    end
    # add custom mounts
    if test -f "$vpnConfig/$vpnName.mounts"
        set -a dockerCmd (dockervpn-read-mounts "$vpnConfig/$vpnName.mounts")
    end

    if test -f "$vpnProfile"
        # note I keep the quotes, since OC_GROUP might contain spaces
        set OC_HOST (string split '=' -f 2 (grep OC_HOST "$vpnProfile"))
        set OC_USER (string split '=' -f 2 (grep OC_USER "$vpnProfile"))
        set OC_GROUP (string split '=' -f 2 (grep OC_GROUP "$vpnProfile"))

        set -a vpnCmd "$OC_HOST"
        set -a vpnCmd "--user" "$OC_USER"

        if test -n "$OC_GROUP"
            set -a vpnCmd "--authgroup" "$OC_GROUP"
        end
    end

    if test -f "$vpnSecret"
        set -a vpnCmd "--passwd-on-stdin"
    else
        # set -a vpnCmd "--no-passwd"
        # echo "Password not provided, you might need to type it manually"
        # echo "After typing the password, use Ctrl-p + Ctrl-q to detach from docker"
        # echo ""
    end

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
    echo "HTTP Proxy Port: $httpProxyPort (customize with HTTP_PROXY_PORT)"
    echo "Use: ssh $vpnName"
    echo "============================================"
    echo ""

    if test -f "$vpnSecret"
        set -a dockerCmd "--interactive"
        set -a dockerCmd "$dockerImage"
        # debug
        # echo $vpnSecret
        # echo $dockerCmd $vpnCmd
        # this allows typing additional inputs from terminal, e.g., if not all
        # the passwords are provided in the secret file, one can type the
        # additional pin to authenticate
        cat "$vpnSecret" - | $dockerCmd $vpnCmd
    else
        set -a dockerCmd "--interactive" "--tty"
        if test -f "$vpnConfig/$vpnName.mounts"
            grep '/vpn/secret' "$vpnConfig/$vpnName.mounts" > /dev/null
            if test $status -eq 0
                # set -p vpnCmd "cat" "/vpn/secret" "|"
                # This is passed as arguments to this function, not needed here
                # set -a vpnCmd "<" "/vpn/secret"
                # I need to wrap all the commands in one, otherwise pipe (|) or
                # redirect (<) won't work
                # "cat: unrecognized option: config"
                # $vpmCmd contains dash, I need to use -- to indicate string
                # join that do not treat $vpnCmd as arguments
                set vpnCmd "/bin/sh" "-c" (string join -- " " $vpnCmd)
                # use detached mode to release the terminal
                set -a dockerCmd "--detach"
            end
        end
        set -a dockerCmd "$dockerImage"
        # debug
        # echo $dockerCmd $vpnCmd
        $dockerCmd $vpnCmd
    end
end

function dockervpn-read-hosts
    # argv[1] is "$vpnConfig/$vpnName.hosts"
    while read -l line
        # Skip commented lines and empty lines
        if test ! -n $line
            continue
        end
        if string trim $line | string match -q -r '^#'
            continue
        end
        set hostname_ (echo "$line" | awk '{print $2}')
        set ip_ (echo "$line" | awk '{print $1}')
        set -a dockerCmd "--add-host" "$ip_:$hostname_"
        echo "--add-host=$ip_:$hostname_"
    end < $argv[1]
end

function dockervpn-read-mounts
    # argv[1] is "$vpnConfig/$vpnName.mounts"
    while read -l line
        # Skip commented lines and empty lines
        if test ! -n $line
            continue
        end
        if string trim $line | string match -q -r '^#'
            continue
        end
        set file_remote (echo "$line" | awk '{print $2}')
        set file_local (echo "$line" | awk '{print $1}')
        echo "--mount=type=bind,src=$file_local,dst=$file_remote,readonly=true"
    end < $argv[1]
end

function dockervpn-openconnect-new-profile
    echo "This tool will create automatic OpenConnect profile to allow automatic connections"
    echo

    read -P "Name for the profile: " -l vpnProfile
    if ! string match -q -r '^[A-Za-z0-9_]+$' "$vpnProfile"
        echo "Profile name should only contain letters, numbers, and underscores!"
        return 1
    end
    set vpnProfilePath "$HOME/.vpn/$vpnProfile.profile"
    if test -f "$vpnProfilePath"
        echo "Profile \"$vpnProfile\" already exists in $vpnProfilePath"
        return 1
    end

    read -P "Hostname: " -l vpnHost
    read -P "Port [443]: " -l vpnPort
    read -P "Username: " -l vpnUser
    read -P "Password: " -s -l vpnPass
    echo

    set vpnHostPort "$vpnHost"
    if test -n "$vpnPort"
        set -a vpnHostPort "$vpnPort"
    end
    echo
    echo "Some VPNs require group code. Go to https://$vpnHostPort/ and see if there's a \"GROUP\" dropdown present. It will show all possible group codes. If there's no such dropdown leave this field empty."
    read -P "Group: " -l vpnGroup

    echo
    echo "If your VPN requires two-factor authentication you need to specify its type. Usually it will be one of the following: pin, push, phone, sms. If your VPN doesn't use 2FA leave this field empty."
    read -P "2FA Type: " -l vpn2FaType

    printf "OC_HOST='%s'\n" "$vpnHostPort" >> "$vpnProfilePath"
    printf "OC_USER='%s'\n" "$vpnUser" >> "$vpnProfilePath"
    printf "OC_GROUP='%s'\n" "$vpnGroup" >> "$vpnProfilePath"

    set vpnSecretPath "$HOME/.vpn/$vpnProfile.secret"
    echo "$vpnPass" > "$vpnSecretPath"
    if test -n "$vpn2FaType"
        echo "$vpn2FaType" >> "$vpnSecretPath"
    end

    chmod 0400 "$vpnProfilePath"
    chmod 0400 "$vpnSecretPath"

    echo
    echo "Your new profile has been saved in $vpnProfilePath and $vpnSecretPath"
    echo "Connect by typing: openconnect $vpnProfile"
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
    # 1st run to check if there is identity, otherwise ssd-add dump to
    # stdout "The agent has no identities."
    ssh-add -L 1>/dev/null 2>/dev/null
    if test $status -eq 0
        ssh-add -L 2>/dev/null
    end
    # append any public key files found in the user's .ssh directory
    # use `awk NF` instead of cat to remove empty lines
    find "$HOME/.ssh" -type f -name '*.pub' -exec awk NF {} \;
end
