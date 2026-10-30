#!/bin/bash
source .env
# --- CONFIGURATION ---
CONTAINER_NAME="mariadb"
DB_USER="root"
DB_PASS="${MARIADB_ROOT_PASSWORD}"
BACKUP_DIR="/srv/mariadb/backup"
RETENTION_DAYS=7
DATE=$(date +%Y-%m-%d_%H%M%S)

QUIET=false
DIAGNOSTICS=false
HELP=false

POSITIONAL_ARGS={}

while [[ $# -gt 0 ]]; do
  case $1 in
	-q|--quiet)
	  QUIET=true
	  shift # past argument
	  ;;
	-d|--diagnostics|--diag)
	  DIAGNOSTICS=true
	  shift
	  ;;
	-h|--help)
	  HELP=true
	  shift
	  ;;
	-*|--*)
	  echo "Unknow Option $1";
	  HELP=true
	  shift
	  ;;
	*)
	  POSITIONAL_ARGS+=("$1") # save positional arg
	  shift
	  ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [[ ${HELP} == "true" ]]; then
  echo "Backup mariadb database running in container: ${CONTAINER_NAME}"
  echo "usage: ./mariadb_backup.sh [-q|--quiet] [-d|--diagnostics] [-h|--help]"
  echo "  -q: no output if sucessful (use this for cron jobs)"
  echo "  -h: help message then quit"
  echo "  -d: diagnostic output then quit"
  echo ""
  exit
fi


if ${DIAGNOSTICS}; then
  echo "CONTAINER_NAME: ${CONTAINER_NAME}"
  echo "DB_USER: ${DB_USER}"
  echo "DB_PASS: ${DB_PASS}"
  echo "BACKUP_DIR: ${BACKUP_DIR}"
  echo "RETENTION_DAYS: ${RETENSION_DAYS}"
  echo "DATE: ${DATE}"
  exit
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# File name for the backup
BACKUP_FILE="$BACKUP_DIR/all_dbs_$DATE.sql.gz"

# --- RUN BACKUP ---
if [[ "${QUIET}" == "false" ]]; then
  echo "Starting MariaDB backup for container: $CONTAINER_NAME..."
fi

docker exec -i "$CONTAINER_NAME" mariadb-dump \
  -u "$DB_USER" \
  -p"$DB_PASS" \
  --all-databases \
  --single-transaction \
  --quick \
  --routines \
  --triggers \
  --events \
  | gzip > "$BACKUP_FILE"

# Check if the backup was successful
if [ $? -eq 0 ]; then
  	if [[ $QUIET == "false" ]] ; then
      echo "Backup completed successfully: $BACKUP_FILE"
	fi
else
    echo "ERROR: Backup failed!" >&2
    exit 1
fi

# --- CLEANUP OLD BACKUPS ---
if [[ $QUIET == "false" ]] ; then
  echo "Cleaning up backups older than $RETENTION_DAYS days..."
fi
find "$BACKUP_DIR" -type f -name "all_dbs_*.sql.gz" -mtime +"$RETENTION_DAYS" -exec rm {} \;

if [[ $QUIET == "false" ]]; then
 echo "Cleanup complete."
fi

