#!/bin/bash

# نصب خودکار whiptail اگه وجود نداشته باشه
if ! command -v whiptail &> /dev/null; then
  echo "whiptail not found. Installing..."
  apt update && apt install whiptail -y
fi

IPTABLES="/sbin/iptables"
CHAIN="FORWARD"
WHITELIST_FILE="/etc/dns-allowed-ips.txt"
LIMITED_PORTS_FILE="/etc/limited-ports.txt"

mkdir -p /etc
touch "$WHITELIST_FILE"
touch "$LIMITED_PORTS_FILE"

add_ip() {
  ip=$(whiptail --inputbox "Enter IP to ALLOW:" 10 60 3>&1 1>&2 2>&3)
  if [[ -z "$ip" ]]; then return; fi
  if grep -q "$ip" "$WHITELIST_FILE"; then
    whiptail --msgbox "⚠️ IP $ip already allowed." 10 50
  else
    echo "$ip" >> "$WHITELIST_FILE"
    whiptail --msgbox "✅ IP $ip added to whitelist." 10 50
  fi
}

remove_ip() {
  ip=$(whiptail --inputbox "Enter IP to REMOVE:" 10 60 3>&1 1>&2 2>&3)
  if [[ -z "$ip" ]]; then return; fi
  sed -i "/$ip/d" "$WHITELIST_FILE"
  whiptail --msgbox "❌ IP $ip removed from whitelist." 10 50
}

list_ips() {
  if [[ -s "$WHITELIST_FILE" ]]; then
    ips=$(cat "$WHITELIST_FILE")
  else
    ips="(Empty)"
  fi
  whiptail --msgbox "📋 Allowed IPs:\n\n$ips" 20 60
}

reset_firewall() {
  while read ip; do
    for port in $(cat "$LIMITED_PORTS_FILE"); do
      $IPTABLES -D $CHAIN -p udp -s $ip --dport $port -j ACCEPT 2>/dev/null
      $IPTABLES -D $CHAIN -p tcp -s $ip --dport $port -j ACCEPT 2>/dev/null
    done
  done < "$WHITELIST_FILE"

  for port in $(cat "$LIMITED_PORTS_FILE"); do
    $IPTABLES -D $CHAIN -p udp --dport $port -j DROP 2>/dev/null
    $IPTABLES -D $CHAIN -p tcp --dport $port -j DROP 2>/dev/null
  done

  > "$WHITELIST_FILE"
  > "$LIMITED_PORTS_FILE"

  whiptail --msgbox "✅ Firewall rules reset." 10 50
}

set_port_limit() {
  ports=$(whiptail --inputbox "Enter ports to LIMIT (comma separated, e.g., 53,80,443):" 10 60 3>&1 1>&2 2>&3)
  if [[ -z "$ports" ]]; then return; fi

  for port in $(echo $ports | tr ',' '\n'); do
    port=$(echo $port | xargs) # پاک کردن فاصله‌ها

    # اگه از قبل محدود نشده، اضافه کن
    if ! grep -q "^$port$" "$LIMITED_PORTS_FILE"; then
      echo "$port" >> "$LIMITED_PORTS_FILE"
    fi

    $IPTABLES -D $CHAIN -p udp --dport $port -j DROP 2>/dev/null
    $IPTABLES -D $CHAIN -p tcp --dport $port -j DROP 2>/dev/null

    $IPTABLES -A $CHAIN -p udp --dport $port -j DROP
    $IPTABLES -A $CHAIN -p tcp --dport $port -j DROP
  done

  whiptail --msgbox "✅ Ports $ports have been limited." 10 50
}

list_limited_ports() {
  if [[ -s "$LIMITED_PORTS_FILE" ]]; then
    ports=$(cat "$LIMITED_PORTS_FILE")
  else
    ports="(No ports limited)"
  fi
  whiptail --msgbox "📋 Limited Ports:\n\n$ports" 20 60
}

# ---------------------- منو ----------------------

while true; do
  OPTION=$(whiptail --title "DNS Firewall Menu" --menu "Choose an option:" 20 60 12 \
    "1" "➕ Add IP to Whitelist" \
    "2" "➖ Remove IP from Whitelist" \
    "3" "📜 List Allowed IPs" \
    "4" "🔄 Reset All Rules" \
    "5" "⚙️ Set Port Limit" \
    "6" "📋 List Limited Ports" \
    "7" "🚪 Exit" \
    3>&1 1>&2 2>&3)

  case "$OPTION" in
    1) add_ip ;;
    2) remove_ip ;;
    3) list_ips ;;
    4) reset_firewall ;;
    5) set_port_limit ;;
    6) list_limited_ports ;;
    7) break ;;
    *) break ;;
  esac
done
