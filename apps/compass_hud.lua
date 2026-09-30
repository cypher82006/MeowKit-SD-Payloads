-- ══════════════════════════════════════════════════════════════
-- MEOWKit S3 // Tactical Compass & Artificial Horizon HUD
-- Author: DarkCyfr
-- Uses 9-Axis BMI270 Accel/Gyro + BMM150 Magnetometer
-- ══════════════════════════════════════════════════════════════

local COL_BG     = 0x10A2
local COL_PANEL  = 0x18E4
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_WHITE  = 0xFFFF
local COL_MUTED  = 0x8410
local COL_RED    = 0xF800

-- Lua 5.4 compliant 2-argument arctangent
local function atan2_safe(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    else
        return math.atan(y, x)
    end
end

local function get_heading(mx, my)
    if (mx == 0 and my == 0) then return 0.0 end
    local heading = atan2_safe(my, mx) * (180.0 / 3.14159265)
    if heading < 0 then heading = heading + 360.0 end
    return heading
end

local function get_cardinal(deg)
    local dirs = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
    local idx = math.floor((deg + 22.5) / 45) % 8 + 1
    return dirs[idx]
end

local cx, cy = 160, 110
local r = 55
local inited = false

local function init_hud()
    meow.clear(COL_BG)

    -- Header bar
    meow.rect(0, 0, 320, 24, COL_PANEL, true)
    meow.text(8, 4, "[ TACTICAL COMPASS & HORIZON ]", COL_LIME)

    -- Horizon Center Reticle
    meow.circle(cx, cy, r, COL_PANEL, true)
    meow.circle(cx, cy, r, COL_CYAN, false)

    -- Heading Box
    meow.rect(10, 32, 90, 48, COL_PANEL, true)
    meow.rect(10, 32, 90, 48, COL_MUTED, false)
    meow.text(18, 38, "HEADING", COL_MUTED)

    -- Attitude Box
    meow.rect(220, 32, 90, 48, COL_PANEL, true)
    meow.rect(220, 32, 90, 48, COL_MUTED, false)
    meow.text(228, 38, "ATTITUDE", COL_MUTED)

    -- G-Force Panel Label
    meow.text(12, 175, "ACCEL G-VECTORS", COL_MUTED)

    -- Footer
    meow.rect(0, 216, 320, 24, COL_PANEL, true)

    inited = true
end

local last_sec = 0

function on_loop()
    if not inited then
        init_hud()
    end

    -- Query Sensors
    local ax, ay, az = meow.imu()
    local gx, gy, gz = meow.gyro()
    local mx, my, mz = meow.mag()
    local temp = meow.temp()
    local vbat, pbat = meow.bat()

    -- Calculate Pitch & Roll from Accelerometer (Lua 5.4 safe)
    local denom = math.sqrt(ay * ay + az * az)
    if denom == 0 then denom = 0.0001 end
    local pitch = atan2_safe(-ax, denom) * (180.0 / 3.14159265)
    local roll  = atan2_safe(ay, az == 0 and 0.0001 or az) * (180.0 / 3.14159265)

    -- Calculate Heading
    local heading = get_heading(mx, my)
    local cardinal = get_cardinal(heading)

    -- Refresh Dynamic Horizon Center Disc
    meow.circle(cx, cy, r - 2, COL_PANEL, true)

    -- Pitch & Roll horizon line
    local pitch_shift = math.floor(pitch * 0.7)
    if pitch_shift > 35 then pitch_shift = 35 end
    if pitch_shift < -35 then pitch_shift = -35 end
    local roll_rad = roll * (3.14159265 / 180.0)
    local lx = math.floor(cx - math.cos(roll_rad) * 40)
    local rx = math.floor(cx + math.cos(roll_rad) * 40)
    local ly = math.floor(cy + pitch_shift - math.sin(roll_rad) * 40)
    local ry = math.floor(cy + pitch_shift + math.sin(roll_rad) * 40)

    -- Crosshair reticle
    meow.rect(cx - 8, cy, 16, 2, COL_LIME, true)
    meow.rect(cx, cy - 8, 2, 16, COL_LIME, true)

    -- Horizon tick line
    meow.circle(lx, ly, 2, COL_ORANGE, true)
    meow.circle(rx, ry, 2, COL_ORANGE, true)

    -- Heading Readout Update
    meow.rect(15, 54, 80, 18, COL_PANEL, true)
    meow.text(18, 54, string.format("%03d' %s", math.floor(heading), cardinal), COL_ORANGE)

    -- Attitude Readout Update
    meow.rect(225, 54, 80, 18, COL_PANEL, true)
    meow.text(228, 54, string.format("P:%2.0f R:%2.0f", pitch, roll), COL_CYAN)

    -- G-Force Vector Bars (differential clear)
    local function draw_g_bar(lbl, val, x, y)
        meow.rect(x + 20, y, 70, 14, COL_BG, true)
        meow.text(x, y, lbl, COL_WHITE)
        local bar_len = math.floor(math.abs(val) * 30)
        if bar_len > 45 then bar_len = 45 end
        local col = (val >= 0) and COL_LIME or COL_ORANGE
        meow.rect(x + 22, y + 2, math.floor(bar_len), 8, col, true)
    end
    draw_g_bar("X:", ax, 12, 192)
    draw_g_bar("Y:", ay, 110, 192)
    draw_g_bar("Z:", az, 210, 192)

    -- Temperature & Battery (1Hz refresh)
    local now_sec = math.floor(meow.millis() / 1000)
    if now_sec ~= last_sec then
        last_sec = now_sec
        meow.rect(240, 4, 75, 18, COL_PANEL, true)
        meow.text(240, 4, string.format("%.1f'C", temp), COL_CYAN)

        meow.rect(8, 220, 305, 18, COL_PANEL, true)
        meow.text(8, 220, string.format("BAT: %d%% (%.2fV)  [Hold B] Exit", math.floor(pbat), vbat), COL_WHITE)
    end

    meow.delay(35) -- ~30 FPS buttery smooth
end
