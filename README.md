# ⚡ MeowKit-SD-Payloads (MicroSD Payload Arsenal)

```
██████╗  █████╗ ██╗   ██╗██╗      ██████╗  █████╗ ██████╗ ███████╗
██╔══██╗██╔══██╗╚██╗ ██╔╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝
██████╔╝███████║ ╚████╔╝ ██║     ██║   ██║███████║██║  ██║███████╗
██╔═══╝ ██╔══██║  ╚██╔╝  ██║     ██║   ██║██╔══██║██╔══██╗╚════██║
██║     ██║  ██║   ██║   ███████╗╚██████╔╝██║  ██║██████╔╝███████║
╚═╝     ╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝
        ── MEOWKIT S3 CYBER ARSENAL // APPS & SCRIPTS ──
```

Complete payload suite, dynamic Lua 5.4 applications, sandboxed WebAssembly binaries, BadUSB DuckyScript modules, and infrared dictionary profiles designed for the **MEOWKit ESP32-S3 Handheld Cyber Multitool** (DarkCyfr Custom Edition).

---

## 📂 Root File Structure

```
SD_CARD_ROOT/
├── apps/                 # Dynamic Lua 5.4 and Wasm3 applications
├── badusb/               # Keystroke injection scripts & keyboard layout maps (.kl)
│   ├── layouts/          # International keyboard layout tables
│   └── scripts/          # DuckyScript payloads (Windows, macOS, Linux, ChromeOS, Android, iOS)
├── config/               # Universal configuration files (IPs, targets, credentials, settings)
│   ├── wifi.cfg.example  # Global Wi-Fi SSID and passkey template
│   ├── homelab.cfg.example # Monitored hosts, IPs, and ports
│   ├── triage.cfg.example  # HTTP latency probe URL, intervals, timeouts
│   ├── subnets.cfg.example # Custom CIDR IP presets for subnet calculator
│   ├── vault.cfg.example   # Offline secret fragments & custom D-Pad PIN
│   ├── walkie.cfg.example  # P2P callsign, UDP port, broadcast address
│   ├── wardrive.cfg.example# Scan intervals, CSV path, auto-decloak toggle
│   ├── radar.cfg.example   # Sweep speed, live RF scan, RSSI thresholds
│   ├── hud.cfg.example     # Callsign, unit ID, accent color theme
│   ├── alarm.cfg.example   # Motion sensitivity, arm delay, siren toggle
│   └── recorder.cfg.example# Audio duration, output directory, prefix
├── infrared/             # Universal IR remote dictionaries (.ir)
│   └── universal/        # AC, Audio, Projectors, TVs, Fans, LEDs, Displays
├── music/                # Standalone audio files for the internal player
├── wifi.cfg              # Active Wi-Fi credentials (gitignored for opsec)
└── recordings/           # Wiretap audio recordings (generated automatically)
```

---

## ⚙️ Universal Configuration Architecture (`/config/`)

All apps are designed to be **100% universal and customizable without editing Lua code**. Simply drop or edit `.cfg` files in the `/config/` directory on your MicroSD card. If any config file is omitted, the apps will automatically run with safe defaults and generate documented templates on the SD card:

| Config File | Target App | Key Settings & Parameters |
|---|---|---|
| [`config/wifi.cfg.example`](config/wifi.cfg.example) | Global (All Net Apps) | `SSID`, `PASSWORD` for automatic connection. |
| [`config/homelab.cfg.example`](config/homelab.cfg.example) | `homelab_pulse.lua` | Custom list of target nodes (`NAME,IP,PORT`). Supports unlimited servers with D-Pad scroll! |
| [`config/triage.cfg.example`](config/triage.cfg.example) | `network_triage.lua` | `PROBE_URL`, `INTERVAL_MS`, `TIMEOUT_MS`. |
| [`config/subnets.cfg.example`](config/subnets.cfg.example) | `subnet_calc.lua` | Custom CIDR presets (`NAME,IP,CIDR`). |
| [`config/vault.cfg.example`](config/vault.cfg.example) | `secure_vault.lua` | Custom D-Pad unlock sequence (`UNLOCK_SEQUENCE=UP,UP,DOWN,DOWN`) and secret fragments (`TAG=SECRET`). |
| [`config/walkie.cfg.example`](config/walkie.cfg.example) | `walkie_terminal.lua` | `CALLSIGN`, `UDP_PORT`, `BROADCAST_IP`, `BEACON_INTERVAL_MS`, and `QUICK_MESSAGES`. |
| [`config/wardrive.cfg.example`](config/wardrive.cfg.example) | `wifi_wardrive.lua` | `SCAN_INTERVAL_MS`, `LOG_FILE`, `AUTO_DECLOAK`, `MIN_RSSI`. |
| [`config/radar.cfg.example`](config/radar.cfg.example) | `radar_recon.lua` | `SWEEP_SPEED`, `REAL_RF_SCAN` (maps real Wi-Fi APs onto radar), `SCAN_INTERVAL_MS`, `MIN_RSSI`. |
| [`config/hud.cfg.example`](config/hud.cfg.example) | `cyber_hud.lua` | `CALLSIGN`, `UNIT_ID`, `THEME` (`CYAN`, `LIME`, `ORANGE`, `RED`). |
| [`config/alarm.cfg.example`](config/alarm.cfg.example) | `tamper_alarm.lua` | `ARM_DELAY_SEC`, `SENSITIVITY` (`HIGH`, `MED`, `LOW`), `SIREN_ENABLED`. |
| [`config/recorder.cfg.example`](config/recorder.cfg.example) | `audio_recorder.lua` | `DEFAULT_DURATION_SEC`, `OUTPUT_DIR`, `FILE_PREFIX`. |

