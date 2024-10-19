#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Telegram Bot Token and Chat ID
TELEGRAM_BOT_TOKEN="YOUR_TOKEN"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"

# Function to send a message to Telegram
send_telegram_message() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
       -d "chat_id=${TELEGRAM_CHAT_ID}" \
       -d "text=${message}" \
       -d "parse_mode=Markdown"
}

# Function to display usage information
usage() {
  echo "rsync backup script for incremental backups"
  echo ""
  echo "Usage: $0 [options] [source_directory] [backup_directory]"
  echo ""
  echo "Options:"
  echo "  -h, --help          Show this help message."
  echo "  --dry-run           Perform a trial run with rsync, showing what would be done."
  echo "  source_directory    The directory to back up (defaults to the user's home directory)."
  echo "  backup_directory    The directory where backups will be stored (defaults to /mnt/data/backups)."
  exit 1
}

DRY_RUN=""
POSITIONAL=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    --dry-run)
      DRY_RUN="--dry-run"
      shift
      ;;
    *)
      POSITIONAL+=("$1") # save positional arguments
      shift
      ;;
  esac
done

# Restore positional arguments
set -- "${POSITIONAL[@]}"

readonly SOURCE_DIR="${1:-${HOME}}"
readonly BACKUP_DIR="${2:-/mnt/data/backups}"
readonly DATETIME="$(date '+%Y-%m-%d_%H:%M:%S')"
readonly BACKUP_PATH="${BACKUP_DIR}/${DATETIME}"
readonly LATEST_LINK="${BACKUP_DIR}/latest"
readonly LOG_FILE="${BACKUP_DIR}/backup.log"

# Create backup directories
mkdir -p "${BACKUP_DIR}"

log_info() {
  local message="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $message" | tee -a "${LOG_FILE}"
}

log_error() {
  local message="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $message" | tee -a "${LOG_FILE}" >&2
}

# Check if rsync is installed
if ! command -v rsync &> /dev/null; then
  log_error "rsync is not installed. Please install rsync to proceed."
  exit 1
fi

# Check if the source directory exists
if [[ ! -d "${SOURCE_DIR}" ]]; then
  log_error "Source directory does not exist: ${SOURCE_DIR}"
  send_telegram_message "Source directory does not exist. Backup failed"
  exit 1
fi

# Check available disk space
REQUIRED_SPACE=$(du -s "${SOURCE_DIR}" | awk '{print $1}')
AVAILABLE_SPACE=$(df "${BACKUP_DIR}" | tail -1 | awk '{print $4}')

if (( AVAILABLE_SPACE < REQUIRED_SPACE )); then
  log_error "Not enough disk space for backup. Required: ${REQUIRED_SPACE}, Available: ${AVAILABLE_SPACE}"
  send_telegram_message "Not enough disk space for backup"
  exit 1
fi

# Perform the backup
log_info "Starting backup at ${DATETIME}"

if [[ -n "${DRY_RUN}" ]]; then
  log_info "Dry run mode: No files will be copied."
else
  if rsync -av --compress --info=progress2 --delete --link-dest="${LATEST_LINK}" \
    --exclude=".cache" \
    --log-file="${LOG_FILE}" \
    "${SOURCE_DIR}/" \
    "${BACKUP_PATH}"; then
    log_info "Backup completed successfully."
  else
    log_error "Error during backup."
    send_telegram_message "Error during backup"
    exit 1
  fi
fi

# Update the symbolic link to the latest backup
if [[ -L "${LATEST_LINK}" ]]; then
  rm -f "${LATEST_LINK}"
fi
ln -s "${BACKUP_PATH}" "${LATEST_LINK}"

log_info "Latest backup link updated."
send_telegram_message "Latest backup was successfull"
