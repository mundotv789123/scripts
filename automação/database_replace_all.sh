#!/bin/bash

# Script basico para mudar automaticamente configurações de banco dados de todos os plugins
# O script procura todos os arquivos .yml e troca as informações inseridas no codigo
# Caso uma informações seja igual a antiga basta repetir no comando
# Caso queira recuperar os aquivos original só executar o reset_old.sh

if [[ !($1 && $2 && $3 && $4 && $5 && $6 && $7 && $8) ]]; then
   echo "usage: ./database_replace_all.sh oldIP newIP oldDB newDB oldUSER newUSER oldPASS newPASS"
   exit 1
fi

# preparando mensagens na mesma linha
OIFS="$IFS"
IFS=$'\n'
# encontrando todos os aquivos .yml
FILES=`find ./ -type f -name "*.yml" -size +0`
for tf in $FILES; do
   echo -ne "\033[1K\r" $tf
   cat $tf | while read line; do
      #verificando se o arquivo tem o antigo ip
      if [[ $line =~ $1 ]]; then 
	      #renomeando arquivos original com .old
	      mv $tf "${tf}.old"
	      cat "${tf}.old" | while read line2; do
	         lin=${line2/$1/$2};
                 lin=${lin/$3/$4};
	         lin=${lin/$5/$6};
	         lin=${lin/$7/$8};
	         echo $lin >> $tf
	      done
	      echo -e " editado!"
	      break
	   fi
   done
done
#finalizando mensagens na mesma linha
IFS="$OIFS"
echo ""
