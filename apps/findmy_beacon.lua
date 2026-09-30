-- ========================================================
--  MEOWKit S3 // FINDMY & AIRTAG BLE BEACON EMULATOR
--  Protocol: Apple Continuity Offline Finding (0x004C / 0x12)
--  Author: DarkCyfr Tactical Suite
--  Optimized: Zero-Flicker Differential Display Engine
-- ========================================================

local COL_BG      = 0x10A2
local COL_PANEL   = 0x18E4
local COL_BORDER  = 0x31A6
local COL_CYAN    = 0x07FF
local COL_LIME    = 0xBEE7
local COL_ORANGE  = 0xFD20
local COL_RED     = 0xF800
local COL_WHITE   = 0xFFFF
local COL_MUTED   = 0x8410

local beacon_active = false
local packets_sent = 0
local start_ms = 0
local last_sec = -1
local b_held_start = 0
local inited = false

local function init_screen()
    meow.clear(COL_BG)
    meow.led(0, 0, 0)

    -- Header bar
    meow.rect(0, 0, 320, 24, COL_PANEL, true)
    meow.rect(0, 24, 320, 1, COL_CYAN, true)
    meow.text(8, 4, "FINDMY / AIRTAG BEACON", COL_WHITE)
    meow.text(215, 4, "[STANDBY]", COL_CYAN)

    -- Protocol Specification Card
    meow.rect(10, 32, 300, 58, COL_PANEL, true)
    meow.rect(10, 32, 300, 58, COL_BORDER, false)
    meow.text(18, 38, "BLE ADVERTISEMENT SPEC", COL_CYAN)
    meow.text(18, 54, "Company: Apple Inc (0x004C) · Type: 0x12", COL_WHITE)
    meow.text(18, 70, "Ecosystem: OpenHaystack & Apple Find My", COL_MUTED)

    -- Status Telemetry Card
    meow.rect(10, 96, 300, 52, COL_PANEL, true)
    meow.rect(10, 96, 300, 52, COL_BORDER, false)
    meow.text(18, 102, "BEACON STATE", COL_MUTED)
    meow.text(18, 120, "STATUS: INACTIVE / RADIO OFF", COL_ORANGE)

    -- Operator Intel Card
    meow.rect(10, 154, 300, 54, COL_PANEL, true)
    meow.rect(10, 154, 300, 54, COL_BORDER, false)
    meow.text(18, 160, "NETWORK INTEL", COL_MUTED)
    meow.text(18, 176, "Nearby Apple devices relay this signal", COL_WHITE)
    meow.text(18, 190, "to Apple servers anonymously via E2EE.", COL_CYAN)

    -- Footer bar
    meow.rect(0, 218, 320, 22, COL_PANEL, true)
    meow.rect(0, 217, 320, 1, COL_BORDER, true)
    meow.text(8, 221, "[A] START BEACON", COL_CYAN)
    meow.text(185, 221, "HOLD [B] EXIT", COL_ORANGE)

    inited = true
end

local function update_state_ui(active)
    -- Update header badge
    meow.rect(210, 2, 105, 20, COL_PANEL, true)
    if active then
        meow.text(210, 4, "[BROADCAST]", COL_LIME)
    else
        meow.text(215, 4, "[STANDBY]", COL_CYAN)
    end

    -- Update status box border
    meow.rect(10, 96, 300, 52, active and COL_LIME or COL_BORDER, false)

    -- Update footer prompt
    meow.rect(8, 220, 160, 18, COL_PANEL, true)
    if active then
        meow.text(8, 221, "[A] STOP BEACON", COL_ORANGE)
    else
        meow.text(8, 221, "[A] START BEACON", COL_CYAN)
    end
end

function on_loop()
    if not inited then
        init_screen()
    end

    local now = meow.millis()

    -- ── Quick-Exit Check ──
    if meow.btn("B") or meow.btn(1) then
        if b_held_start == 0 then
            b_held_start = now
        elseif (now - b_held_start > 380) then
            if beacon_active then
                meow.ble_airtag(false)
            end
            meow.led(0, 0, 0)
            return false
        end
    else
        b_held_start = 0
    end

    -- ── Controls: Button A Toggles Beacon ──
    if meow.btn("A") or meow.btn(0) then
        beacon_active = not beacon_active
        if beacon_active then
            start_ms = now
            packets_sent = 0
            last_sec = -1
            meow.ble_airtag(true)
            meow.tone(2200, 60)
            meow.delay(60)
            meow.tone(2600, 90)
        else
            meow.ble_airtag(false)
            meow.led(0, 0, 0)
            meow.tone(1200, 100)

            -- Reset status text to idle
            meow.rect(18, 118, 280, 24, COL_PANEL, true)
            meow.text(18, 120, "STATUS: INACTIVE / RADIO OFF", COL_ORANGE)
        end
        update_state_ui(beacon_active)
        meow.delay(220)
    end

    -- ── Beacon Active Processing ──
    if beacon_active then
        packets_sent = math.floor((now - start_ms) / 160)
        local cur_sec = math.floor((now - start_ms) / 1000)

        -- Update display text once per second (differential, zero flicker)
        if cur_sec ~= last_sec then
            last_sec = cur_sec
            meow.rect(18, 118, 280, 24, COL_PANEL, true)
            meow.text(18, 120, string.format("STATUS: ACTIVE (%ds | %d pkts)", cur_sec, packets_sent), COL_LIME)
        end

        -- Smooth Apple Cyan-Blue pulse
        local pulse = (now % 1000)
        if pulse < 80 then
            meow.led(0, 80, 220)
        else
            meow.led(0, 0, 0)
        end
    end

    meow.delay(30) -- Fluid 33 FPS event polling with zero bus load
    return true
end
