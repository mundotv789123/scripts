#!/bin/bash

# Fez merda com script database_replace_all.sh?
# Esse script recupera todos os arquivos .yml.old

OIFS="$IFS"
IFS=$'\n'
for tf in $(find ./ -type f -name "*.yml.old" -size +0); do
        mv $tf ${tf/.old/""}
done
IFS="$OIFS"
