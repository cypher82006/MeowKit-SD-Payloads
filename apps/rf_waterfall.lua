-- ==============================================================================
-- MEOWKit S3 Dynamic App: RF / Spectrum Waterfall Display
-- Operator: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/rf_waterfall.lua)
-- ==============================================================================

local COL_BG     = 0x0000
local COL_PANEL  = 0x10A2
local COL_BORDER = 0x2124
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_TEXT   = 0xFFFF
local COL_MUTED  = 0x7BEF

-- Color heatmap gradient: Black -> Blue -> Cyan -> Green -> Yellow -> Red
local function get_rssi_color(rssi)
    if rssi < -85 then return 0x0010      -- Dark Blue
    elseif rssi < -75 then return 0x001F  -- Blue
    elseif rssi < -65 then return 0x07FF  -- Cyan
    elseif rssi < -55 then return 0x07E0  -- Green
    elseif rssi < -45 then return 0xFFE0  -- Yellow
    else return 0xF800                    -- Red (Hot)
    end
end

-- Channel energy (1 to 13)
local channels = {}
for ch = 1, 13 do
    channels[ch] = { max_rssi = -100, ap_count = 0 }
end

local total_aps = 0
local cleanest_ch = 1
local scanning = false
local last_scan = 0
local scan_interval = 4000
local waterfall_row = 150 -- Y position where waterfall begins

meow.clear(COL_BG)

function on_loop()
    local now = meow.millis()

    -- Header
    meow.rect(10, 6, 300, 28, COL_PANEL, true)
    meow.rect(10, 6, 300, 28, COL_CYAN, false)
    meow.text(16, 12, "RF SPECTRUM // 2.4GHZ WATERFALL", COL_CYAN)

    -- Immediate exit check for Button B
    if meow.btn("B") then
        return
    end

    -- Trigger WiFi Scan
    if now - last_scan > scan_interval then
        last_scan = now
        scanning = true
        meow.text(230, 12, "[SCANNING]", COL_LIME)
        
        -- Reset channel buckets
        for ch = 1, 13 do
            channels[ch].max_rssi = -100
            channels[ch].ap_count = 0
        end

        local aps = meow.wifi_scan()
        total_aps = #aps
        
        for _, ap in ipairs(aps) do
            local ch = ap.channel
            if ch and ch >= 1 and ch <= 13 then
                channels[ch].ap_count = channels[ch].ap_count + 1
                if ap.rssi > channels[ch].max_rssi then
                    channels[ch].max_rssi = ap.rssi
                end
            end
        end

        -- Calculate cleanest channel
        local min_density = 999
        for ch = 1, 13 do
            local density = channels[ch].ap_count * 20 + (channels[ch].max_rssi + 100)
            if density < min_density then
                min_density = density
                cleanest_ch = ch
            end
        end

        -- Waterfall row draw: draw current channel energy across bottom
        for ch = 1, 13 do
            local col = get_rssi_color(channels[ch].max_rssi)
            local wx = 15 + (ch - 1) * 22
            meow.rect(wx, waterfall_row, 20, 10, col, true)
        end
        waterfall_row = waterfall_row + 11
        if waterfall_row > 210 then
            waterfall_row = 150
            meow.rect(15, 150, 290, 70, COL_BG, true) -- clear waterfall zone
        end

        -- Spectrum LED color
        if total_aps > 20 then
            meow.led(60, 0, 0) -- Congested
        elseif total_aps > 8 then
            meow.led(40, 30, 0) -- Moderate
        else
            meow.led(0, 40, 20) -- Clean
        end

        scanning = false
    end

    -- Real-Time Channel Bar Graph (Y: 40 to 135)
    meow.rect(10, 38, 300, 102, COL_PANEL, true)
    meow.rect(10, 38, 300, 102, COL_BORDER, false)
    
    for ch = 1, 13 do
        local bx = 16 + (ch - 1) * 22
        local rssi = channels[ch].max_rssi
        local height = math.floor(math.max(2, (rssi + 100) * 0.95))
        local col = get_rssi_color(rssi)
        
        -- Background column guide
        meow.rect(bx, 44, 18, 75, 0x0841, true)
        -- Signal level bar
        meow.rect(bx, 119 - height, 18, height, col, true)
        -- Channel label
        meow.text(bx + 3, 122, tostring(ch), (ch == cleanest_ch) and COL_LIME or COL_MUTED)
    end

    -- Telemetry stats
    meow.text(16, 42, string.format("TOTAL APs: %d", total_aps), COL_TEXT)
    meow.text(180, 42, string.format("CLEANEST CH: %d", cleanest_ch), COL_LIME)

    -- Waterfall label
    meow.text(16, 142, "WATERFALL HEATMAP [1-13]:", COL_MUTED)
    meow.text(16, 222, "[A] Force Sweep   |   Hold [B] Return", COL_MUTED)

    if meow.btn("A") and (now - last_scan > 500) then
        last_scan = 0
        meow.tone(1800, 40)
    end
end
