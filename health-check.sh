# In the original repository we'll just print the result of status checks,
# without committing. This avoids generating several commits that would make
# later upstream merges messy for anyone who forked us.
commit=true
origin=$(git remote get-url origin)
if [[ $origin == *statsig-io/statuspage* ]]
then
  commit=false
fi

KEYSARRAY=()
URLSARRAY=()

urlsConfig="./urls.cfg"
echo "Reading $urlsConfig"
while read -r line
do
  echo "  $line"
  IFS='=' read -ra TOKENS <<< "$line"
  KEYSARRAY+=(${TOKENS[0]})
  URLSARRAY+=(${TOKENS[1]})
done < "$urlsConfig"

echo "***********************"
echo "Starting health checks with ${#KEYSARRAY[@]} configs:"

mkdir -p logs


# Clean up failed_systems.log - remove any systems no longer in urls.cfg
if [[ -f logs/failed_systems.log ]]; then
  echo "Cleaning up failed_systems.log for removed systems..."
  temp_file="logs/failed_systems_clean.tmp"
  > "$temp_file"
  
  while IFS="," read -r key timestamp emailsent; do
    key=$(echo "$key" | xargs)  # Remove whitespace
    if [[ -n "$key" ]]; then
      # Check if this key exists in current KEYSARRAY
      found=false
      for current_key in "${KEYSARRAY[@]}"; do
        if [[ "$current_key" == "$key" ]]; then
          found=true
          break
        fi
      done
      
      if [[ "$found" == true ]]; then
        echo "$key,$timestamp,$emailsent" >> "$temp_file"
      else
        echo "  Removing obsolete system from failed_systems.log: $key"
      fi
    fi
  done < logs/failed_systems.log
  
  if [[ -s "$temp_file" ]]; then
    mv "$temp_file" logs/failed_systems.log
  else
    rm -f logs/failed_systems.log "$temp_file"
  fi
fi

for (( index=0; index < ${#KEYSARRAY[@]}; index++))
do
  key="${KEYSARRAY[index]}"
  url="${URLSARRAY[index]}"
  echo "  $key=$url"

  for i in 1 2 3 4; 
  do
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null $url)
    if [ "$response" -eq 200 ] || [ "$response" -eq 202 ] || [ "$response" -eq 301 ] || [ "$response" -eq 302 ] || [ "$response" -eq 307 ]; then
      result="success"
    else
      result="failed"
    fi
    if [ "$result" = "success" ]; then
      break
    fi
    sleep 5
  done
  dateTime=$(date +'%Y-%m-%d %H:%M')
  if [[ $commit == true ]]
  then
    echo $dateTime, $result >> "logs/${key}_report.log"
    # By default we keep 2000 last log entries.  Feel free to modify this to meet your needs.
    echo "$(tail -2000 logs/${key}_report.log)" > "logs/${key}_report.log"
  else
    echo "    $dateTime, $result"
  fi


  # Log failed systems to failed_systems.log (email notifications)
  if [[ "$result" == "failed" ]]; then
    # if exists update timestamp, keep emailsent as is (every hr, compared in notify_failed_systems.sh)
    if grep -q "^$key," logs/failed_systems.log 2>/dev/null; then
      awk -F',' -v k="$key" -v t="$dateTime" 'BEGIN{OFS=","} {if($1==k){$2=t} print $0}' logs/failed_systems.log > logs/failed_systems.tmp && mv logs/failed_systems.tmp logs/failed_systems.log
    else
      echo "$key,$dateTime," >> logs/failed_systems.log
    fi
  else
    # Remove from failed_systems.log if it exists (system recovered)
    if [[ -f logs/failed_systems.log ]]; then
      if grep -q "^$key," logs/failed_systems.log 2>/dev/null; then
        grep -v "^$key," logs/failed_systems.log > logs/failed_systems.tmp 2>/dev/null || true
        if [[ -s logs/failed_systems.tmp ]]; then
          mv logs/failed_systems.tmp logs/failed_systems.log
        else
          # If tmp file is empty, remove the original file
          rm -f logs/failed_systems.log logs/failed_systems.tmp
        fi
      fi
    fi
  fi
done
