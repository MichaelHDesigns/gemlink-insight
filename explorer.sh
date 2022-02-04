#!/usr/bin/env bash

D=$PWD

if [ ! -f /swapfile ]; then
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
sudo sh -c "echo '/swapfile none swap sw 0' >> /etc/fstab"
fi

sudo apt-get update

sudo apt-get install \
      build-essential pkg-config libc6-dev m4 g++-multilib \
      autoconf libtool ncurses-dev unzip git python python-zmq \
      zlib1g-dev wget bsdmainutils automake curl apache2 libzmq3-dev

sudo service apache2 start

# install npm and use node v4
cd ..

curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get install nodejs -y

# install ZeroMQ libraries
sudo apt-get -y install libzmq3-dev

# install mongodb
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo service mongod start

# install Gemlink version of bitcore
npm install gemlink/bitcore-node-gemlink

# create bitcore node
./node_modules/bitcore-node-gemlink/bin/bitcore-node create gemlink-explorer
cd gemlink-explorer

# wget -N https://github.com/TENTOfficial/TENT/releases/download/v3.1.1/snowgem-linux-3.1.1.zip -O binary.zip
# unzip -o binary.zip

# install insight api/ui
../node_modules/bitcore-node-gemlink/bin/bitcore-node install gemlink/insight-api-gemlink gemlink/insight-ui-gemlink

# create bitcore config file for bitcore
cat << EOF > bitcore-node.json
{
  "network": "mainnet",
  "port": 3001,
  "services": [
    "bitcoind",
    "insight-api-gemlink",
    "insight-ui-gemlink",
    "web"
  ],
  "servicesConfig": {
    "bitcoind": {
      "spawn": {
        "datadir": "./data",
        "exec": "./gemlinkd"
      }
    },
     "insight-ui-gemlink": {
      "apiPrefix": "api"
     },
    "insight-api-gemlink": {
      "routePrefix": "api"
    }
  }
}
EOF

#need to sync blockchain again with indexed

# create snowgem.conf
cat << EOF > data/gemlink.conf
server=1
whitelist=127.0.0.1
insightexplorer=1
masternodeprotection=1
zmqpubrawtx=tcp://127.0.0.1:8332
zmqpubhashblock=tcp://127.0.0.1:8332
rpcallowip=127.0.0.1
rpcuser=bitcoin
rpcpassword=local321
uacomment=bitcore
showmetrics=0
rpcport=16112
maxconnections=100

EOF

curl https://raw.githubusercontent.com/gemlink/gemlink/master/zcutil/fetch-params.sh > fetch-params.sh
chmod +x fetch-params.sh
./fetch-params.sh

#remove old one
if [ -f /lib/systemd/system/gemlink_insight.service ]; then
  systemctl disable --now gemlink_insight.service
  rm /lib/systemd/system/gemlink_insight.service
fi

echo "Creating service file..."

service="echo '[Unit]
Description=Gemlink Insight - Block Explorer for Gemlink
After=network-online.target

[Service]
User=root
Group=root
Restart=always
RestartSec=30s
WorkingDirectory=/root/gemlink-explorer
ExecStart=/root/gemlink-explorer/node_modules/bitcore-node-gemlink/bin/bitcore-node start
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=gemlink-insight

[Install]
WantedBy=default.target' >> /lib/systemd/system/gemlink_insight.service"

echo $service
sh -c "$service"

cd ~/gemlink-explorer

systemctl enable gemlink_insight.service
systemctl start gemlink_insight.service

echo "Start the block explorer, open in your browser http://server_ip:3001"
# echo "./node_modules/bitcore-node-gemlink/bin/bitcore-node start"
