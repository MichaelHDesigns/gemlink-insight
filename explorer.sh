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

# install snowgem version of bitcore
npm install snowgem/bitcore-node-snowgem

# create bitcore node
./node_modules/bitcore-node-snowgem/bin/bitcore-node create snowgem-explorer
cd snowgem-explorer

wget -N https://github.com/Snowgem/Snowgem/releases/download/v3000457-20190909/snowgem-ubuntu16.04-3000457-20190926.zip -O binary.zip
unzip -o binary.zip

# install insight api/ui
../node_modules/bitcore-node-snowgem/bin/bitcore-node install snowgem/insight-api-snowgem snowgem/insight-ui-snowgem

# create bitcore config file for bitcore
cat << EOF > bitcore-node.json
{
  "network": "mainnet",
  "port": 3001,
  "services": [
    "bitcoind",
    "insight-api-snowgem",
    "insight-ui-snowgem",
    "web"
  ],
  "servicesConfig": {
    "bitcoind": {
      "spawn": {
        "datadir": "./data",
        "exec": "./snowgemd"
      }
    },
     "insight-ui-snowgem": {
      "apiPrefix": "api"
     },
    "insight-api-snowgem": {
      "routePrefix": "api"
    }
  }
}
EOF

#need to sync blockchain again with indexed

# create snowgem.conf
cat << EOF > data/snowgem.conf
server=1
whitelist=127.0.0.1
txindex=1
addressindex=1
timestampindex=1
masternodeprotection=1
spentindex=1
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

echo "Creating service file..."

service="echo '[Unit]
Description=SnowGem Insight - Block Explorer for Snowgem
After=network-online.target

[Service]
User=root
Group=root
Restart=always
RestartSec=30s
WorkingDirectory=/root/snowgem-explorer
ExecStart=/root/snowgem-explorer/node_modules/bitcore-node-snowgem/bin/bitcore-node start
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=snowgem-insight

[Install]
WantedBy=default.target' >> /lib/systemd/system/snowgem_insight.service"

echo $service
sh -c "$service"

cd ~/snowgem-explorer

echo "Start the block explorer, open in your browser http://server_ip:3001"
# echo "./node_modules/bitcore-node-snowgem/bin/bitcore-node start"
