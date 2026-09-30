-- ========================================================
--  MEOWKIT // SENTINEL MOTION TAMPER ALARM
--  Hardware: Bosch BMI270 6-Axis IMU + Speaker + WS2812B
--  Author: DarkCyfr Tactical Suite
--  Configuration: /config/alarm.cfg (or /alarm.cfg)
-- ========================================================

local COL_BG      = 0x10A2
local COL_PANEL   = 0x18E4
local COL_BORDER  = 0x31A6
local COL_CYAN    = 0x07FF
local COL_LIME    = 0xBEE7
local COL_ORANGE  = 0xFD20
local COL_RED     = 0xF800
local COL_BLUE    = 0x001F
local COL_WHITE   = 0xFFFF
local COL_MUTED   = 0x8410

-- ── Configuration Loader ──
local function load_alarm_config()
    local cfg = {
        arm_delay = 5,
        sens_idx = 2,
        siren_enabled = true
    }

    local content = (meow.read_file and meow.read_file("/config/alarm.cfg")) or
                    (meow.read_file and meow.read_file("/alarm.cfg")) or
                    (meow.read_file and meow.read_file("/config/alarm.cfg.example"))

    if content then
        for line in content:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^[#;]") and not line:match("^%-%-") then
                local k, v = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                if k and v then
                    k = k:upper()
                    if k == "ARM_DELAY_SEC" or k == "ARM_DELAY" then
                        cfg.arm_delay = tonumber(v) or 5
                    elseif k == "SENSITIVITY" then
                        local s = v:upper()
                        if s == "HIGH" then cfg.sens_idx = 1
                        elseif s == "LOW" then cfg.sens_idx = 3
                        else cfg.sens_idx = 2 end
                    elseif k == "SIREN_ENABLED" or k == "SIREN" then
                        cfg.siren_enabled = (v:lower() == "true" or v == "1")
                    end
                end
            end
        end
    else
        if meow.write_file then
            local tpl = "# SENTINEL MOTION TAMPER ALARM CONFIGURATION\n" ..
                        "# Countdown delay before arming in seconds\n" ..
                        "ARM_DELAY_SEC=5\n" ..
                        "# Default sensitivity profile: HIGH, MED, or LOW\n" ..
                        "SENSITIVITY=MED\n" ..
                        "# Siren speaker audio alert enabled\n" ..
                        "SIREN_ENABLED=true\n"
            meow.write_file("/config/alarm.cfg", tpl)
        end
    end
    return cfg
end

local config = load_alarm_config()

-- Modes: 1=STANDBY, 2=ARMING, 3=ARMED, 4=ALARM
local mode = 1
local arm_start_ms = 0
local arm_delay_sec = config.arm_delay

-- Sensitivity profiles
local sens_levels = {
    { name = "HIGH (0.06 G)", thresh = 0.06 },
    { name = "MED  (0.15 G)", thresh = 0.15 },
    { name = "LOW  (0.30 G)", thresh = 0.30 }
}
local sens_idx = config.sens_idx

-- Baseline gravity vector
local base_x, base_y, base_z = 0, 0, 0
local peak_delta = 0
local breach_time_sec = 0

-- UI Animation timers
local last_draw_ms = 0
local siren_step = 0
local b_held_start = 0

function math_dist3d(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function draw_header(title, tag, col)
    meow.rect(0, 0, 320, 24, COL_PANEL, 1)
    meow.rect(0, 24, 320, 1, col, 1)
    meow.text(8, 4, title, COL_WHITE)
    meow.text(230, 4, tag, col)
end

function draw_footer(hint_left, hint_right)
    meow.rect(0, 218, 320, 22, COL_PANEL, 1)
    meow.rect(0, 217, 320, 1, COL_BORDER, 1)
    meow.text(8, 221, hint_left, COL_CYAN)
    meow.text(185, 221, hint_right, COL_ORANGE)
end

-- Top-level Init
meow.clear(COL_BG)
meow.led(0, 0, 0)

function on_loop()
    local now = meow.millis()

    -- ── Universal Quick-Exit Check ──
    if meow.btn("B") or meow.btn(1) then
        if b_held_start == 0 then
            b_held_start = now
        elseif (now - b_held_start > 380) then
            meow.led(0, 0, 0)
            return
        end
    else
        b_held_start = 0
    end

    -- ── State Machine Logic ──
    local ax, ay, az = meow.imu()

    if mode == 1 then
        -- ── STANDBY ──
        if meow.btn("A") or meow.btn(0) then
            mode = 2
            arm_start_ms = now
            meow.tone(1400, 80)
            meow.delay(180)
        elseif meow.btn("UP") or meow.btn(2) then
            sens_idx = (sens_idx % 3) + 1
            meow.tone(1800, 30)
            meow.delay(150)
        elseif meow.btn("DOWN") or meow.btn(3) then
            sens_idx = sens_idx - 1
            if sens_idx < 1 then sens_idx = 3 end
            meow.tone(1600, 30)
            meow.delay(150)
        end

    elseif mode == 2 then
        -- ── ARMING COUNTDOWN ──
        local elapsed = (now - arm_start_ms) / 1000.0
        if elapsed >= arm_delay_sec then
            mode = 3
            base_x, base_y, base_z = ax, ay, az
            peak_delta = 0
            meow.tone(2400, 200)
            meow.led(0, 40, 0)
            meow.delay(200)
        else
            if (math.floor(elapsed * 2) % 2 == 0) then
                meow.led(30, 20, 0)
            else
                meow.led(0, 0, 0)
            end
        end

    elseif mode == 3 then
        -- ── ARMED & WATCHING ──
        local delta = math_dist3d(ax, ay, az, base_x, base_y, base_z)
        if delta > peak_delta then peak_delta = delta end

        if (math.floor(now / 1500) % 2 == 0) then
            meow.led(0, 30, 0)
        else
            meow.led(0, 0, 0)
        end

        local thresh = sens_levels[sens_idx].thresh
        if delta > thresh then
            mode = 4
            breach_time_sec = 0
            meow.tone(3000, 300)
            meow.led(255, 0, 0)
        end

        if meow.btn("A") or meow.btn(0) then
            mode = 1
            meow.led(0, 0, 0)
            meow.tone(800, 100)
            meow.delay(200)
        end

    elseif mode == 4 then
        -- ── ALARM / BREACH DETECTED ──
        siren_step = (siren_step + 1) % 4
        if siren_step < 2 then
            if config.siren_enabled then meow.tone(2600, 60) end
            meow.led(255, 0, 0)
        else
            if config.siren_enabled then meow.tone(1900, 60) end
            meow.led(0, 0, 255)
        end

        local delta = math_dist3d(ax, ay, az, base_x, base_y, base_z)
        if delta > peak_delta then peak_delta = delta end

        if meow.btn("A") or meow.btn(0) then
            mode = 1
            meow.led(0, 0, 0)
            meow.tone(800, 150)
            meow.delay(250)
        end
    end

    -- ── Render at ~20 FPS ──
    if (now - last_draw_ms >= 50) then
        last_draw_ms = now

        if mode == 1 then
            meow.clear(COL_BG)
            draw_header("TAMPER SENTINEL", "[STANDBY]", COL_CYAN)

            meow.rect(10, 32, 300, 75, COL_PANEL, 1)
            meow.rect(10, 32, 300, 75, COL_BORDER, 0)
            meow.text(18, 38, "IMU 6-AXIS TELEMETRY", COL_CYAN)
            meow.text(18, 56, string.format("ACCEL X: %+0.2f G   Y: %+0.2f G", ax, ay), COL_WHITE)
            meow.text(18, 74, string.format("ACCEL Z: %+0.2f G   |G|: %0.2f G", az, math.sqrt(ax*ax + ay*ay + az*az)), COL_WHITE)

            meow.rect(10, 115, 300, 65, COL_PANEL, 1)
            meow.rect(10, 115, 300, 65, COL_BORDER, 0)
            meow.text(18, 122, "TRIP SENSITIVITY (D-PAD UP/DN):", COL_MUTED)
            meow.text(18, 142, "-> " .. sens_levels[sens_idx].name, COL_LIME)

            meow.text(18, 192, "Place on target asset & press [A] to Arm", COL_ORANGE)
            draw_footer("[A] ARM SENTINEL", "HOLD [B] EXIT")

        elseif mode == 2 then
            meow.clear(COL_BG)
            draw_header("TAMPER SENTINEL", "[ARMING]", COL_ORANGE)

            local elapsed = (now - arm_start_ms) / 1000.0
            local remain = math.max(0, math.ceil(arm_delay_sec - elapsed))

            meow.rect(10, 45, 300, 150, COL_PANEL, 1)
            meow.rect(10, 45, 300, 150, COL_ORANGE, 0)

            meow.text(50, 75, "ARMING COUNTDOWN", COL_WHITE)
            meow.text(145, 110, string.format("%d", remain), COL_ORANGE)
            meow.text(45, 155, "STABILIZING POSITION...", COL_MUTED)

            draw_footer("DO NOT MOVE DEVICE", "HOLD [B] CANCEL")

        elseif mode == 3 then
            meow.clear(COL_BG)
            draw_header("TAMPER SENTINEL", "[ARMED]", COL_LIME)

            meow.rect(10, 35, 300, 130, COL_PANEL, 1)
            meow.rect(10, 35, 300, 130, COL_LIME, 0)

            meow.text(25, 48, "SENTINEL SURVEILLANCE ACTIVE", COL_LIME)
            meow.text(25, 75, "PROFILE: " .. sens_levels[sens_idx].name, COL_WHITE)

            local cur_delta = math_dist3d(ax, ay, az, base_x, base_y, base_z)
            meow.text(25, 98, string.format("CURRENT DELTA: %0.3f G", cur_delta), COL_CYAN)
            meow.text(25, 120, string.format("TRIP THRESH:   %0.3f G", sens_levels[sens_idx].thresh), COL_MUTED)

            local bar_w = math.min(260, math.floor((cur_delta / sens_levels[sens_idx].thresh) * 260))
            meow.rect(25, 142, 260, 10, COL_BG, 1)
            if bar_w > 0 then
                meow.rect(25, 142, bar_w, 10, (bar_w > 200) and COL_ORANGE or COL_LIME, 1)
            end

            draw_footer("[A] DISARM", "HOLD [B] EXIT")

        elseif mode == 4 then
            meow.clear(COL_BG)
            draw_header("TAMPER SENTINEL", "[BREACH!]", COL_RED)

            meow.rect(10, 35, 300, 160, COL_PANEL, 1)
            meow.rect(10, 35, 300, 160, (siren_step < 2) and COL_RED or COL_BLUE, 0)

            meow.text(35, 55, "!!! TAMPER DETECTED !!!", COL_RED)
            meow.text(25, 90, "MOTION DETECTED ON TARGET ASSET", COL_WHITE)
            meow.text(25, 115, string.format("PEAK IMPACT: %0.3f G", peak_delta), COL_ORANGE)
            meow.text(25, 140, "STATUS: AUDIBLE ALARM TRIP", COL_CYAN)

            draw_footer("[A] RESET & DISARM", "HOLD [B] EXIT")
        end
    end

    meow.delay(15)
end
