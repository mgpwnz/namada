#!/bin/bash
# Default variables
function="install"
NAMADA_TAG="v0.31.2"
NAMADA_CHAIN_ID="shielded-expedition.88f17d1d14"
# Options
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
        case "$1" in
        -in|--install)
            function="install"
            shift
            ;;
        -un|--uninstall)
            function="uninstall"
            shift
            ;;
	    -up|--update)
            function="update"
            shift
            ;;
        *|--)
		break
		;;
	esac
done
install() {
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
	    . $HOME/.bash_profile
fi
if ss -tulpen | awk '{print $5}' | grep -q ":26656$" ; then
        echo -e "\e[31mInstallation is not possible, port 26656 already in use.\e[39m"
        exit
else
        echo "Preparing..."
fi
rm -rf $HOME/.masp-params

if [ ! $VALIDATOR_ALIAS ]; then
	read -p "Enter validator name: " VALIDATOR_ALIAS
	echo 'export VALIDATOR_ALIAS='\"${VALIDATOR_ALIAS}\" >> $HOME/.bash_profile
fi
if [ ! $EMAIL ]; then
        read -p "Enter your email address: " EMAIL
        echo 'export EMAIL='\"${EMAIL}\" >> $HOME/.bash_profile
fi
echo 'source $HOME/.bashrc' >> $HOME/.bash_profile
. $HOME/.bash_profile
sleep 1
cd $HOME
sudo apt update
sudo apt install make unzip clang pkg-config git-core libudev-dev libssl-dev build-essential libclang-12-dev git jq ncdu bsdmainutils htop -y < "/dev/null"


echo -e '\n\e[42mInstall Rust\e[0m\n' && sleep 1
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

echo -e '\n\e[42mInstall libprotoc 3.12.0\e[0m\n' && sleep 1
if ! command -v protoc; then
    curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v3.12.0/protoc-3.12.0-linux-x86_64.zip
    unzip -o protoc-3.12.0-linux-x86_64.zip -d $HOME/.local
    echo 'export PATH=$PATH:'"$HOME/.local/bin" >> $HOME/.bash_profile
    source $HOME/.bash_profile    
elif [ "$(protoc --version | awk '{print $NF}')" != "3.12.0" ]; then
    sudo apt remove libprotoc-dev -y
    sudo rm -f $(which protoc)	
    curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v3.12.0/protoc-3.12.0-linux-x86_64.zip
    unzip -o protoc-3.12.0-linux-x86_64.zip -d $HOME/.local
    echo 'export PATH=$PATH:'"$HOME/.local/bin" >> $HOME/.bash_profile
    source $HOME/.bash_profile
else
    echo "Protocol Buffers already installed"
fi

echo -e '\n\e[42mInstall Go\e[0m\n' && sleep 1
VERSION=1.20.5
wget -O go.tar.gz https://go.dev/dl/go$VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go.tar.gz && rm go.tar.gz
echo 'export GOROOT=/usr/local/go' >> $HOME/.bash_profile
echo 'export GOPATH=$HOME/go' >> $HOME/.bash_profile
echo 'export GO111MODULE=on' >> $HOME/.bash_profile
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile && . $HOME/.bash_profile
go version

echo -e '\n\e[42mInstall software\e[0m\n' && sleep 1
mkdir -p $HOME/cometbft_bin
cd $HOME/cometbft_bin
wget -O cometbft.tar.gz https://github.com/cometbft/cometbft/releases/download/v0.37.2/cometbft_0.37.2_linux_amd64.tar.gz
tar xvf cometbft.tar.gz
sudo chmod +x cometbft
sudo mv ./cometbft /usr/local/bin/

cd $HOME
rm -rf namada
git clone https://github.com/anoma/namada 
cd namada 
git checkout $NAMADA_TAG
make build-release
sudo mv target/release/namada /usr/local/bin/
sudo mv target/release/namada[c,n,w] /usr/local/bin/
cd $HOME
namada client utils join-network --chain-id $NAMADA_CHAIN_ID
sleep 3
echo "[Unit]
Description=Namada Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/.local/share/namada
Type=simple
ExecStart=/usr/local/bin/namadan ledger run
Environment=NAMADA_LOG=info
Environment=NAMADA_CMT_STDOUT=true
Environment=CMT_LOG_LEVEL=p2p:none,pex:error
LimitSTACK=infinity
RemainAfterExit=no
Restart=always
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > $HOME/namadad.service
sudo mv $HOME/namadad.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
echo -e '\n\e[42mRunning a service\e[0m\n' && sleep 1
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable namadad
sudo systemctl restart namadad

echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
if [[ `service namadad status | grep active` =~ "running" ]]; then
        echo -e "Your namada node \e[32minstalled and works\e[39m!"
        echo -e "You can check node status by the command \e[7mservice namadad status\e[0m"
        echo -e "Press \e[7mQ\e[0m for exit from status menu"
      else
        echo -e "Your namada node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
}
uninstall() {
read -r -p "You really want to delete the node? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
    sudo systemctl disable namadad.service
    sudo rm /etc/systemd/system/namadad.service
    sudo rm /usr/local/bin/namadan
    sudo rm -rf $HOME/namada $HOME/.local/share/namada
    echo "Done"
    cd $HOME
    ;;
    *)
        echo Сanceled
        return 0
        ;;
esac
}

update() {
##   rm -rf namada
#    git clone https://github.com/anoma/namada 
#    cd namada 
#    git checkout $NAMADA_TAG
#    make build-release
#    sudo mv target/release/namada /usr/local/bin/
#    sudo mv target/release/namada[c,n,w] /usr/local/bin/
#    cd $HOME
#    namada client utils join-network --chain-id $NAMADA_CHAIN_ID
#    sudo systemctl restart namadad
#    echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
#    if [[ `service namadad status | grep active` =~ "running" ]]; then
#            echo -e "Your namada node \e[32minstalled and works\e[39m!"
#            echo -e "You can check node status by the command \e[7mservice namadad status\e[0m"
#            echo -e "Press \e[7mQ\e[0m for exit from status menu"
#        else
#            echo -e "Your namada node \e[31mwas not installed correctly\e[39m, please reinstall."
#    fi
}
# Actions
sudo apt install wget -y &>/dev/null
cd
$function