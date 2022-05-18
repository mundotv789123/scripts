# -*- coding: utf-8 -*-

# sistema de monitoramento de rede com alertas no discord
# esse script monitora endereços ip usando ping ou requisição http/https, quando acontece uma variação ele notifica no discord
# lembre-se de usar esse script em crontab

#=====================================================
discord_url_webhook='' #insira a url do webhook do discord aqui
services_file='services.json'
# exemplo do que deve conter no services.json
#[
#    {
#        "ip": "127.0.0.1",
#        "name": "localhost",
#        "online": true
#    },
#    {
#        "url": "http://localhost",
#        "name": "localhost http",
#        "online": true
#    }
#]
#=====================================================

import requests
import json
import os

mdir = os.path.dirname(__file__)
if (mdir != ''):
	os.chdir(mdir)

def testePing(ip):
	response = os.system("ping -c 1 -W 1 {0} > /dev/null".format(ip))
	return response == 0

def sendRequest(url):
	try:
		x = requests.get(url, timeout=2)
		return (x.status_code == 200)
	except:
		return False

def sendMessage(message):
	try:
		x = requests.post(discord_url_webhook, data={'content': message}, timeout=20)
		return (x.status_code == 200 or x.status_code == 204)
	except:
		return False

file = open(services_file, 'r')
services = json.load(file)

edited=False

for service in services:
	if not ('online' in service) or not ('name' in service):
		continue
	online = False
	if ('url' in service):
		online = sendRequest(service['url'])
	elif ('ip' in service):
		online = testePing(service['ip'])
	else:
		continue

	if (online != service['online']) and (sendMessage('@everyone [**{0}**] Ficou {1}'.format(service['name'], ('online [:white_check_mark:]' if online else 'offline [:warning:]')))):
		edited=True
		service['online'] = online

if edited:
	file = open(services_file, 'w')
	file.write(json.dumps(services, sort_keys=True, indent=4))
