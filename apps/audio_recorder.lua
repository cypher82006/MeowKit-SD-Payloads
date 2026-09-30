-- ========================================================
--  MEOWKIT // ES7210 TACTICAL AUDIO RECORDER & WIRETAP
--  Hardware: ES7210 24-bit ADC + ZTS6216 MEMS Mic + SDMMC
--  Author: DarkCyfr Tactical Suite
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

local rec_durations = { 5, 10, 15, 30, 60 }
local dur_idx = 2 -- Default 10 seconds

local is_recording = false
local rec_counter = 1
local last_recorded_file = "None"
local last_recorded_bytes = 0

local inited = false
local last_vu_ms = 0
local b_held_start = 0

local function init_screen()
    meow.clear(COL_BG)
    meow.led(0, 0, 0)

    -- Header
    meow.rect(0, 0, 320, 24, COL_PANEL, true)
    meow.rect(0, 24, 320, 1, COL_CYAN, true)
    meow.text(8, 4, "ES7210 AUDIO RECORDER", COL_WHITE)
    meow.text(220, 4, "[READY]", COL_CYAN)

    -- Hardware Info Card
    meow.rect(10, 30, 300, 44, COL_PANEL, true)
    meow.rect(10, 30, 300, 44, COL_BORDER, false)
    meow.text(18, 34, "HARDWARE: ES7210 ADC (16kHz 16-Bit)", COL_CYAN)
    meow.text(18, 50, "MIC: ZTS6216 MEMS (+30dB Studio Pre-Amp)", COL_MUTED)

    -- Capture Settings Card
    meow.rect(10, 80, 300, 46, COL_PANEL, true)
    meow.rect(10, 80, 300, 46, COL_BORDER, false)
    meow.text(18, 84, "RECORD DURATION (JOYSTICK UP/DN):", COL_MUTED)
    meow.text(18, 100, string.format("-> [ %d SECONDS ]", rec_durations[dur_idx]), COL_LIME)

    -- Live VU Meter Bar
    meow.rect(10, 132, 300, 36, COL_PANEL, true)
    meow.rect(10, 132, 300, 36, COL_BORDER, false)
    meow.text(18, 136, "LIVE MIC VU:", COL_MUTED)
    meow.rect(110, 138, 185, 14, COL_BG, true)

    -- Last capture stats Card
    meow.rect(10, 174, 300, 38, COL_PANEL, true)
    meow.rect(10, 174, 300, 38, COL_BORDER, false)
    meow.text(18, 178, "TARGET: " .. last_recorded_file, COL_WHITE)
    meow.text(18, 192, "READY TO CAPTURE", COL_MUTED)

    -- Footer
    meow.rect(0, 218, 320, 22, COL_PANEL, true)
    meow.rect(0, 217, 320, 1, COL_BORDER, true)
    meow.text(8, 221, "[A] RECORD", COL_CYAN)
    meow.text(180, 221, "HOLD [B] EXIT", COL_ORANGE)

    inited = true
end

function on_loop()
    if not inited then
        init_screen()
    end

    local now = meow.millis()

    -- ── Check Buttons (Supporting both String and Number bindings) ──
    local btnA  = meow.btn("A")    or meow.btn(0)
    local btnB  = meow.btn("B")    or meow.btn(1)
    local btnUp = meow.btn("UP")   or meow.btn(2)
    local btnDn = meow.btn("DOWN") or meow.btn(3)

    -- Hold B to exit handled by host, but keep LED off on exit
    if btnB then
        if b_held_start == 0 then
            b_held_start = now
        elseif (now - b_held_start > 380) then
            meow.led(0, 0, 0)
            return
        end
    else
        b_held_start = 0
    end

    if not is_recording then
        -- ── 1. Record Action (Button A) ──
        if btnA then
            is_recording = true
            meow.tone(1800, 60)
            meow.led(255, 0, 0) -- RED LED on during active recording

            -- Status update: RECORDING
            meow.rect(215, 4, 100, 18, COL_PANEL, true)
            meow.text(215, 4, "[RECORDING]", COL_RED)

            local dur = rec_durations[dur_idx]
            local filepath = string.format("/recordings/rec_%03d.wav", rec_counter)
            rec_counter = rec_counter + 1

            meow.rect(18, 178, 280, 30, COL_PANEL, true)
            meow.text(18, 178, "WRITING: " .. filepath, COL_ORANGE)
            meow.text(18, 192, string.format("CAPTURING %d SECONDS...", dur), COL_RED)

            -- Perform actual I2S capture to SD card
            local ok, samples = meow.record_wav(filepath, dur)

            -- Fallback to root directory if /recordings fails
            if not ok then
                filepath = string.format("/rec_%03d.wav", rec_counter - 1)
                ok, samples = meow.record_wav(filepath, dur)
            end

            meow.led(0, 0, 0)

            meow.rect(215, 4, 100, 18, COL_PANEL, true)
            meow.text(220, 4, "[READY]", COL_CYAN)

            meow.rect(18, 178, 280, 30, COL_PANEL, true)
            if ok then
                last_recorded_file = filepath
                last_recorded_bytes = math.floor(samples * 2 + 44)
                meow.tone(2400, 100)
                meow.text(18, 178, "SAVED: " .. filepath, COL_LIME)
                meow.text(18, 192, string.format("SIZE: %.1f KB (%d samples)", last_recorded_bytes / 1024.0, samples), COL_WHITE)
            else
                last_recorded_file = "ERR: " .. tostring(samples)
                meow.tone(500, 250)
                meow.text(18, 178, "RECORDING FAILED", COL_RED)
                meow.text(18, 192, tostring(samples), COL_ORANGE)
            end

            is_recording = false
            meow.delay(300)
            return

        -- ── 2. Duration Selector (Up / Down) ──
        elseif btnUp then
            dur_idx = math.min(#rec_durations, dur_idx + 1)
            meow.tone(1600, 30)
            meow.rect(18, 100, 280, 18, COL_PANEL, true)
            meow.text(18, 100, string.format("-> [ %d SECONDS ]", rec_durations[dur_idx]), COL_LIME)
            meow.delay(180)

        elseif btnDn then
            dur_idx = math.max(1, dur_idx - 1)
            meow.tone(1400, 30)
            meow.rect(18, 100, 280, 18, COL_PANEL, true)
            meow.text(18, 100, string.format("-> [ %d SECONDS ]", rec_durations[dur_idx]), COL_LIME)
            meow.delay(180)
        end

        -- ── 3. Live VU Meter sampling (~15 FPS) ──
        if (now - last_vu_ms > 66) then
            last_vu_ms = now
            local lvl = meow.mic_level() -- Returns 0 to 100
            local bar_w = math.floor((lvl / 100.0) * 185)
            if bar_w > 185 then bar_w = 185 end

            meow.rect(110, 138, 185, 14, COL_BG, true)
            local bar_col = (lvl > 75) and COL_RED or ((lvl > 40) and COL_ORANGE or COL_LIME)
            if bar_w > 0 then
                meow.rect(110, 138, bar_w, 14, bar_col, true)
            end
        end
    end

    meow.delay(20)
end
