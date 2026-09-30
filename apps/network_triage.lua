-- ══════════════════════════════════════════════════════════════
-- MEOWKit S3 // Tactical Network Triage & Lab Health Auditor
-- Author: DarkCyfr
-- Measures latency, HTTP response times, and Wi-Fi link quality
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

-- Target Wi-Fi and probe configuration
local TARGET_SSID = "YOUR_SSID"
local TARGET_PASS = "YOUR_PASSWORD"
local TARGET_HOST = "http://1.1.1.1"

function do_triage()
    local stat = meow.wifi_status()
    if not stat.connected then
        current_status = "CONNECTING WIFI..."
        meow.text(12, 100, "Arming Wi-Fi Link...", COL_ORANGE)
        meow.wifi_connect(TARGET_SSID, TARGET_PASS)
        meow.delay(2000)
        stat = meow.wifi_status()
    end

    if stat.connected then
        current_ip = stat.ip
        current_rssi = stat.rssi
        current_status = "LINK ACTIVE"

        -- HTTP Probe Latency
        local t0 = meow.millis()
        local code, body = meow.http_get(TARGET_HOST, 3000)
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
    meow.text(210, 36, string.format("RSSI: %d dBm", current_rssi), COL_MUTED)
    meow.text(210, 54, string.format("AVG: %d ms", avg_ping), COL_LIME)

    -- Latency Histogram
    meow.text(12, 86, "LATENCY HISTOGRAM (24 PINGS)", COL_MUTED)
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

    -- Background Ping Interval (every 3 seconds)
    local now = meow.millis()
    if now - last_check >= 3000 then
        last_check = now
        do_triage()
        draw_screen()
    end

    meow.delay(20)
    return true
end
