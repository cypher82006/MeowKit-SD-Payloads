-- ══════════════════════════════════════════════════════════════
-- MEOWKit S3 // Tactical Network Triage & Lab Health Auditor
-- Author: DarkCyfr
-- Measures latency, HTTP response times, and Wi-Fi link quality
-- Configuration: /config/triage.cfg and /config/wifi.cfg
-- ══════════════════════════════════════════════════════════════

local COL_BG     = 0x10A2
local COL_PANEL  = 0x18E4
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_RED    = 0xF800
local COL_WHITE  = 0xFFFF
local COL_MUTED  = 0x8410

local b_hold_start = 0
local last_check = 0
local history = {}
local current_status = "READY"
local current_ip = "0.0.0.0"
local current_rssi = 0
local avg_ping = 0

-- ── Configuration Loader ──
local function load_triage_config()
    local cfg = {
        probe_url = "http://1.1.1.1",
        interval_ms = 3000,
        timeout_ms = 3000
    }
    local content = (meow.read_file and meow.read_file("/config/triage.cfg")) or
                    (meow.read_file and meow.read_file("/triage.cfg")) or
                    (meow.read_file and meow.read_file("/config/triage.cfg.example"))
    if content then
        for line in content:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^[#;]") and not line:match("^%-%-") then
                local k, v = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                if k and v then
                    k = k:upper()
                    if k == "PROBE_URL" or k == "TARGET_HOST" then
                        cfg.probe_url = v
                    elseif k == "INTERVAL_MS" then
                        cfg.interval_ms = tonumber(v) or 3000
                    elseif k == "TIMEOUT_MS" then
                        cfg.timeout_ms = tonumber(v) or 3000
                    end
                end
            end
        end
    else
        if meow.write_file then
            local tpl = "# NETWORK TRIAGE & LATENCY AUDITOR CONFIG\n" ..
                        "# Target HTTP/HTTPS endpoint to probe\n" ..
                        "PROBE_URL=http://1.1.1.1\n" ..
                        "# Probe interval in milliseconds\n" ..
                        "INTERVAL_MS=3000\n" ..
                        "# HTTP probe timeout in milliseconds\n" ..
                        "TIMEOUT_MS=3000\n"
            meow.write_file("/config/triage.cfg", tpl)
        end
    end
    return cfg
end

-- ── Wi-Fi Auto-Connector ──
local function ensure_wifi()
    local stat = meow.wifi_status()
    if stat and stat.connected then return stat end

    local content = (meow.read_file and meow.read_file("/config/wifi.cfg")) or
                    (meow.read_file and meow.read_file("/wifi.cfg"))
    if content then
        local ssid = content:match("SSID=([^\r\n]+)")
        local pass = content:match("PASSWORD=([^\r\n]+)")
        if ssid and pass and ssid ~= "YOUR_SSID" then
            current_status = "CONNECTING WIFI..."
            meow.text(12, 100, "Arming Wi-Fi Link: " .. ssid, COL_ORANGE)
            meow.wifi_connect(ssid, pass)
            meow.delay(1500)
            return meow.wifi_status()
        end
    end
    return stat
end

local config = load_triage_config()

function do_triage()
    local stat = ensure_wifi()

    if stat and stat.connected then
        current_ip = stat.ip
        current_rssi = stat.rssi
        current_status = "LINK ACTIVE"

        -- HTTP Probe Latency
        local t0 = meow.millis()
        local code, body = meow.http_get(config.probe_url, config.timeout_ms)
        local elapsed = meow.millis() - t0

        if code and code > 0 then
            table.insert(history, elapsed)
            if #history > 24 then table.remove(history, 1) end
            
            -- Recalculate average
            local sum = 0
            for _, v in ipairs(history) do sum = sum + v end
            avg_ping = math.floor(sum / #history)
            current_status = string.format("HTTP %d OK (%d ms)", code, elapsed)
            meow.led(0, 40, 0)
        else
            current_status = "PROBE TIMEOUT"
            meow.led(50, 0, 0)
        end
    else
        current_status = "NO LINK"
        meow.led(40, 20, 0)
    end
end

function draw_screen()
    meow.clear(COL_BG)

    -- Header
    meow.rect(0, 0, 320, 24, COL_PANEL, true)
    meow.text(8, 4, "[ NETWORK TRIAGE & LAB AUDITOR ]", COL_LIME)

    -- Status Card
    meow.rect(10, 30, 300, 48, COL_PANEL, true)
    meow.rect(10, 30, 300, 48, COL_MUTED, false)
    meow.text(18, 36, "IP: " .. current_ip, COL_WHITE)
    meow.text(18, 54, "STATE: " .. current_status, COL_CYAN)
    meow.text(205, 36, string.format("RSSI: %d dBm", current_rssi), COL_MUTED)
    meow.text(205, 54, string.format("AVG: %d ms", avg_ping), COL_LIME)

    -- Latency Histogram
    meow.text(12, 86, string.format("PROBE: %s", config.probe_url), COL_MUTED)
    meow.rect(10, 102, 300, 95, COL_PANEL, true)
    meow.rect(10, 102, 300, 95, COL_MUTED, false)

    -- Render bars
    for i, lat in ipairs(history) do
        local bar_h = math.min(80, math.floor(lat / 3))
        local bx = 16 + (i - 1) * 12
        local by = 190 - bar_h
        local col = (lat < 100) and COL_LIME or ((lat < 250) and COL_ORANGE or COL_RED)
        meow.rect(bx, by, 8, bar_h, col, true)
    end

    -- Footer
    meow.rect(0, 216, 320, 24, COL_PANEL, true)
    meow.text(8, 220, "[A] Force Ping  [Hold B] Exit", COL_WHITE)
end

-- First run
do_triage()
draw_screen()

function on_loop()
    -- Immediate Button [B] Hold-to-Exit check
    if meow.btn("B") then
        if b_hold_start == 0 then
            b_hold_start = meow.millis()
        elseif meow.millis() - b_hold_start > 400 then
            meow.tone(1200, 60)
            meow.led(0, 0, 0)
            return false
        end
    else
        b_hold_start = 0
    end

    -- Manual Ping on [A]
    if meow.btn("A") then
        do_triage()
        draw_screen()
        meow.delay(300)
    end

    -- Background Ping Interval
    local now = meow.millis()
    if now - last_check >= config.interval_ms then
        last_check = now
        do_triage()
        draw_screen()
    end

    meow.delay(20)
    return true
end
