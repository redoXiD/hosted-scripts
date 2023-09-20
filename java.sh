#!/bin/bash
user="$(whoami)"
# Make a scripts directory
mkdir -p "/home/${user}/.local/"
which java || {
    echo "Java not installed..."
    curl -sL "https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz" -o /tmp/jdk.tar.gz
    tar -xvf /tmp/jdk.tar.gz --strip-components=1 -C "/home/${user}/.local/"
    rm /tmp/jdk.tar.gz
    . "/home/${user}/.profile"
}
. /home/${user}/.bashrc
