#!/bin/bash
# update_failed_systems_log.sh
# After sending emails, update failed_systems.log to set emailsent timestamp for notified systems

FAILED_LOG="logs/failed_systems.log"
EMAIL_TRIGGER_FILE="logs/email_triggers.txt"
NOW=$(date +'%Y-%m-%d %H:%M')

if [[ ! -f "$EMAIL_TRIGGER_FILE" ]]; then
  exit 0
fi

if [[ ! -f "$FAILED_LOG" ]]; then
  exit 0
fi

# Read all keys that were notified
while IFS= read -r key; do
  # Update emailsent field for this key, used to avoid sending duplicate notifications (schedule = every hour)
  awk -F',' -v k="$key" -v now="$NOW" 'BEGIN{OFS=","} {if($1==k){$3=now} print $0}' "$FAILED_LOG" > logs/failed_systems.tmp && mv logs/failed_systems.tmp "$FAILED_LOG"
done < "$EMAIL_TRIGGER_FILE"

exit 0
