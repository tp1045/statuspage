#!/bin/bash
# notify_failed_systems.sh

FAILED_LOG="logs/failed_systems.log"
EMAIL_TRIGGER_FILE="logs/email_triggers.txt"
NOW_EPOCH=$(date +%s)
ONE_HOUR=3600

mkdir -p logs
> "$EMAIL_TRIGGER_FILE"

if [[ ! -f "$FAILED_LOG" ]]; then
  exit 0
fi

while IFS="," read -r key timestamp emailsent; do
  key=$(echo "$key" | xargs)
  timestamp=$(echo "$timestamp" | xargs) # when the system failed
  emailsent=$(echo "$emailsent" | xargs) # when the notification was sent
  # Skip empty lines
  if [[ -z "$key" ]]; then
    continue
  fi

  # Check if the failure is recent (within last 2 hours) to avoid stale entries (we're sending updates every hour)
  failure_epoch=$(date -d "$timestamp" +%s 2>/dev/null)
  if [[ -n "$failure_epoch" ]]; then
    failure_age=$((NOW_EPOCH - failure_epoch))
    if (( failure_age > 7200 )); then  # 2 hourss
    # should have been cleaned up...
      continue
    fi
  fi

  # If emailsent is empty or older than 1 hour
  if [[ -z "$emailsent" ]]; then
    send_email=1
  else
    emailsent_epoch=$(date -d "$emailsent" +%s 2>/dev/null)
    if [[ -z "$emailsent_epoch" ]]; then
      send_email=1
    else
      diff=$((NOW_EPOCH - emailsent_epoch))
      if (( diff > ONE_HOUR )); then
        send_email=1
      else
      # If email was sent within the last hour, skip sending again.. Tech support is already busy enough with emails. 
        send_email=0
      fi
    fi
  fi

  if (( send_email == 1 )); then
    echo "$key" >> "$EMAIL_TRIGGER_FILE"
  fi

done < "$FAILED_LOG"

exit 0