---

## 🚀 Dynamic SD Apps Manifest (`/apps/`)

All applications execute dynamically via **App 11 (SD Apps)**. Under the **DarkCyfr Custom Firmware**, all Lua applications execute with **zero internal SRAM overhead** by allocating strictly into the **8 MB Octal PSRAM** with deterministic radio teardown upon exit.

### 🛰️ Wireless & Tactical Recon

| File | Type | Description |
|---|---|---|
| [`wifi_wardrive.lua`](apps/wifi_wardrive.lua) | Lua 5.4 | **Autonomous Wi-Fi Wardrive & Hidden SSID Decloaker:** Scans channels 1–13, captures RSSI/BSSID/Auth, logs GPS-ready telemetry to `/wardrive.csv`. Features automated promiscuous frame sniffing (`meow.wifi_decloak`) to unmask hidden networks. |
| [`radar_recon.lua`](apps/radar_recon.lua) | Lua 5.4 | **Tactical Signal Radar:** Real-time sweeping polar radar rendering detected 802.11 APs positioned by signal attenuation ring and channel azimuth with integer-safe trigonometry math. |
| [`findmy_beacon.lua`](apps/findmy_beacon.lua) | Lua 5.4 | **Apple AirTag / FindMy Emulation:** Broadcasts cryptographic Apple FindMy telemetry packets. Upgraded with static canvas caching for zero screen tearing and flicker-free 30 FPS updates. |
| [`rf_waterfall.lua`](apps/rf_waterfall.lua) | Lua 5.4 | **RF Waterfall Spectral Display:** Visual spectrogram tracking channel utilization and radio energy across the 2.4 GHz spectrum. |

### 🛠️ Field Operations & Telemetry

| File | Type | Description |
|---|---|---|
| [`cyber_hud.lua`](apps/cyber_hud.lua) | Lua 5.4 | **Cyberpunk HUD:** Mission-critical dashboard reporting AXP2101 battery voltage/level/charging status, QMI8658 6-axis IMU pitch/roll/accel, and Wi-Fi state with high-speed differential rendering (30+ FPS). |
| [`compass_hud.lua`](apps/compass_hud.lua) | Lua 5.4 | **Tactical Artificial Horizon & Compass:** Dual-axis pitch/roll reticle with digital heading calculated from raw accelerometer and magnetometer vectors via safe `math.atan(y, x)`. |
| [`audio_recorder.lua`](apps/audio_recorder.lua) | Lua 5.4 | **Acoustic Wiretap & Voice Recorder:** Dual ES7210 microphone capture into 16 kHz 16-bit WAV files stored at `/recordings/`. Features a live hardware VU meter and multi-mode button triggers. |
| [`subnet_calc.wasm`](apps/subnet_calc.wasm) | WebAssembly | **Rust Wasm3 Subnet Calculator:** Sandboxed 64 KB memory binary calculating IPv4 network/broadcast addresses, usable host ranges, and wildcard masks with tactile joystick navigation. |
| [`subnet_calc.lua`](apps/subnet_calc.lua) | Lua 5.4 | **Pure Lua Subnet Calculator:** Zero-dependency fallback providing instant CIDR and VLSM subnet breakdowns. |

