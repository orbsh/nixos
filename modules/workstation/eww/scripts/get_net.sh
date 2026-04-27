#!/bin/bash
INTERFACE=${2:-wlan0}
TYPE=$1
CACHE_FILE="/tmp/eww_net_${INTERFACE}_${TYPE}"

# Get current bytes
if [ "$TYPE" == "down" ]; then
    NOW=$(awk -v iface="$INTERFACE" '$1 ~ iface {print $2}' /proc/net/dev)
else
    NOW=$(awk -v iface="$INTERFACE" '$1 ~ iface {print $10}' /proc/net/dev)
fi

NOW=${NOW:-0}
PREV=$(cat "$CACHE_FILE" 2>/dev/null)
PREV=${PREV:-$NOW}
echo "$NOW" > "$CACHE_FILE"

# Calculate Delta and convert to MB/s
# Delta / 1024 / 1024 / 2 seconds
awk -v now="$NOW" -v prev="$PREV" 'BEGIN { printf "%.2f", (now - prev) / 2097152 }'
