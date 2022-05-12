#!/bin/bash -e

apt update
apt install -y python3 python3-pip curl

pip3 install requests
pip3 install psutil

if [ ! -d /root/.scripts ]; then
	mkdir /root/.scripts
fi

curl -o /root/.scripts/system_alert.py https://raw.githubusercontent.com/mundotv789123/scripts/master/system_alert.py
chmod u+x /root/.scripts/system_alert.py

echo "*/15    * * *   root    python3 /root/.scripts/system_alert.py " >> /etc/crontab
