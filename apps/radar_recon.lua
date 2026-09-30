-- ==============================================================================
-- MEOWKit S3 Dynamic App: Tactical Radar Recon
-- Author: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/radar_recon.lua)
-- Configuration: /config/radar.cfg (or /radar.cfg)
-- ==============================================================================

local COL_BG     = 0x0000
local COL_RADAR  = 0x03E0
local COL_SWEEP  = 0x07E0
local COL_BLIP   = 0xF800
local COL_TEXT   = 0x07FF
local COL_MUTED  = 0x0200
local COL_WHITE  = 0xFFFF
local COL_ORANGE = 0xFD20

-- ── Configuration Loader ──
local function load_radar_config()
    local cfg = {
        sweep_speed = 4,
        real_rf_scan = true,
        scan_interval = 12000,
        min_rssi = -90
    }

    local content = (meow.read_file and meow.read_file("/config/radar.cfg")) or
                    (meow.read_file and meow.read_file("/radar.cfg")) or
                    (meow.read_file and meow.read_file("/config/radar.cfg.example"))

    if content then
        for line in content:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^[#;]") and not line:match("^%-%-") then
                local k, v = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                if k and v then
                    k = k:upper()
                    if k == "SWEEP_SPEED" then
                        cfg.sweep_speed = tonumber(v) or 4
                    elseif k == "REAL_RF_SCAN" then
                        cfg.real_rf_scan = (v:lower() == "true" or v == "1")
                    elseif k == "SCAN_INTERVAL_MS" or k == "SCAN_INTERVAL" then
                        cfg.scan_interval = tonumber(v) or 12000
                    elseif k == "MIN_RSSI" then
                        cfg.min_rssi = tonumber(v) or -90
                    end
                end
            end
        end
    else
        if meow.write_file then
            local tpl = "# TACTICAL RADAR RECON CONFIGURATION\n" ..
                        "# Sweep rotation speed in degrees per frame\n" ..
                        "SWEEP_SPEED=4\n" ..
                        "# Live RF scan: map real nearby Wi-Fi APs onto radar screen\n" ..
                        "REAL_RF_SCAN=true\n" ..
                        "# Wi-Fi rescan interval in milliseconds\n" ..
                        "SCAN_INTERVAL_MS=12000\n" ..
                        "# Minimum RSSI threshold to display on radar\n" ..
                        "MIN_RSSI=-90\n"
            meow.write_file("/config/radar.cfg", tpl)
        end
    end
    return cfg
end

local config = load_radar_config()

local angle = 0
local cx = 160
local cy = 120
local radius = 85
local r_outer = math.floor(radius)
local r_mid   = math.floor(radius * 0.66)
local r_inner = math.floor(radius * 0.33)

local targets = {
    { r = 40, a = 45,  hit = false, name = "SIG-ALPHA" },
    { r = 65, a = 160, hit = false, name = "SIG-BRAVO" },
    { r = 30, a = 230, hit = false, name = "SIG-CHARLIE" },
    { r = 75, a = 310, hit = false, name = "SIG-DELTA" }
}

local last_rf_scan = 0
local contact_label = "STANDBY"

local function refresh_rf_targets()
    if not config.real_rf_scan or not meow.wifi_scan then return end
    local results = meow.wifi_scan()
    if results and #results > 0 then
        local new_targets = {}
        for _, ap in ipairs(results) do
            if ap.rssi >= config.min_rssi then
                -- Derive stable angle from BSSID hash
                local hash = 0
                local b = ap.bssid or ap.ssid or "00"
                for i = 1, #b do
                    hash = (hash * 31 + string.byte(b, i)) % 360
                end
                -- Map RSSI (-40 dBm = 20px, -90 dBm = 80px)
                local norm = math.max(0.1, math.min(1.0, (ap.rssi + 95) / 60.0))
                local dist = math.floor(radius * (1.05 - norm * 0.85))
                local name = ap.ssid
                if not name or #name == 0 then name = "<CLOAKED>" end
                table.insert(new_targets, {
                    r = dist,
                    a = hash,
                    hit = false,
                    name = string.sub(name, 1, 12)
                })
            end
            if #new_targets >= 12 then break end
        end
        if #new_targets > 0 then
            targets = new_targets
            contact_label = string.format("%d LIVE CONTACTS", #targets)
        end
    end
end

-- Initial static HUD draw
meow.clear(COL_BG)
meow.text(10, 10,  "TACTICAL RADAR // ACTIVE", COL_TEXT)
meow.text(10, 215, "HOLD [B] TO RETURN", COL_MUTED)

refresh_rf_targets()

function on_loop()
    local now = meow.millis()

    -- Quick check on Button B
    if meow.btn("B") or meow.btn(1) then end

    -- Trigger manual scan on Button A
    if (meow.btn("A") or meow.btn(0)) and config.real_rf_scan then
        contact_label = "SCANNING RF..."
        meow.text(10, 10,  "TACTICAL RADAR // " .. contact_label, COL_ORANGE)
        refresh_rf_targets()
        last_rf_scan = now
        meow.tone(1800, 40)
    end

    -- Periodic RF background refresh
    if config.real_rf_scan and (now - last_rf_scan > config.scan_interval) then
        last_rf_scan = now
        refresh_rf_targets()
    end

    -- Clear central radar ring area
    meow.circle(cx, cy, r_outer - 1, COL_BG, true)

    -- Draw concentric radar rings
    meow.circle(cx, cy, r_outer, COL_RADAR, false)
    meow.circle(cx, cy, r_mid,   COL_RADAR, false)
    meow.circle(cx, cy, r_inner, COL_RADAR, false)

    -- Crosshair lines
    meow.rect(cx - r_outer, cy, r_outer * 2, 1, COL_MUTED, true)
    meow.rect(cx, cy - r_outer, 1, r_outer * 2, COL_MUTED, true)

    -- Sweep line
    angle = (angle + config.sweep_speed) % 360
    local rad = angle * (3.14159265 / 180.0)
    local sx = math.floor(cx + math.cos(rad) * radius)
    local sy = math.floor(cy + math.sin(rad) * radius)
    meow.circle(sx, sy, 3, COL_SWEEP, true)

    -- Header status update
    meow.text(10, 10,  "TACTICAL RADAR // " .. contact_label, COL_TEXT)

    -- Draw contacts and ping on sweep intercept
    for _, t in ipairs(targets) do
        local diff = math.abs(angle - t.a)
        if diff < (config.sweep_speed + 2) then
            if not t.hit then
                t.hit = true
                meow.tone(2000, 25)
                meow.led(0, 40, 40)
                -- Display intercept contact name on HUD footer
                meow.rect(10, 195, 300, 16, COL_BG, true)
                meow.text(10, 195, "CONTACT: " .. t.name, COL_WHITE)
            end
        else
            t.hit = false
        end

        local trad = t.a * (3.14159265 / 180.0)
        local tx = math.floor(cx + math.cos(trad) * t.r)
        local ty = math.floor(cy + math.sin(trad) * t.r)
        meow.circle(tx, ty, 3, COL_BLIP, true)
    end

    meow.delay(25)
    return true
end
