#!/bin/bash

# Script automático para fazer backups de banco de dados de forma organizada
# O script pega todos os bancos de dados, cria um backup deles e compacta separadamente 
# Deve ser usado como sistema secundário de backups apenas para redundância e não como backup principal

# config
DB_USERNAME='admin'
DB_PASSWORD='password'
DB_HOST='localhost'

DAYS_ROTATE='5'
BACKUPS_DIR='./mysql_backups'

IGNORE_DATABASES=(
	'information_schema'
	'performance_schema'
)

# script
function ignore_database {
	for name in ${IGNORE_DATABASES[@]}; do
		if [ "$name" == "$1" ]; then
			echo 1
		fi
	done
}

da=`date +%d-%m-%Y-%H-%M-%S`

BACKUP_DIR="$BACKUPS_DIR/db_backup_$da"

if [ ! -d $BACKUP_DIR ]; then
	mkdir -p $BACKUP_DIR
fi

mysql -u $DB_USERNAME -p"$DB_PASSWORD" -h $DB_HOST -N -e 'show databases' |

while read -r dbname; do
	if [ `ignore_database $dbname` ]; then
		continue
	fi 
	file_name="$da-$dbname.sql.gz"
	mysqldump -u $DB_USERNAME -p"$DB_PASSWORD" -h $DB_HOST "$dbname" | gzip > "$BACKUP_DIR/$file_name"
done

find "$BACKUPS_DIR" -maxdepth 1 -type d -name 'db_backup_*' -mtime +$DAYS_ROTATE -exec rm -vr {} \;
