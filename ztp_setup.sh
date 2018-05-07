#!/bin/bash

set -e
GOLANG_VERSION=1.9
INTERFACE=ens33
#export PNP_USER=${USER}
export PNP_USER=$1
export PNP_USER_HOME="/home/$PNP_USER"
export PNP_USER_PROFILE="$PNP_USER_HOME/.profile"
export PNP_USER_GOPATH="$PNP_USER_HOME/go"

setupPNPServer() {
    echo "Setting up PNP server ..."

    go get "github.com/golang/protobuf/proto"
    go get "github.com/micro/cli"
    go get "github.com/micro/go-micro"
    go get "github.com/micro/go-grpc"

    mkdir -p $PNP_USER_GOPATH/src/github.com
    cp -r $PNP_USER_HOME/PnP $PNP_USER_GOPATH/src/github.com

    cd $PNP_USER_HOME/PnP/client
    CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o client
    cp client /var/lib/matchbox/assets/coreos/client/    #Triggered from Preseed.cfg on client

    cd $PNP_USER_GOPATH/src/github.com/PnP/util
    echo "Current PnP Directory: $PWD"
    echo "Generating certificates..."
    go run GenerateTLSCertificate.go $INTERFACE
    cp ../certs/server.crt /var/lib/matchbox/assets/coreos/client/
    cd ../server
    IP="$(ifconfig $INTERFACE | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')"
    echo "InterfaceName: $INTERFACE"
    echo "Starting PNP server..."
    go run server.go --registry_address=$IP --server_name "NewPnPService" --package_file "/../config/packageInfo.json" --cert_file "../certs/server.crt" --key_file "../certs/server.key"

    echo "PNP server setup done"
}

setupZTP() {
    #Matchbox setup
    wget https://github.com/coreos/matchbox/releases/download/v0.7.0/matchbox-v0.7.0-linux-amd64.tar.gz
    wget https://github.com/coreos/matchbox/releases/download/v0.7.0/matchbox-v0.7.0-linux-amd64.tar.gz.asc
    tar xzvf matchbox-v0.7.0-linux-amd64.tar.gz
    cp matchbox-v0.7.0-linux-amd64/matchbox /usr/local/bin
    mkdir -p /var/lib/matchbox/assets/coreos/ubuntu
    mkdir -p /var/lib/matchbox/groups/ubuntu
    mkdir -p /var/lib/matchbox/profiles
    mkdir -p /var/lib/matchbox/ignition
    mkdir -p /var/lib/matchbox/assets/coreos/client
    rm -f matchbox-v0.7.0-linux-amd64.tar.gz*
    rm -f matchbox-v0.7.0-linux-amd64.tar.gz.asc*
    rm -rf matchbox-v0.7.0-linux-amd64*
    #Copy base resolv.conf
    cp /etc/resolv.conf /var/lib/matchbox/assets/coreos/client/
    #Dnsmasq setup
    mkdir -p /var/lib/tftpboot
    apt-get -y update && apt-get install -y dnsmasq
    rm -f /etc/dnsmasq.conf
    configure_ZTP_services
}

configure_ZTP_services() {
    mkdir -p $PNP_USER_GOPATH/src/github.com
    cp -r ../ZTP $PNP_USER_GOPATH/src/github.com
    cd $PNP_USER_GOPATH/src/github.com/ZTP/sdp-ztp
    echo "Current Directory: $PWD"
    go run main.go
}

is_go_installed() {
  [ ! -z "$(which go)" ]
}

is_curl_installed() {
    [ ! -z "$(which curl)" ]
}

install_curl() {
    apt-get -y update && apt-get -f install && apt-get -y install curl
}

install_go() {
  echo "Fetching go..."
  mkdir -p "$PNP_USER_GOPATH"

  pushd $(mktemp -d)
    curl -fL -o go.tgz "https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz"
    tar -C . -xzf go.tgz;
    mkdir -p /usr/lib/go-$GOLANG_VERSION
    mv go/* /usr/lib/go-$GOLANG_VERSION
  popd
    ln -s /usr/lib/go-$GOLANG_VERSION /usr/lib/go
    ln -s /usr/lib/go/bin/* /usr/bin/.
}

post_install() {
  echo "go installed..."
  echo "$(go version)"
  update_go_path
}

update_go_path() {
  if ! grep -q GOPATH $PNP_USER_PROFILE; then
    echo "export GOPATH=\"$PNP_USER_GOPATH\"" >> "$PNP_USER_PROFILE"
    echo 'export PATH="$PATH:$GOPATH/bin"' >> "$PNP_USER_PROFILE"
  fi
}

is_git_installed() {
    [ ! -z "$(which git)" ]
}

setupGit() {
  if is_git_installed; then
    echo "A version of git is already installed"
    echo "$(git version)"
  else
    apt-get install -y git
  fi
}

setupCurl() {
  if is_curl_installed; then
    echo "A version of curl is already installed"
    echo "$(curl --version)"
  else
    install_curl
  fi
}

only_run_as_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: must run as privileged user"
        exit 1
    fi
}

setupGo() {
  setupGit
  setupCurl
  if is_go_installed; then
    echo "A version of go is already installed"
    echo "$(go version)"
  else
    install_go
  fi
  post_install
}

setupConsul() {
    echo "Setting up consul"
    apt-get install -y zip
    wget https://releases.hashicorp.com/consul/1.0.7/consul_1.0.7_linux_amd64.zip
    unzip consul_1.0.7_linux_amd64.zip
    rm consul_1.0.7_linux_amd64.zip
    IP="$(ifconfig $INTERFACE | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')"
    ./consul agent -dev -bind=$IP -client $IP -ui -data-dir=/tmp/consul > /dev/null 2>&1 &
    echo "Consul server running"
}

if [ -z "$1" ]
then
    echo "No argument supplied : Pass ${USER} as argument"
    exit 1
fi

only_run_as_root
setupGo
setupZTP
setupConsul
setupPNPServer
