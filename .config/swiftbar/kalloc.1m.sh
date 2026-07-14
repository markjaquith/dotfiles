#!/usr/bin/env zsh

zone_name="data.kalloc.1024"
ceiling_bytes=$((20 * 1024 * 1024 * 1024))
menu_bar_icon="| sfimage=memorychip sfsize=13"

zone_stats=$(/usr/bin/zprint "$zone_name" 2>/dev/null | /usr/bin/awk -v zone="$zone_name" '$1 == zone { print $2, $7; exit }')

if [[ -z "$zone_stats" ]]; then
	echo "kalloc.1024 ?% $menu_bar_icon"
	echo "---"
	echo "Unable to read $zone_name"
	exit 0
fi

read -r element_size in_use <<< "$zone_stats"
usage_bytes=$((element_size * in_use))
usage_percent=$(/usr/bin/awk -v used="$usage_bytes" -v ceiling="$ceiling_bytes" 'BEGIN { printf "%.0f", used / ceiling * 100 }')
usage_gib=$(/usr/bin/awk -v used="$usage_bytes" 'BEGIN { printf "%.2f", used / 1024 / 1024 / 1024 }')

echo "kalloc.1024 ${usage_percent}% $menu_bar_icon"
echo "---"
echo "Usage: ${usage_gib} GiB of 20 GiB"
echo "Objects in use: $in_use"
echo "Refresh | refresh=true"
