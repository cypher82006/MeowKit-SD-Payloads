-- ==============================================================================
-- MEOWKit S3 Dynamic App: Cyber HUD (High-Performance Tactical Edition)
-- Operator: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/cyber_hud.lua)
-- ==============================================================================

local COL_BG     = 0x10A2
local COL_PANEL  = 0x18E4
local COL_BORDER = 0x31A6
local COL_TEXT   = 0xFFFF
local COL_MUTED  = 0x8410
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_RED    = 0xF800

local frame = 0
local last_beep = 0
local last_sec = -1
local inited = false

-- Previous state caches for differential update
local prev_btnA = false
local prev_btnB = false
local prev_dpad = false
local prev_ox = 0
local prev_oy = 0
local cx, cy = 115, 105

local function init_hud()
    meow.clear(COL_BG)

    -- Header Panel
    meow.rect(10, 10, 300, 35, COL_PANEL, true)
    meow.rect(10, 10, 300, 35, COL_CYAN, false)
    meow.text(20, 20, "DARKCYFR // MEOW-S3 HUD", COL_CYAN)

    -- IMU Telemetry Panel
    meow.rect(10, 52, 145, 115, COL_PANEL, true)
    meow.rect(10, 52, 145, 115, COL_BORDER, false)
    meow.text(18, 58, "[ IMU VECTOR ]", COL_LIME)
    meow.circle(cx, cy, 18, COL_MUTED, false)

    -- IO & Key Status Panel
    meow.rect(165, 52, 145, 115, COL_PANEL, true)
    meow.rect(165, 52, 145, 115, COL_BORDER, false)
    meow.text(173, 58, "[ INPUT MATRIX ]", COL_ORANGE)

    -- Bottom Status / Exit Bar
    meow.rect(10, 175, 300, 55, COL_PANEL, true)
    meow.rect(10, 175, 300, 55, COL_BORDER, false)
    meow.text(20, 205, "HOLD [B] TO RETURN TO SD MENU", COL_MUTED)

    inited = true
end

function on_loop()
    if not inited then
        init_hud()
    end

    frame = frame + 1
    local now = meow.millis()
    local uptime_sec = math.floor(now / 1000)

    -- ── 1. Battery & Uptime (1Hz update to save SPI / I2C bandwidth) ──
    if uptime_sec ~= last_sec then
        last_sec = uptime_sec
        local vbat, pct = meow.bat()
        meow.rect(200, 18, 100, 20, COL_PANEL, true)
        meow.text(205, 20, string.format("%2.1fV | %d%%", vbat, math.floor(pct)), COL_LIME)

        -- Bottom Frame & Uptime
        meow.rect(18, 183, 280, 20, COL_PANEL, true)
        meow.text(20, 185, string.format("FRAME: %06d | UP: %04ds", frame, uptime_sec), COL_TEXT)
    end

    -- ── 2. IMU Telemetry (Differential Updates) ──
    local ax, ay, az = meow.imu()

    -- Only clear the numeric values instead of the entire box
    meow.rect(36, 78,  60, 18, COL_PANEL, true)
    meow.rect(36, 98,  60, 18, COL_PANEL, true)
    meow.rect(36, 118, 60, 18, COL_PANEL, true)
    meow.text(18, 80,  string.format("X: %+1.2fg", ax), COL_TEXT)
    meow.text(18, 100, string.format("Y: %+1.2fg", ay), COL_TEXT)
    meow.text(18, 120, string.format("Z: %+1.2fg", az), COL_TEXT)

    -- Erase old horizon blip & draw new one
    local ox = math.floor(ax * 15)
    local oy = math.floor(ay * 15)
    if ox > 14 then ox = 14 end
    if ox < -14 then ox = -14 end
    if oy > 14 then oy = 14 end
    if oy < -14 then oy = -14 end

    if ox ~= prev_ox or oy ~= prev_oy then
        meow.circle(cx + prev_ox, cy + prev_oy, 4, COL_PANEL, true)
        meow.circle(cx, cy, 18, COL_MUTED, false) -- re-stroke ring if clipped
        meow.circle(cx + ox, cy + oy, 4, COL_CYAN, true)
        prev_ox = ox
        prev_oy = oy
    end

    -- ── 3. IO & Key Matrix (Event-driven text redraw) ──
    local btnA = meow.btn("A") or meow.btn(0)
    local btnB = meow.btn("B") or meow.btn(1)
    local btnUp = meow.btn("UP") or meow.btn(2)
    local btnDn = meow.btn("DOWN") or meow.btn(3)
    local dpad = (btnUp or btnDn)

    if btnA ~= prev_btnA then
        prev_btnA = btnA
        meow.rect(173, 78, 130, 20, COL_PANEL, true)
        meow.text(173, 80, btnA and "[A] PRESSED" or "[A] IDLE", btnA and COL_LIME or COL_MUTED)
        if btnA and (now - last_beep > 150) then
            meow.tone(1760, 40)
            last_beep = now
        end
    end

    if btnB ~= prev_btnB then
        prev_btnB = btnB
        meow.rect(173, 98, 130, 20, COL_PANEL, true)
        meow.text(173, 100, btnB and "[B] PRESSED" or "[B] IDLE", btnB and COL_ORANGE or COL_MUTED)
    end

    if dpad ~= prev_dpad then
        prev_dpad = dpad
        meow.rect(173, 118, 130, 20, COL_PANEL, true)
        meow.text(173, 120, dpad and "DPAD: ACTIVE" or "DPAD: IDLE", dpad and COL_CYAN or COL_MUTED)
    end

    meow.delay(30) -- ~33 FPS fluid rendering, zero bus congestion
end
