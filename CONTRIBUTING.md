# 🛠️ Contributing to MeowKit-SD-Payloads

Welcome, Operator. This repository houses the offensive, defensive, and diagnostic payload arsenal for the **MEOWKit ESP32-S3 Handheld Cyber Multitool**.

Whether you are writing dynamic Lua 5.4 scripts, compiling sandboxed WebAssembly (`.wasm`) binaries, crafting BadUSB DuckyScript injections, or capturing infrared dictionaries, please adhere to these standards.

---

## 🧭 Code of Conduct

All contributors must follow our [Code of Conduct](CODE_OF_CONDUCT.md). We maintain a zero-tolerance policy for harassment, sabotage, or the submission of destructive, uncontained malware.

---

## 📂 Repository Layout & Contribution Types

```
SD_CARD_ROOT/
├── apps/         # Dynamic Lua 5.4 (.lua) and WebAssembly (.wasm) applications
├── badusb/       # DuckyScript keystroke injection scripts & keyboard layout maps (.kl)
├── config/       # Universal configuration files (.cfg.example)
└── infrared/     # Raw infrared remote dictionary profiles (.ir)
```

---

## ⚙️ The Universal Configuration Rule (`/config/`)

**Crucial Architecture Standard:**
No payload may require a user to edit its Lua code or recompile its WASM binary to change target IPs, ports, Wi-Fi credentials, or thresholds.

1. **Always read from `/config/<app_name>.cfg`:**
   * Provide a companion template named `/config/<app_name>.cfg.example`.
   * If the `.cfg` file is missing on the SD card, the app must fall back to safe defaults **and** automatically write a documented `.cfg` template to the SD card.
2. **Never commit private credentials or personal IPs:**
   * Commit only `.example` files in `/config/`.
   * Real active credentials (`wifi.cfg`) must remain gitignored.

---

## 📜 Lua 5.4 Scripting Guidelines (`/apps/*.lua`)

All Lua apps run on the embedded Lua 5.4 interpreter inside App 11:

### 1. Memory Discipline
* The ESP32-S3 allocates the Lua state into **8 MB Octal PSRAM**, but graphics and network queues share internal memory. Avoid runaway table allocations inside infinite loops.
* Reuse tables where possible. Never create temporary tables inside frame-rendering loops.

### 2. Rendering & Frame Timing
* Use LovyanGFX double-buffering methods (`meow.fill_screen()`, `meow.draw_rect()`, `meow.draw_text()`).
* Always yield to the FreeRTOS scheduler:
  ```lua
  meow.delay(10) -- mandatory yield to allow background Wi-Fi and audio tasks to execute
  ```
* Standard display resolution is **320x240 pixels**.

### 3. Native File I/O
* Use the firmware's native C++ file operations for speed:
  * `meow.read_file(path)`
  * `meow.write_file(path, data)`
  * `meow.append_file(path, data)` (Streaming logs, e.g., `/wardrive.csv`)

### 4. Deterministic Teardown
* Check for user exit (`meow.btn_b()` held).
* If the app initialized Wi-Fi promiscuous mode, raw sockets, or I2S audio, ensure it shuts them down cleanly before exiting back to the launcher menu.

---

## ⚡ WebAssembly Standards (`/apps/*.wasm`)

WASM binaries run inside the embedded **Wasm3** interpreter:

1. **Stack Limit:** The Wasm3 runtime stack is strictly **16 KB** (`16 * 1024` bytes). Keep stack frames shallow.
2. **Memory:** Allocate buffers as static arrays in linear memory. Do not allocate multi-megabyte heap segments.
3. **Compilation Target:** Must target `wasm32-unknown-unknown` with `no_std`:
   ```bash
   rustc --target wasm32-unknown-unknown -C opt-level=z -C lto=yes -C panic=abort -C link-arg=--allow-undefined -C link-arg=--strip-all --crate-type=cdylib -o payload.wasm src/lib.rs
   ```
4. **Host Environment:** Link only to the exported host functions (`meow_clear`, `meow_rect`, `meow_circle`, `meow_text`, `meow_pixel`, `meow_btn`, `meow_tone`, `meow_millis`, `meow_delay`).

---

## ⌨️ BadUSB Standards (`/badusb/scripts/`)

1. **Cross-Platform Compatibility:** Scripts must target explicit operating systems (`_win.txt`, `_linux.txt`, `_mac.txt`, `_android.txt`).
2. **Timing & Delays:** Always include realistic `DEFAULT_DELAY` and post-keystroke `DELAY 200` to prevent lost characters on slow target machines.
3. **Safe Demonstration:** Keystroke injection scripts must demonstrate tactical utility (e.g. system audit, staging, diagnostic report) without inflicting destructive hardware or partition damage.

---

## 🔀 Git Workflow & Submissions

1. **Branching:** Create a clean branch from `main`:
   ```bash
   git checkout -b payload/subghz-analyzer
   ```
2. **Testing:** Test the script or WASM binary on physical MEOWKit hardware. Confirm it does not crash or exhaust RAM.
3. **Documentation:** Update the root [`README.md`](README.md) manifest table with the new app's name, type, and description.
4. **Pull Request:** Submit a PR using our [Pull Request Template](.github/pull_request_template.md).
