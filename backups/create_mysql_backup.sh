#!/bin/bash

# Script automático para fazer backups de banco de dados de forma organizada
# O script pega todos os bancos de dados, cria um backup deles e compacta separadamente 
# Deve ser usado como sistema secundário de backups apenas para redundância e não como backup principal

DB_USERNAME='admin'
DB_PASSOWRD='senha'
DB_HOST='localhost'

DAYS_ROTATE='5'
BACKUPS_DIR='./mysql_backups'

IGNORE_DATABASES=(
	'information_schema'
	'performance_schema'
)

function ignore_database {
	for name in ${IGNORE_DATABASES[@]}; do
		if [ "$name" == "$1" ]; then
			echo 1
		fi
	done
}

da=$(date +%d-%m-%Y-%H-%M-%S)

if [ ! -d $BACKUPS_DIR ]; then
	mkdir $BACKUPS_DIR
fi

cd $BACKUPS_DIR

mysql -u $DB_USERNAME -p$DB_PASSOWRD -h $DB_HOST -N -e 'show databases' | 

while read dbname; do
	if [ $(ignore_database $dbname) ]; then
		continue
	fi 
	file_name="$da""-$dbname"".sql.gz"
	mysqldump -u $DB_USERNAME -p$DB_PASSOWRD -h $DB_HOST -f "$dbname" | gzip > "$file_name"
	zip -q "$da.zip" "$file_name"
	rm "$file_name"
done

find $BACKUPS_DIR -type f -name '*.zip' -mtime +$DAYS_ROTATE -delete
