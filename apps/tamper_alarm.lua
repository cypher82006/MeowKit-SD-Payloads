-- ========================================================
--  MEOWKIT // SENTINEL MOTION TAMPER ALARM
--  Hardware: Bosch BMI270 6-Axis IMU + Speaker + WS2812B
--  Author: DarkCyfr Tactical Suite
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

-- Modes: 1=STANDBY, 2=ARMING, 3=ARMED, 4=ALARM
local mode = 1
local arm_start_ms = 0
local arm_delay_sec = 5

-- Sensitivity profiles
local sens_levels = {
    { name = "HIGH (0.06 G)", thresh = 0.06 },
    { name = "MED  (0.15 G)", thresh = 0.15 },
    { name = "LOW  (0.30 G)", thresh = 0.30 }
}
local sens_idx = 2

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
    if meow.btn("B") or meow.btn(1) then -- Button B
        if b_held_start == 0 then
            b_held_start = now
        elseif (now - b_held_start > 380) then
            meow.led(0, 0, 0)
            return -- AppLoader catches hold and exits
        end
    else
        b_held_start = 0
    end

    -- ── State Machine Logic ──
    local ax, ay, az = meow.imu()

    if mode == 1 then
        -- ── STANDBY ──
        if meow.btn("A") or meow.btn(0) then -- Button A to ARM
            mode = 2
            arm_start_ms = now
            meow.tone(1400, 80)
            meow.delay(180)
        elseif meow.btn("UP") or meow.btn(2) then -- D-pad Up
            sens_idx = (sens_idx % 3) + 1
            meow.tone(1800, 30)
            meow.delay(150)
        elseif meow.btn("DOWN") or meow.btn(3) then -- D-pad Down
            sens_idx = sens_idx - 1
            if sens_idx < 1 then sens_idx = 3 end
            meow.tone(1600, 30)
            meow.delay(150)
        end

    elseif mode == 2 then
        -- ── ARMING COUNTDOWN ──
        local elapsed = (now - arm_start_ms) / 1000.0
        local remain = arm_delay_sec - elapsed

        if remain <= 0 then
            -- Calibrate baseline vector
            base_x, base_y, base_z = ax, ay, az
            mode = 3
            meow.tone(2800, 300)
            meow.led(0, 255, 0)
            meow.delay(100)
            meow.led(0, 0, 0)
        end

    elseif mode == 3 then
        -- ── ARMED / SENTINEL ACTIVE ──
        local delta = math_dist3d(ax, ay, az, base_x, base_y, base_z)

        -- Subtle sentinel heartbeat pulse every 2 seconds
        if (now % 2000) < 50 then
            meow.led(0, 30, 0)
        else
            meow.led(0, 0, 0)
        end

        if delta > sens_levels[sens_idx].thresh then
            -- BREACH DETECTED!
            mode = 4
            peak_delta = delta
            breach_time_sec = now / 1000.0
            -- Log breach event to SD
            local log_entry = string.format("[SENTINEL ALARM] Breach detected at %d s! Delta: %.3f G\n", breach_time_sec, delta)
            meow.write_file("/tamper_log.txt", log_entry)
        elseif meow.btn("A") or meow.btn(0) then
            -- Manual Disarm
            mode = 1
            meow.tone(1000, 100)
            meow.led(0, 0, 0)
            meow.delay(200)
        end

    elseif mode == 4 then
        -- ── ALARM / INTRUSION SIREN ──
        siren_step = siren_step + 1
        if (siren_step % 2) == 0 then
            meow.tone(2600, 60)
            meow.led(255, 0, 0) -- Police Red
        else
            meow.tone(1900, 60)
            meow.led(0, 0, 255) -- Police Blue
        end

        local delta = math_dist3d(ax, ay, az, base_x, base_y, base_z)
        if delta > peak_delta then peak_delta = delta end

        if meow.btn("A") or meow.btn(0) then
            -- Disarm
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
            -- STANDBY HUD
            meow.clear(COL_BG)
            draw_header("TAMPER SENTINEL", "[STANDBY]", COL_CYAN)

            -- Sensor telemetry box
            meow.rect(10, 32, 300, 75, COL_PANEL, 1)
            meow.rect(10, 32, 300, 75, COL_BORDER, 0)
            meow.text(18, 38, "IMU 6-AXIS TELEMETRY", COL_CYAN)
            meow.text(18, 56, string.format("ACCEL X: %+0.2f G   Y: %+0.2f G", ax, ay), COL_WHITE)
            meow.text(18, 74, string.format("ACCEL Z: %+0.2f G   |G|: %0.2f G", az, math.sqrt(ax*ax + ay*ay + az*az)), COL_WHITE)

            -- Sensitivity Box
            meow.rect(10, 115, 300, 65, COL_PANEL, 1)
            meow.rect(10, 115, 300, 65, COL_BORDER, 0)
            meow.text(18, 122, "TRIP SENSITIVITY (D-PAD UP/DN):", COL_MUTED)
            meow.text(18, 142, "-> " .. sens_levels[sens_idx].name, COL_LIME)

            -- Instruction
            meow.text(18, 192, "Place on target asset & press [A] to Arm", COL_ORANGE)
            draw_footer("[A] ARM SENTINEL", "HOLD [B] EXIT")

        elseif mode == 2 then
            -- ARMING COUNTDOWN
            meow.clear(COL_BG)
            draw_header("TAMPER SENTINEL", "[ARMING]", COL_ORANGE)

            local elapsed = (now - arm_start_ms) / 1000.0
            local remain = math.max(0, math.ceil(arm_delay_sec - elapsed))

            -- Countdown box
            meow.rect(20, 45, 280, 130, COL_PANEL, 1)
            meow.rect(20, 45, 280, 130, COL_ORANGE, 0)
            meow.text(45, 60, "DEPOSIT ASSET & STEP AWAY", COL_ORANGE)
            meow.text(140, 95, string.format("%d", remain), COL_WHITE)
            meow.text(55, 145, "CALIBRATING ZERO-VECTOR...", COL_CYAN)

            draw_footer("DO NOT MOVE DEVICE", "HOLD [B] CANCEL")

        elseif mode == 3 then
            -- ARMED SCREEN
            meow.clear(0x0000) -- Pitch black stealth mode with minimal HUD
            draw_header("SENTINEL ARMED", "[LOCKED]", COL_LIME)

            meow.rect(20, 50, 280, 120, COL_PANEL, 1)
            meow.rect(20, 50, 280, 120, COL_LIME, 0)

            meow.text(65, 75, "MOTION LOCK ACTIVE", COL_LIME)
            meow.text(45, 100, string.format("TRIP SENSITIVITY: %s", sens_levels[sens_idx].name), COL_WHITE)
            meow.text(55, 130, "STEALTH PERIMETER ENGAGED", COL_MUTED)

            draw_footer("[A] DISARM", "HOLD [B] EXIT")

        elseif mode == 4 then
            -- ALARM BREACH SCREEN
            local bg = ((siren_step % 2) == 0) and COL_BG or 0x4000
            meow.clear(bg)
            draw_header("!!! BREACH DETECTED !!!", "[ALARM]", COL_RED)

            meow.rect(15, 35, 290, 140, COL_PANEL, 1)
            meow.rect(15, 35, 290, 140, COL_RED, 0)

            meow.text(35, 50, "** TAMPER INTRUSION ALERT **", COL_RED)
            meow.text(25, 75, string.format("PEAK FORCE DELTA : +%.3f G", peak_delta), COL_WHITE)
            meow.text(25, 100, string.format("THRESHOLD SETTING: %.2f G", sens_levels[sens_idx].thresh), COL_WHITE)
            meow.text(25, 125, "LOG SAVED TO /tamper_log.txt", COL_CYAN)
            meow.text(25, 148, "SIREN STROBE RUNNING", COL_ORANGE)

            draw_footer("[A] SILENCE & RESET", "HOLD [B] EXIT")
        end
    end
end
