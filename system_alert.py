# -*- coding: utf-8 -*-
# sistema de alerta para gerenciamento de nodes
# aqui você pode configurar um script que fique rodando em um crontab e alerta quando algum recursos é usado mais do que o necessário

#=====================================================
name='' #caso você use o script em mais de um servidor defina um nome para melhor organização
discord_url_webhook='' #insira a url do webhook do discord aqui

hdd_porcent_alert = 85
ram_porcent_alert = 90
load_alert = 20

#lista de hds para monitorar
hds = {
  'Principal': '/'
}
#=====================================================

import requests
import psutil
import os

#funções
def send_notification(message):
  try:
    payload = {'content': message, 'username': 'System Manager (ALERT)', 'avatar_url': 'https://cdn.discordapp.com/attachments/528698938530856961/829879589622120480/alerta.png'}
    x = requests.post(discord_url_webhook, data=payload, timeout=20)
    if (x.status_code != 200 and x.status_code !=204):
      print('Error status code: {0}'.format(x.status_code))
  except:
    print('Error while send wenhook request')

def check_hd(hd_name, path):
  hdd = psutil.disk_usage(path)
  if (hdd.percent >= hdd_porcent_alert):
    send_notification('@everyone **{0}** Ultrapassou {1}% de HD ({2}) {3}%'.format(name, hdd_porcent_alert, hd_name, hdd.percent))

def check_ram():
  ram = psutil.virtual_memory()
  if (ram.percent >= ram_porcent_alert):
    send_notification('@everyone **{0}** Ultrapassou {1}% de RAM {2}%'.format(name, ram_porcent_alert, ram.percent))

def check_load():
  load1, load5, load15 = os.getloadavg()
  if (load1 >= load_alert):
    send_notification('@everyone **{0}** Ultrapassou {1} de Load Average {2}'.format(name, load_alert, load1))

#executando funções
for hd in hds:
  check_hd(hd, hds[hd])

check_ram()

check_load()
