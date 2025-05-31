# Bash-Based Personal Intelligence Dashboard
# Projekt zaliczeniowy (Marcel Tomaszek)

A self-updating personal dashboard served locally using only Bash and a few standard CLI tools. It displays:

* Real-time weather for Kraków (temperature, humidity, wind, condition)
* Daily satellite imagery centered on Poland
* Latest Git log of the current repository
* Top cryptocurrency prices
* Latest business news headlines
* Live system resource usage (CPU, RAM, Disk)

---

## How It Works

* **Frontend**: A minimal HTML+CSS page with meta refresh every 6 seconds
* **Backend**:

  * Bash script to collect data and generate HTML
  * `curl` to pull weather, satellite, crypto, and news APIs
  * `jq` for parsing JSON responses
  * `vm_stat`, `free`, and `top` for system stats
  * `python3 -m http.server` to host the static dashboard
* **Live system stats**: Written to a small HTML fragment (`sys.html`) and embedded via `<iframe>`
* **Satellite**: Fetched from NASA GIBS once per day and cached locally

---

## Quick Start

### Requirements (macOS/Linux)

* Bash
* `curl`, `jq`, `top`, `df`, `free` or `vm_stat`
* Python 3
* Git (optional: for local git log display)

### Run it

```
chmod +x dashboard2.sh
./dashboard2.sh
```

This will:

* Start a local web server at [http://localhost:8080](http://localhost:8080)
* Open your browser
* Refresh live every 6 seconds

### Exit

Use `Ctrl+C` to cleanly shut down all background tasks and the web server.

---

## Satellite Image Notes

The satellite image is fetched only once per day due to NASA API limits and image update frequency. It is cached locally and reused until the next day.

---

## Customization

* **Location**: Change coordinates in the weather and satellite URL for different cities
* **News source**: Update the `news_json` endpoint for different regions or categories
* **Refresh rate**: Edit meta refresh or Bash `sleep` intervals

---

## Files Generated

* `/tmp/bash_dashboard/index.html` – the dashboard
* `/tmp/bash_dashboard/sys.html` – system stats iframe
* `/tmp/bash_dashboard/satellite_DATE.jpg` – daily satellite image cache

---

## Purpose

A lightweight information feed for use on a secondary screen or fullscreen workspace. Built with Bash and standard Unix tools, avoiding heavy dependencies like Node.js or Electron.

---

## Components Used

* Bash + GNU core utilities
* NASA GIBS (imagery)
* Open-Meteo (weather)
* CoinGecko (crypto)
* Saurav's News API proxy (news)
* Python HTTP server
