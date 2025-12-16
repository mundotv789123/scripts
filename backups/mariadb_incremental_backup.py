# -*- coding: utf-8 -*-

# ATENÇÃO: Esse é um script experimental não testado em produção
# NÃO POSSUE NENHUMA GARANTIA DE FUNCIONAMENTO E DEVE SER TESTADO E AJUSTADO ANTES DE USAR

import sqlite3
from datetime import datetime
import os
import shutil

input("Esse script não foi testado, realmente deseja continuar?")

backup_dir = "./mysql_backups"
db_user = "root"
days_rotate = 1

if not os.path.exists(backup_dir):
    os.mkdir(backup_dir)

con = sqlite3.connect("database.db")
con.row_factory = sqlite3.Row
cur = con.cursor()

# iniciando banco
cur.execute(
    "CREATE TABLE IF NOT EXISTS migrations(name varchar(64) NOT NULL, executed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)"
)

migrations = {
    "0001_init_db": """CREATE TABLE IF NOT EXISTS backups(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER,
        path VARCHAR(512) NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(parent_id) REFERENCES backups(id) ON DELETE CASCADE
    )"""
}

res = cur.execute("SELECT * FROM migrations")
executed_migrations = res.fetchall()

for migration in migrations.keys():
    if any(filter(lambda v: v["name"] == migration, executed_migrations)):
        continue
    cur.execute(migrations[migration])
    cur.execute("INSERT INTO migrations (name) VALUES (?)", [migration])
    con.commit()
    print(f"migration: '{migration}' success")


# manutenção
deleteds = []
res = cur.execute("SELECT id, parent_id, path FROM backups ORDER BY id ASC")
all_backups = res.fetchall()
for backup in all_backups:
    if not os.path.exists(backup["path"]) or backup["parent_id"] in deleteds:
        deleteds.append(backup["id"])
        cur.execute("DELETE FROM backups WHERE id = ?", [backup["id"]])
        con.commit()
        print(f"not found: {backup['path']}")
        if os.path.exists(backup["path"]):
            shutil.rmtree(backup["path"])
# backup
res = cur.execute(
    """SELECT * 
    FROM backups 
    WHERE parent_id IS NULL 
    AND DATE(created_at) = CURRENT_DATE
    ORDER BY created_at 
    DESC LIMIT 1
"""
)
last_full_backup = res.fetchone()

current_date = datetime.now()

if not last_full_backup:
    path_to_backup = os.path.join(backup_dir, current_date.strftime("%d-%m-%Y_full"))
    res = cur.execute("INSERT INTO backups (path) VALUES (?)", [path_to_backup])
    con.commit()

    command = f"mariadb-backup --backup --target-dir={path_to_backup} --user={db_user}"
else:
    res = cur.execute(
        """SELECT * 
        FROM backups 
        WHERE DATE(created_at) = CURRENT_DATE 
        ORDER BY created_at DESC 
        LIMIT 1
    """
    )
    last_backup = res.fetchone()
    path_last_backup = last_backup["path"]
    path_to_backup = os.path.join(
        backup_dir, current_date.strftime("%d-%m-%Y_%H-%M-%S")
    )
    res = cur.execute(
        "INSERT INTO backups (parent_id, path) VALUES (?, ?)",
        [last_backup["id"], path_to_backup],
    )
    con.commit()

    command = f"mariadb-backup --backup --target-dir={path_to_backup} --incremental-basedir={path_last_backup} --user={db_user}"

if os.path.exists(path_to_backup):
    shutil.rmtree(path_to_backup)

os.system(command)

# expurgo
res = cur.execute(
    f"SELECT * FROM backups WHERE parent_id is null AND DATE(created_at, '+{days_rotate} day') <= CURRENT_DATE"
)
backups_to_delete = res.fetchall()

for backup in backups_to_delete:
    res = cur.execute(
        """
        WITH RECURSIVE tree AS (
            SELECT id, parent_id, path
            FROM backups
            WHERE id = ?

            UNION ALL

            SELECT b.id, b.parent_id, b.path
            FROM backups b
            JOIN tree t ON b.parent_id = t.id
        )
        SELECT * FROM tree
    """,
        [backup["id"]],
    )
    backups_childrens = res.fetchall()
    for children in backups_childrens:
        if os.path.exists(children["path"]):
            shutil.rmtree(children["path"])
        cur.execute("DELETE FROM backups WHERE id = ?", [children["id"]])
        con.commit()
        print(f"{children['path']} {children['id']} deleted")

con.close()
