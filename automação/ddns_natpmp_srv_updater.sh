#!/bin/bash

DNS_SERVER='ns1.dynv6.com'
DNS_KEY='hmac-sha256:tsig-123.dynv6.com YourSHAREDsecret=='

function update_dns_ip {
    zone=$1
    ip_domain=$2
    ip_address=$3

    nsupdate <<EOF
        server $DNS_SERVER
        zone $zone
        update delete $ip_domain A
        update add $ip_domain 60 A $ip_address
        key $DNS_KEY
        send
EOF
}

function update_dns_srv {
    zone=$1
    protocol=$2
    domain=$3
    port=$4
    target=$5

    nsupdate <<EOF
        server $DNS_SERVER
        zone $zone
        update delete $protocol.$domain SRV
        update add $protocol.$domain 60 SRV 10 5 $port $target.
        key $DNS_KEY
        send
EOF
}
