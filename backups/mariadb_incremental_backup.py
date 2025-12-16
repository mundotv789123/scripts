# -*- coding: utf-8 -*-

# ATENÇÃO: Esse é um script experimental não testado em produção
# NÃO POSSUE NENHUMA GARANTIA DE FUNCIONAMENTO E DEVE SER TESTADO E AJUSTADO ANTES DE USAR

# Script de backups de banco de dados mariadb incremental
# A função desse script é gerenciar backups incrementais usando mariadb-backup, ele cria, associa e expurga backups
# Sua principal vantagem é poder ter vários backups ao longo do dia de forma eficiente

import sqlite3
from datetime import datetime
import os
import shutil
import subprocess

input("Esse script não foi testado, realmente deseja continuar?") #TODO remover após finalização dos testes

# config
BACKUP_DIR = "./mysql_backups"
DB_FILE = os.path.join(BACKUP_DIR, "database.db")
DB_USER = "root"
DAYS_ROTATE = 1
DISCORD_WEBHOOK_URL = None

if not os.path.exists(BACKUP_DIR):
    os.mkdir(BACKUP_DIR)

con = sqlite3.connect(DB_FILE)
con.row_factory = sqlite3.Row
cur = con.cursor()


def delete_backup(path: str, del_log: bool = True):
    global cur, con
    if os.path.exists(path):
        shutil.rmtree(path)
    if del_log and os.path.exists(f"{path}.log"):
        os.remove(f"{path}.log")
    cur.execute("DELETE FROM backups WHERE path = ?", [path])
    con.commit()


def system_log(message: str):
    print(message)
    if not DISCORD_WEBHOOK_URL:
        return
    import requests

    payload = {"content": message, "username": "Backup Manager"}
    requests.post(DISCORD_WEBHOOK_URL, data=payload, timeout=20)


def init_db():
    cur.execute(
        "CREATE TABLE IF NOT EXISTS migrations(name varchar(64) NOT NULL, executed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)"
    )

    migrations = {
        "0001_init_db": """CREATE TABLE IF NOT EXISTS backups(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            parent_id INTEGER,
            path VARCHAR(512) UNIQUE NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(parent_id) REFERENCES backups(id)
        )"""
    }

    executed_migrations = cur.execute("SELECT * FROM migrations").fetchall()
    for migration in migrations.keys():
        if any(filter(lambda v: v["name"] == migration, executed_migrations)):
            continue
        cur.execute(migrations[migration])
        cur.execute("INSERT INTO migrations (name) VALUES (?)", [migration])
        con.commit()
        print(f"migration: '{migration}' success")


def init_maintenance():
    deleteds = []
    all_backups = cur.execute(
        "SELECT id, parent_id, path FROM backups ORDER BY id ASC"
    ).fetchall()
    for backup in all_backups:
        if not os.path.exists(backup["path"]) or backup["parent_id"] in deleteds:
            print(f"not found: {backup['path']}")
            delete_backup(backup["path"])
            deleteds.append(backup["id"])


def backup():
    last_full_backup = cur.execute(
        "SELECT * FROM backups WHERE parent_id IS NULL AND DATE(created_at) = CURRENT_DATE ORDER BY created_at DESC LIMIT 1"
    ).fetchone()

    current_date = datetime.now()
    if not last_full_backup:
        path_to_backup = os.path.join(
            BACKUP_DIR, current_date.strftime("%d-%m-%Y_full")
        )
        cur.execute("INSERT INTO backups (path) VALUES (?)", [path_to_backup])
        con.commit()

        command = (
            f"mariadb-backup --backup --target-dir={path_to_backup} --user={DB_USER}"
        )
    else:
        last_backup = cur.execute(
            "SELECT * FROM backups WHERE DATE(created_at) = CURRENT_DATE ORDER BY created_at DESC LIMIT 1"
        ).fetchone()
        path_last_backup = last_backup["path"]
        path_to_backup = os.path.join(
            BACKUP_DIR, current_date.strftime("%d-%m-%Y_%H-%M-%S")
        )
        cur.execute(
            "INSERT INTO backups (parent_id, path) VALUES (?, ?)",
            [last_backup["id"], path_to_backup],
        )
        con.commit()

        command = f"mariadb-backup --backup --target-dir={path_to_backup} --incremental-basedir={path_last_backup} --user={DB_USER}"

    if os.path.exists(path_to_backup):
        shutil.rmtree(path_to_backup)

    try:
        command_result = subprocess.run(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        with open(f"{path_to_backup}.log", "w") as log_file:
            log_file.write(command_result.stdout)
            log_file.write(command_result.stderr)

        if command_result.returncode != 0:
            raise Exception(
                f"Backup command failed with return code {command_result.returncode}, {command_result.stderr}"
            )
    except Exception as e:
        system_log(f"Error during backup '{path_to_backup}': {e}")
        delete_backup(path_to_backup, False)
        return


def purge():
    backups_to_delete = cur.execute(
        f"SELECT * FROM backups WHERE parent_id is null AND DATE(created_at, '+{DAYS_ROTATE} day') <= CURRENT_DATE"
    ).fetchall()

    for backup in backups_to_delete:
        backups_childrens = cur.execute(
            """WITH RECURSIVE tree AS (
                SELECT id, parent_id, path FROM backups WHERE id = ?
                UNION ALL
                SELECT b.id, b.parent_id, b.path FROM backups b JOIN tree t ON b.parent_id = t.id
            ) SELECT * FROM tree""",
            [backup["id"]],
        ).fetchall()

        for children in backups_childrens:
            delete_backup(children["path"])
            print(f"{children['path']} {children['id']} deleted")


if os.system("mariadb-backup --help >> /dev/null") != 0:
    system_log("mariadb-backup command not found. Please install MariaDB Backup tool.")
    con.close()
    exit(1)

init_db()
init_maintenance()
backup()
purge()

con.close()
