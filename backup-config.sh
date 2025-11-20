#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

unset TOKEN CHAT_ID bot_token api_sendDocument ddns_block ip_address host_name ddns_status
unset hostname uptime_info wg_status wg_active wg_peers timestamp backup_dir backup_file filename caption

eval $(grep -v '^[[:space:]]*#' /config/auth/telegram.env | xargs)
bot_token="${TOKEN}"
chat_id="${CHAT_ID}"
api_sendDocument="https://api.telegram.org/bot${bot_token}/sendDocument"

trim() { echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

ddns_block=$(run show dns dynamic status 2>/dev/null || true)
ip_address=$(printf "%s\n" "$ddns_block" | awk -F: '/ip address/ {print $2; exit}' | sed 's/^[ \t]*//;s/[ \t]*$//')
host_name=$(printf "%s\n" "$ddns_block" | awk -F: '/host-name/ {print $2; exit}' | sed 's/^[ \t]*//;s/[ \t]*$//')
ddns_status=$(printf "%s\n" "$ddns_block" | awk -F: '/update-status/ {print $2; exit}' | sed 's/^[ \t]*//;s/[ \t]*$//')

[ -z "$ip_address" ] && ip_address="unknown"
[ -z "$host_name" ] && host_name="unknown"
[ -z "$ddns_status" ] && ddns_status="unknown"

hostname=$(run show system 2>/dev/null | awk -F: '/Hostname/ {print $2; exit}' | sed 's/^[ \t]*//;s/[ \t]*$//')
[ -z "$hostname" ] && hostname=$(hostname 2>/dev/null || echo "unknown")

uptime_info=$(run show system uptime 2>/dev/null | sed -n 's/.*up[[:space:]]\(.*\),[[:space:]][0-9]* user.*/\1/p')
[ -z "$uptime_info" ] && uptime_info=$(uptime -p 2>/dev/null || echo "unknown")

if command -v wg >/dev/null 2>&1; then
  wg_status=$(sudo wg show all 2>/dev/null || true)
  wg_active=$(printf "%s\n" "$wg_status" | awk '/^interface:/ {iface=$2} END {print iface}')
  [ -z "$wg_active" ] && wg_active="None"
  wg_peers=$(printf "%s\n" "$wg_status" | awk '/^peer:/ {p=$2} /latest handshake/ && $3!="0" {count++} END {if(count=="") count=0; print count}')
else
  wg_active="Not installed"
  wg_peers=0
fi

timestamp=$(date +%d%m%Y_%H%M)
backup_dir="/tmp/backup_${timestamp}"
mkdir -p "$backup_dir"
cp -r /config "$backup_dir/" 2>/dev/null || true
[ -d /home/ubnt/wireguard ] && cp -r /home/ubnt/wireguard "$backup_dir/" 2>/dev/null || true
backup_file="/tmp/backup_${timestamp}.tar.gz"
tar -C "$backup_dir" -czf "$backup_file" . >/dev/null 2>&1 || tar -czf "$backup_file" -C "$backup_dir" . >/dev/null 2>&1
rm -rf "$backup_dir"
filename=$(basename "$backup_file")

caption="🖥️ <b>Hostname:</b> <code>$(trim "$hostname")</code>
🌐 <b>Public IP:</b> <code>$(trim "$ip_address")</code>
🏠 <b>DDNS Host:</b> <code>$(trim "$host_name")</code>
✅ <b>DDNS Status:</b> <b>$(trim "$ddns_status")</b>
⏱️ <b>Uptime:</b> <code>$(trim "$uptime_info")</code>
🛡️ <b>WireGuard:</b> <b>$(trim "$wg_active")</b> ($(trim "$wg_peers") peers)
📅 <b>Timestamp:</b> <code>${timestamp}</code>
💾 <b>File:</b> <code>${filename}</code>"

curl -s -X POST "${api_sendDocument}" \
  -F chat_id="${chat_id}" \
  -F document=@"${backup_file}" \
  -F caption="${caption}" \
  -F parse_mode=HTML >/dev/null 2>&1

exit 0
