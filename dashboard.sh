#!/bin/bash
set -e

PORT=8080
DASH_DIR="/tmp/bash_dashboard"
OUTPUT="$DASH_DIR/index.html"
IMG="$DASH_DIR/satellite.jpg"
SYS="$DASH_DIR/sys.html"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$DASH_DIR"
cd "$DASH_DIR"

weather_code_desc() {
  case "$1" in
    0) echo "Bezchmurnie";;
    1|2|3) echo "Częściowo pochmurno";;
    45|48) echo "Mgła";;
    51|53|55) echo "Mżawka";;
    61|63|65) echo "Deszcz";;
    66|67) echo "Marznący deszcz";;
    71|73|75) echo "Śnieg";;
    80|81|82) echo "Przelotne opady";;
    95) echo "Burza";;
    96|99) echo "Burza z gradem";;
    *) echo "Nieznana pogoda";;
  esac
}

get_sys_stats() {
  if command -v free >/dev/null; then
    mem=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
  elif command -v vm_stat >/dev/null; then
    pagesize=$(sysctl -n hw.pagesize)
    stats=$(vm_stat)
    active=$(echo "$stats" | awk '/Pages active/ {gsub(/\./, "", $3); print $3}')
    wired=$(echo "$stats" | awk '/Pages wired down/ {gsub(/\./, "", $5); print $5}')
    compressed=$(echo "$stats" | awk '/Pages occupied by compressor/ {gsub(/\./, "", $6); print $6}')
    total=$(echo "$stats" | awk '/Pages free/ {gsub(/\./, "", $3); free=$3}
                                 /Pages inactive/ {gsub(/\./, "", $3); inactive=$3}
                                 END {print free + inactive + active + wired + compressed}')
    used=$((active + wired + compressed))
    total_bytes=$((total * pagesize))
    used_bytes=$((used * pagesize))
    mem="$(awk -v used=$used_bytes -v total=$total_bytes 'BEGIN {
      printf("%.1f / %.1f GB", used / 1073741824, total / 1073741824)
    }')"
  else
    mem="Nieznane"
  fi

  cpu=$(top -l 1 -n 0 | awk '/CPU usage/{print $3}' 2>/dev/null || top -bn1 | grep "Cpu(s)" | awk '{print $2+$4"%"}')
  disk=$(df -h / | awk 'NR==2 {print $3 " / " $2}')
  echo "<p><b>CPU:</b> $cpu</p><p><b>Pamięć RAM:</b> $mem</p><p><b>Dysk:</b> $disk</p>"
}

update_sys_stats() {
  stats=$(get_sys_stats)
  cat <<EOF > "$SYS"
<div style="color:#ddd;font-family:sans-serif;font-size:14px;">$stats</div>
EOF
}

fetch_data() {
  sat_date=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
  img_day_file="$DASH_DIR/satellite_${sat_date}.jpg"
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  if [ ! -f "$img_day_file" ]; then
    curl -s -o "$img_day_file" "https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi?SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0&LAYERS=MODIS_Terra_CorrectedReflectance_TrueColor&FORMAT=image/jpeg&HEIGHT=1024&WIDTH=1024&CRS=EPSG:4326&BBOX=47,16,53,22&TIME=$sat_date"
  fi
  cp "$img_day_file" "$IMG"

  weather_json=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=50.06143&longitude=19.93658&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weathercode")
  temp=$(jq '.current.temperature_2m' <<< "$weather_json")
  wind=$(jq '.current.wind_speed_10m' <<< "$weather_json")
  humidity=$(jq '.current.relative_humidity_2m' <<< "$weather_json")
  wcode=$(jq '.current.weathercode' <<< "$weather_json")
  wdesc=$(weather_code_desc "$wcode")

  news_json=$(curl -s "https://saurav.tech/NewsAPI/top-headlines/category/business/us.json")
  news_items=$(jq -r '.articles[:5][] | "<div><b><a href=\""+.url+"\">"+.title+"</a></b><br><i>"+.description+"</i></div>"' <<< "$news_json")

  crypto_json=$(curl -s "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=volume_desc&per_page=10&page=1")
  parsed=$(jq -r '.[] | select(.name and .current_price and .image) | "<tr><td><img src=\""+.image+"\" width=20></td><td>"+.name+"</td><td>$"+(.current_price|tostring)+"</td></tr>"' <<< "$crypto_json")
  if [[ -n "$parsed" ]]; then
    crypto_rows="$parsed"
  else
    crypto_rows="<tr><td colspan=3><i>Brak danych kryptowalut</i></td></tr>"
  fi

  if [[ -d "$SCRIPT_PATH/.git" ]]; then
    cd "$SCRIPT_PATH"
    git_log=$(git log -n 5 --pretty=format:'<li>%s (%cr)</li>')
    cd "$DASH_DIR"
  else
    git_log="<li>Brak repozytorium Git</li>"
  fi

  cat <<EOF > "$OUTPUT"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"><title>Pulpit systemowy</title>
  <meta http-equiv="refresh" content="6">
  <style>
    body{background:#111;color:#ddd;font-family:sans-serif;padding:20px;}
    a{color:#4fc3f7;text-decoration:none;}
    .grid{display:grid;grid-template-columns:1fr 1fr;gap:20px;}
    .card{background:#222;padding:15px;border-radius:8px;box-shadow:0 0 8px #000;}
    table{width:100%;border-collapse:collapse;}
    td,th{padding:6px;border-bottom:1px solid #444;}
    img{max-width:100%;border-radius:8px;margin-top:10px;}
    .footer{text-align:center;color:#888;font-size:0.9em;margin-top:15px;}
  </style>
</head>
<body>
  <h1>Pulpit informacyjny</h1>
  <div class="footer">Ostatnia aktualizacja: $timestamp</div>

  <div class="grid">
    <div class="card">
      <h2>Pogoda - Kraków</h2>
      <p><b>Temperatura:</b> $temp °C</p><p><b>Wilgotność:</b> $humidity%</p><p><b>Wiatr:</b> $wind km/h</p><p><b>Stan:</b> $wdesc</p>
    </div>

    <div class="card">
      <h2>Logi Git</h2><ul>$git_log</ul>
    </div>

    <div class="card">
      <h2>Wiadomości biznesowe</h2>$news_items
    </div>

    <div class="card">
      <h2>Kryptowaluty</h2>
      <table><tr><th></th><th>Nazwa</th><th>Cena</th></tr>$crypto_rows</table>
    </div>

    <div class="card">
      <h2>Statystyki systemu</h2>
      <iframe src="sys.html" width="100%" height="100" frameborder="0" style="background:#222;color:#fff;"></iframe>
    </div>

    <div class="card">
      <h2>Zdjęcie satelitarne (MODIS - $sat_date)</h2>
      <img src="satellite.jpg">
    </div>
  </div>
</body>
</html>
EOF
}

# Serwer lokalny
python3 -m http.server "$PORT" --directory "$DASH_DIR" &>/dev/null &
server_pid=$!

# Zamykanie procesów przy wyjściu
trap "kill $server_pid $!" EXIT

# Start
fetch_data
open "http://localhost:$PORT" 2>/dev/null || xdg-open "http://localhost:$PORT"

# Live system stats
while true; do update_sys_stats; sleep 1; done &

# Full refresh
while true; do
  start=$(date +%s)
  fetch_data
  elapsed=$(( $(date +%s) - start ))
  sleep $((6 > elapsed ? 6 - elapsed : 1))
done
