#!/usr/bin/env bash
# Current weather as one JSON object, for the bar's weather module.
#   weather.sh [location] [metric|imperial]
# An empty location means "where this connection is" (IP lookup via ipwho.is). A named
# location is resolved with Open-Meteo's geocoder. Weather data comes from Open-Meteo
# (no account or key). The location lookup is cached; if the network fails, the last
# good result is printed with "stale": true.
loc="${1:-}"
units="${2:-metric}"
dir="$HOME/.cache/43pr"
mkdir -p "$dir"
cache="$dir/weather.json"
geo="$dir/weather-geo.json"

fail() { [ -r "$cache" ] && jq -c '.stale = true' "$cache" && exit 0; exit 1; }

# 1. coordinates (cached per location string)
if [ -r "$geo" ] && [ "$(jq -r '.query' "$geo")" = "$loc" ]; then
    place=$(cat "$geo")
else
    if [ -z "$loc" ]; then
        place=$(curl -sf -m 10 "https://ipwho.is/?fields=success,city,latitude,longitude" |
            jq -c --arg q "$loc" 'select(.success == true) | {query: $q, city: .city, lat: .latitude, lon: .longitude}') || fail
    else
        place=$(curl -sfG -m 10 "https://geocoding-api.open-meteo.com/v1/search" \
                    --data-urlencode "name=$loc" --data-urlencode "count=1" |
            jq -c --arg q "$loc" '.results[0] | select(. != null) | {query: $q, city: .name, lat: .latitude, lon: .longitude}') || fail
    fi
    [ -n "$place" ] || fail
    echo "$place" > "$geo"
fi
lat=$(jq -r '.lat' <<<"$place"); lon=$(jq -r '.lon' <<<"$place"); city=$(jq -r '.city' <<<"$place")

# 2. current conditions
if [ "$units" = "imperial" ]; then tu=fahrenheit; wu=mph; else tu=celsius; wu=kmh; fi
out=$(curl -sf -m 10 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day&temperature_unit=$tu&wind_speed_unit=$wu" |
    jq -c --arg city "$city" --arg units "$units" '.current | {
        city: $city, units: $units,
        temp: (.temperature_2m | round), feels: (.apparent_temperature | round),
        humidity: .relative_humidity_2m, wind: (.wind_speed_10m | round),
        code: .weather_code, day: (.is_day == 1), time: .time, stale: false }') || fail
[ -n "$out" ] || fail
echo "$out" | tee "$cache"
