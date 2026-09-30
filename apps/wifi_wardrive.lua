-- ══════════════════════════════════════════════════════════════
-- MEOWKit S3 // Tactical Wi-Fi Wardriver & Spectrum Recon
-- Author: DarkCyfr
-- Features: 802.11 Sniffer, Auto-Decloaker for Hidden SSIDs,
--           Direct CSV Wardrive Logger, Real-Time HUD
-- Configuration: /config/wardrive.cfg (or /wardrive.cfg)
-- ══════════════════════════════════════════════════════════════

local COL_BG     = 0x10A2
local COL_PANEL  = 0x18E4
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_RED    = 0xF800
local COL_WHITE  = 0xFFFF
local COL_MUTED  = 0x8410

-- ── Configuration Loader ──
local function load_wardrive_config()
    local cfg = {
        scan_interval = 4000,
        log_file = "/wardrive.csv",
        auto_decloak = true,
        min_rssi = -95
    }

    local content = (meow.read_file and meow.read_file("/config/wardrive.cfg")) or
                    (meow.read_file and meow.read_file("/wardrive.cfg")) or
                    (meow.read_file and meow.read_file("/config/wardrive.cfg.example"))

    if content then
        for line in content:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^[#;]") and not line:match("^%-%-") then
                local k, v = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                if k and v then
                    k = k:upper()
                    if k == "SCAN_INTERVAL_MS" or k == "SCAN_INTERVAL" then
                        cfg.scan_interval = tonumber(v) or 4000
                    elseif k == "LOG_FILE" then
                        cfg.log_file = v
                    elseif k == "AUTO_DECLOAK" then
                        cfg.auto_decloak = (v:lower() == "true" or v == "1")
                    elseif k == "MIN_RSSI" then
                        cfg.min_rssi = tonumber(v) or -95
                    end
                end
            end
        end
    else
        if meow.write_file then
            local tpl = "# TACTICAL WI-FI WARDRIVER & SPECTRUM RECON CONFIG\n" ..
                        "# Scan interval in milliseconds\n" ..
                        "SCAN_INTERVAL_MS=4000\n" ..
                        "# Destination CSV log file on MicroSD\n" ..
                        "LOG_FILE=/wardrive.csv\n" ..
                        "# Automatically attempt promiscuous probe decloaking of hidden SSIDs\n" ..
                        "AUTO_DECLOAK=true\n" ..
                        "# Minimum RSSI threshold to log\n" ..
                        "MIN_RSSI=-95\n"
            meow.write_file("/config/wardrive.cfg", tpl)
        end
    end
    return cfg
end

local config = load_wardrive_config()

local ap_list = {}
local total_logged = 0
local total_decloaked = 0
local last_scan = 0
local scanning = false
local b_hold_start = 0
local decloaked_cache = {}

-- Safe file append helper
local function append_record(path, line)
    if meow.append_file then
        return meow.append_file(path, line)
    end
    local prev = (meow.read_file and meow.read_file(path)) or ""
    if meow.write_file then
        return meow.write_file(path, prev .. line)
    end
    return false
end

-- Initialize CSV header if not exists
local existing_csv = meow.read_file and meow.read_file(config.log_file)
if not existing_csv or #existing_csv == 0 then
    if meow.write_file then
        meow.write_file(config.log_file, "Timestamp_ms,BSSID,SSID,RSSI,Channel,Encrypted,Decloaked\n")
    end
end

function draw_hud()
    meow.clear(COL_BG)

    -- Top Header
    meow.rect(0, 0, 320, 24, COL_PANEL, true)
    meow.text(8, 4, "[ WARDRIVE // SPECTRUM RECON ]", COL_LIME)
    meow.text(230, 4, string.format("%d APs | %d *", #ap_list, total_decloaked), COL_CYAN)

    -- Subheader Stats
    local open_count = 0
    local hidden_count = 0
    for _, ap in ipairs(ap_list) do
        if not ap.encrypted then open_count = open_count + 1 end
        if ap.is_hidden and not ap.decloaked then hidden_count = hidden_count + 1 end
    end
    local stats = string.format("Open: %d | Encrypted: %d | Hidden: %d | Log: %d",
        open_count, #ap_list - open_count, hidden_count, total_logged)
    meow.text(8, 28, stats, COL_MUTED)

    -- Render AP list (up to 5 entries)
    local y = 46
    for i = 1, math.min(5, #ap_list) do
        local ap = ap_list[i]
        local col = ap.decloaked and COL_LIME or (ap.encrypted and COL_WHITE or COL_RED)
        local tag = ap.decloaked and "[DE-CLOAK]" or (ap.is_hidden and "[HIDDEN]" or (ap.encrypted and "[SEC]" or "[OPEN]"))
        local tag_col = ap.decloaked and COL_LIME or (ap.is_hidden and COL_ORANGE or (ap.encrypted and COL_CYAN or COL_RED))

        meow.rect(6, y, 308, 30, COL_PANEL, true)
        meow.rect(6, y, 308, 30, ap.decloaked and COL_LIME or COL_MUTED, false)

        -- RSSI Signal Bar
        local bar_w = math.max(4, math.min(50, math.floor((ap.rssi + 100) * 1.0)))
        local bar_col = ap.rssi > -60 and COL_LIME or (ap.rssi > -75 and COL_CYAN or COL_ORANGE)
        meow.rect(12, y + 8, bar_w, 14, bar_col, true)

        -- SSID Display
        local display_name = ap.ssid
        if ap.decloaked then
            display_name = "*" .. string.sub(ap.ssid, 1, 14)
        elseif ap.is_hidden then
            display_name = "<CLOAKED-AP>"
        else
            display_name = string.sub(ap.ssid, 1, 15)
        end

        meow.text(68, y + 6, display_name, col)
        meow.text(188, y + 6, string.format("CH%d %ddB", ap.channel, ap.rssi), COL_MUTED)
        meow.text(256, y + 6, tag, tag_col)

        y = y + 33
    end

    -- Bottom Navigation Bar
    meow.rect(0, 216, 320, 24, COL_PANEL, true)
    local status_txt = scanning and "SNIFFING & PROBING SPECTRUM..." or "[A] Scan  [Hold B] Exit"
    meow.text(8, 220, status_txt, scanning and COL_ORANGE or COL_WHITE)
end

function do_scan()
    scanning = true
    draw_hud()
    meow.led(0, 50, 50)

    local results = meow.wifi_scan()
    if results and #results > 0 then
        for _, ap in ipairs(results) do
            local is_hidden = (ap.hidden == true) or (#ap.ssid == 0) or (ap.ssid == "<HIDDEN>")
            ap.is_hidden = is_hidden

            if ap.bssid and decloaked_cache[ap.bssid] then
                ap.ssid = decloaked_cache[ap.bssid]
                ap.decloaked = true
                ap.is_hidden = false
            elseif is_hidden and ap.bssid and config.auto_decloak then
                if meow.wifi_decloak then
                    meow.led(255, 120, 0)
                    local revealed = meow.wifi_decloak(ap.bssid, ap.channel, 1200)
                    if revealed and #revealed > 0 then
                        ap.ssid = revealed
                        ap.decloaked = true
                        ap.is_hidden = false
                        decloaked_cache[ap.bssid] = revealed
                        total_decloaked = total_decloaked + 1
                        meow.tone(2800, 100)
                    end
                end
            end
        end

        ap_list = results
        table.sort(ap_list, function(a, b) return a.rssi > b.rssi end)

        -- Append to CSV log
        local now = meow.millis()
        for _, ap in ipairs(results) do
            if ap.rssi >= config.min_rssi then
                local bssid_str = ap.bssid or "UNKNOWN"
                local clean_ssid = ap.ssid:gsub("\"", "'")
                local is_dec = ap.decloaked and "true" or "false"
                local line = string.format("%d,\"%s\",\"%s\",%d,%d,%s,%s\n",
                    now, bssid_str, clean_ssid, ap.rssi, ap.channel, tostring(ap.encrypted), is_dec)
                append_record(config.log_file, line)
                total_logged = total_logged + 1
            end
        end
        meow.tone(1400, 30)
    end

    meow.led(0, 0, 0)
    scanning = false
    draw_hud()
end

do_scan()

function on_loop()
    if meow.btn("B") or meow.btn(1) then
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

    if (meow.btn("A") or meow.btn(0)) and not scanning then
        do_scan()
        meow.delay(200)
    end

    local now = meow.millis()
    if now - last_scan >= config.scan_interval and not scanning then
        last_scan = now
        do_scan()
    end

    meow.delay(25)
    return true
end
