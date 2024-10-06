#!/bin/bash -e

# CONFIG
API_KEY=''

ZONE_ID=''
RECORD_A_ID=''
RECORD_SRV_ID=''

SUBDOMAIN=''

PORT='22'
NATPMP_GW='10.2.0.1'

PROTOCOL='tcp'
SERVICE='ssh'

SRV_PROTOCOL="_$SERVICE._$PROTOCOL"
CACHE_FILE="./dynv6_natpmp.txt"

# request natpmp
natpmp_result=`natpmpc -g $NATPMP_GW -a $PORT $PORT $PROTOCOL`

external_address=`echo "$natpmp_result" | grep -E '^Public IP address : ([0-9\.]+).*$' | tail -n 1 | sed -E "s/^Public IP address : ([0-9\.]+).*$/\1/g"`
external_port=`echo "$natpmp_result" | grep -E '^Mapped public port ([0-9]+).*$' | tail -n 1 | sed -E "s/^Mapped public port ([0-9]+).*$/\1/g"`

if [[ "$external_address" = "" || "$external_port" = "" ]]; then
  echo "error: address or port could not updated"
  exit 1
fi

# check cache
if [ -e $CACHE_FILE ]; then
  cache_external_address=`cat $CACHE_FILE | head -n 1`
  cache_external_port=`cat $CACHE_FILE | tail -n 1`
  if [[ "$cache_external_address" = "$external_address" && "$cache_external_port" = "$external_port" ]]; then 
    echo "port or address not changed"
    exit 0
  fi
fi

# update dns
if [[ "$cache_external_address" != "$external_address" ]]; then
  curl \
    -d "{\"name\":\"$SUBDOMAIN\",\"data\":\"$external_address\"}" -X PATCH \
    -H "Authorization: Bearer $API_KEY" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "https://dynv6.com/api/v2/zones/$ZONE_ID/records/$RECORD_A_ID"
  echo "address: $external_address updated"
fi

if [[ "$cache_external_port" != "$external_port" ]]; then
  curl \
    -d "{\"name\":\"$SRV_PROTOCOL.$SUBDOMAIN\",\"data\":\"$SUBDOMAIN\",\"priority\":10,\"weight\":0,\"port\":$external_port}" -X PATCH \
    -H "Authorization: Bearer $API_KEY" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "https://dynv6.com/api/v2/zones/$ZONE_ID/records/$RECORD_SRV_ID"
  echo "port: $external_port updated"
fi

# save ache
echo $external_address > $CACHE_FILE
echo $external_port >> $CACHE_FILE

echo "success"