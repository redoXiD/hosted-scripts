#!/bin/bash
# thx flyingsausages and swizzin team
export user=$(whoami)
mkdir -p ~/.logs/
touch ~/.logs/overseerr.log
export log="$HOME/.logs/overseerr.log"

function _deps() {
    ## Function for installing nvm.
    if [[ ! -d /home/$user/.nvm ]]; then
        echo "Installing node"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash >> "$log" 2>&1
        echo "nvm installed."
    else
        echo "nvm is already installed."
    fi
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    nvm install --lts >> "$log" 2>&1 || {
        echo "node failed to install"
        exit 1
    }
    echo "Node LTS installed."
    echo "Installing Yarn"
    npm install -g yarn >> "$log" 2>&1 || {
        echo "Yarn failed to install"
        exit 1
    }
    echo "Yarn installed."
}

function _overseer_install() {
    echo "Downloading and extracting source code"
    dlurl="$(curl -sS https://api.github.com/repos/sct/overseerr/releases/latest | jq .tarball_url -r)"
    wget "$dlurl" -q -O /home/${user}/scripts/overseerr.tar.gz >> "$log" 2>&1 || {
        echo "Download failed"
        exit 1
    }
    mkdir -p ~/scripts/overseerr
    tar --strip-components=1 -C ~/scripts/overseerr -xzvf /home/${user}/scripts/overseerr.tar.gz >> "$log" 2>&1
    rm /home/${user}/scripts/overseerr.tar.gz
    echo "Code extracted"

    # Changing baseurl before build
    # export OVERSEERR_BASEURL='/baseurl'

    echo "Installing dependencies via yarn"
    # Ensure sqlite can build right in case it needs to use python
    if ! which python >> "$log" 2>&1; then #TODO make this a more specific check as this could interfere with other things possibly
        npm config set python "$(which python3)"
    fi
    yarn install --cwd ~/scripts/overseerr >> "$log" 2>&1 || {
        echo "Failed to install dependencies"
        exit 1
    }
    echo "Dependencies installed"

    echo "Building overseerr"
    yarn --cwd ~/scripts/overseerr build >> "$log" 2>&1 || {
        echo "Failed to build overseerr sqlite"
        exit 1
    }
    echo "Succesfully built"
}

function _port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _service() {
    mkdir -p "/home/$user/.config/systemd/user/"
    mkdir -p "/home/$user/.install/"
    mkdir -p "/home/$user/.config/scripts/overseerr/"
    # Adapted from https://aur.archlinux.org/cgit/aur.git/tree/overseerr.service?h=overseerr
    cat > ~/.config/systemd/user/scripts-overseerr.service << EOF
[Unit]
Description=Overseerr Service
Wants=network-online.target
After=network-online.target
[Service]
EnvironmentFile=/home/$user/scripts/overseerr/env.conf
Environment=NODE_ENV=production
Type=exec
Restart=on-failure
WorkingDirectory=/home/$user/scripts/overseerr
ExecStart=$(which node) dist/index.js
[Install]
WantedBy=multi-user.target
EOF
    port=$(_port 1000 18000)
    cat > ~/scripts/overseerr/env.conf << EOF
# specify on which port to listen
PORT=$port
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now -q scripts-overseerr
    touch ~/.install/.scripts-overseerr.lock
    echo "Overseerr is up and running on http://$(hostname -f):$port/overseerr"

}

function _remove() {
    systemctl --user disable --now scripts-overseerr
    sleep 2
    rm -rf ~/scripts/overseerr
    rm -rf ~/.config/scripts/overseerr
    rm -rf ~/.config/systemd/user/scripts-overseerr.service
    rm -rf ~/.install/.scripts-overseerr.lock
}

echo 'This is unsupported software. You will not get help with this, please answer `yes` if you understand and wish to proceed'
if [[ -z ${eula} ]]; then
    read -r eula
fi

if ! [[ $eula =~ yes ]]; then
  echo "You did not accept the above. Exiting..."
  exit 1
else
  echo "Proceeding with installation"
fi

echo "Welcome to the Overseerr installer..."
echo ""
echo "What do you like to do?"
echo ""
echo "install = Install Overseerr"
echo "uninstall = Completely removes Overseerr"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            clear
            _deps
            _overseer_install
            _service
            break
            ;;
        "uninstall")
            _remove
            break
            ;;
        "exit")
            break
            ;;
        *)
            echo "Unknown Option."
            ;;
    esac
done
exit
