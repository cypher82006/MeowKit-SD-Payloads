-- ==============================================================================
-- MEOWKit S3 Dynamic App: Hardware Bus Sniffer / Logic Tracer
-- Operator: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/gpio_sniffer.lua)
-- ==============================================================================

local COL_BG     = 0x0841
local COL_PANEL  = 0x18C3
local COL_BORDER = 0x31A6
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_TEXT   = 0xFFFF
local COL_MUTED  = 0x7BEF

-- Chip signature database for on-board and common peripherals
local KNOWN_CHIPS = {
    ["0x18"] = "ES8311 (Audio DAC)",
    ["0x19"] = "PCA9557 (IO Expander)",
    ["0x34"] = "AXP173 (Power PMU)",
    ["0x38"] = "FT6336 (Touch CTP)",
    ["0x41"] = "ES7210 (Mic ADC)",
    ["0x44"] = "SHT30 (Env Sensor)",
    ["0x51"] = "PCF8563 (RTC Clock)",
    ["0x68"] = "BMI270 (6-Axis IMU)"
}

local mode = 1 -- 1 = I2C Bus Scan, 2 = Logic Probe
local detected_devices = {}
local last_scan_time = 0
local last_toggle_time = 0

-- Logic waveform trace buffer (60 points)
local trace = {}
for i = 1, 60 do trace[i] = 0 end

meow.clear(COL_BG)
meow.pin_mode(8, "pullup") -- Probe GPIO 8 (Expansion pin / Joy Right)

function on_loop()
    local now = meow.millis()

    -- Header Panel
    meow.rect(10, 8, 300, 32, COL_PANEL, true)
    meow.rect(10, 8, 300, 32, COL_CYAN, false)
    meow.text(18, 16, "BUS SNIFFER // HARDWARE PROBE", COL_CYAN)
    meow.text(215, 16, mode == 1 and "[MODE: I2C]" or "[MODE: LOGIC]", COL_ORANGE)

    -- Mode Switch via [A]
    if meow.btn("A") and (now - last_toggle_time > 300) then
        last_toggle_time = now
        mode = (mode == 1) and 2 or 1
        meow.tone(1400, 40)
        meow.clear(COL_BG)
    end

    if mode == 1 then
        -- ══════════════════════════════════════════════════════
        -- MODE 1: I2C SCANNER
        -- ══════════════════════════════════════════════════════
        if now - last_scan_time > 3000 then
            last_scan_time = now
            detected_devices = meow.i2c_scan() or {}
        end

        meow.rect(10, 46, 300, 148, COL_PANEL, true)
        meow.rect(10, 46, 300, 148, COL_BORDER, false)
        meow.text(18, 52, string.format("DETECTED I2C ASSETS (%d TOTAL):", #detected_devices), COL_LIME)

        for i, addr in ipairs(detected_devices) do
            if i <= 6 then
                local y = 72 + (i - 1) * 19
                local name = KNOWN_CHIPS[addr] or "External / Custom Device"
                meow.text(22, y, addr, COL_CYAN)
                meow.text(75, y, "-> " .. name, (KNOWN_CHIPS[addr] and COL_TEXT or COL_ORANGE))
            end
        end

        meow.text(18, 204, "[A] Switch Mode   |   Hold [B] Return", COL_MUTED)

    else
        -- ══════════════════════════════════════════════════════
        -- MODE 2: LOGIC PROBE & TRACER (GPIO 8)
        -- ══════════════════════════════════════════════════════
        local val = meow.pin_read(8)
        table.remove(trace, 1)
        table.insert(trace, val)

        meow.rect(10, 46, 300, 148, COL_PANEL, true)
        meow.rect(10, 46, 300, 148, COL_BORDER, false)
        meow.text(18, 52, "GPIO 8 LOGIC STATE: " .. (val == 1 and "HIGH (3.3V)" or "LOW (0V)"), val == 1 and COL_LIME or COL_ORANGE)

        -- Draw Logic Waveform
        local baseline_y = 150
        for i = 1, #trace - 1 do
            local x1 = 20 + (i - 1) * 4
            local x2 = 20 + i * 4
            local y1 = baseline_y - (trace[i] * 50)
            local y2 = baseline_y - (trace[i+1] * 50)
            meow.rect(x1, y1, 4, 2, COL_CYAN, true)
            if y1 ~= y2 then
                -- Vertical transition edge
                local top = math.min(y1, y2)
                local h = math.abs(y1 - y2)
                meow.rect(x2, top, 2, h, COL_LIME, true)
            end
        end

        meow.text(18, 172, "REAL-TIME OSCILLOSCOPE TRACE", COL_MUTED)
        meow.text(18, 204, "[A] Switch Mode   |   Hold [B] Return", COL_MUTED)
    end
end