### 🛡️ Utilities & Hardware Hacking

| File | Type | Description |
|---|---|---|
| [`gpio_sniffer.lua`](apps/gpio_sniffer.lua) | Lua 5.4 | **Hardware Logic Sniffer:** Real-time state visualizer for GPIO pins with pullup/pulldown probing. |
| [`pinout_ref.lua`](apps/pinout_ref.lua) | Lua 5.4 | **Onboard Interactive Pinout Guide:** Quick reference for all external header pins, I2C, SPI, and UART lines. |
| [`homelab_pulse.lua`](apps/homelab_pulse.lua) | Lua 5.4 | **Homelab Health Monitor:** Performs HTTP/UDP heartbeat checks against local network nodes and servers. |
| [`walkie_terminal.lua`](apps/walkie_terminal.lua) | Lua 5.4 | **P2P Mesh Communicator:** Off-grid encrypted text terminal utilizing peer-to-peer UDP broadcast packets. |
| [`tamper_alarm.lua`](apps/tamper_alarm.lua) | Lua 5.4 | **Inertial Tamper Siren:** Armable perimeter sensor triggering acoustic alarms and status strobes on physical disturbance. |
| [`token_gen.lua`](apps/token_gen.lua) | Lua 5.4 | **Hardware Entropy Generator:** Cryptographic PRNG generating one-time passcodes and passwords using ESP32-S3 radio noise. |
| [`secure_vault.lua`](apps/secure_vault.lua) | Lua 5.4 | **Encrypted Field Notepad:** Password-protected encrypted text storage for sensitive credentials and notes. |
| [`pocket_synth.lua`](apps/pocket_synth.lua) | Lua 5.4 | **Acoustic Synthesizer:** Real-time interactive frequency tone generator using the onboard I2S speaker. |
| [`network_triage.lua`](apps/network_triage.lua) | Lua 5.4 | **Network Diagnostics:** Automated gateway, DNS, and IP configuration inspector. |

---

## ⌨️ BadUSB Payloads (`/badusb/`)

The BadUSB engine turns the MEOWKit S3 into a programmable HID keyboard / mouse injector.

### Script Highlights (`/badusb/scripts/`)
* `recon_operator_audit.txt`: Collects system architecture, network configuration, and active users into a sanitized audit file.
* `sys_net_health.txt`: Rapid network adapter and DNS health validation.
* `dev_terminal_prep.txt`: Instantly spawns and styles administrative shells.
* `anti_sleep_jiggler.txt`: Mouse micro-movement injector preventing lock-screen timeouts during long audits.
* `Install_qFlipper_*.txt`: Rapid staging scripts for desktop utilities across Windows, Linux, and macOS.

### Layout Maps (`/badusb/layouts/`)
Full support for international keyboard mapping: `en-US`, `en-UK`, `de-DE`, `fr-FR`, `es-ES`, `it-IT`, `cz_CS`, `dvorak`, `colemak`, and more.

---

## 📡 Universal Infrared Remotes (`/infrared/`)

Contains raw `.ir` frequency dictionaries compatible with home appliances, televisions, audio receivers, projectors, and digital signage:
* `universal/tv.ir` (Samsung, LG, Sony, Vizio, TCL, Hisense, Panasonic)
* `universal/ac.ir` (Daikin, Mitsubishi, Carrier, LG, Gree)
* `universal/audio.ir` (Soundbars, AVRs, Amps)
* `universal/projector.ir` (Epson, BenQ, Optoma)
* `universal/fans.ir` & `universal/leds.ir` (Home automation, LED strip controllers)

---

## 🔄 Synchronizing to Your MEOWKit

### Automated Sync via PowerShell
1. Insert the MicroSD card into your computer, or put the MEOWKit into **USB MSC Mode** (`Settings -> USB MSC`).
2. Run the automated sync utility:
```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync_sd_apps.ps1
```

### Manual Sync
Copy the entire contents of this repository directly to the root of your FAT32-formatted MicroSD card:
```
Copy-Item -Path .\* -Destination "K:\" -Recurse -Force
```

---

## 🏴‍☠️ Author & Credits

* **Curator & Lead Architect:** DarkCyfr (Navy Veteran · Cyber Security Operations)
* **Target Hardware:** WhitecliffTech / Mingo MEOWKit ESP32-S3
* **Companion Firmware:** [MeowKit-DarkCyfr-Edition](https://github.com/cypher82006/MeowKit-DarkCyfr-Edition)
* **License:** MIT License
