-- ========================================================
--  MEOWKIT // ES7210 TACTICAL AUDIO RECORDER & WIRETAP
--  Hardware: ES7210 24-bit ADC + ZTS6216 MEMS Mic + SDMMC
--  Author: DarkCyfr Tactical Suite
--  Configuration: /config/recorder.cfg (or /recorder.cfg)
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

-- ── Configuration Loader ──
local function load_recorder_config()
    local cfg = {
        default_dur = 10,
        out_dir = "/recordings",
        prefix = "wiretap"
    }

    local content = (meow.read_file and meow.read_file("/config/recorder.cfg")) or
                    (meow.read_file and meow.read_file("/recorder.cfg")) or
                    (meow.read_file and meow.read_file("/config/recorder.cfg.example"))

    if content then
        for line in content:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^[#;]") and not line:match("^%-%-") then
                local k, v = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                if k and v then
                    k = k:upper()
                    if k == "DEFAULT_DURATION_SEC" or k == "DURATION" then
                        cfg.default_dur = tonumber(v) or 10
                    elseif k == "OUTPUT_DIR" then
                        cfg.out_dir = v
                    elseif k == "FILE_PREFIX" or k == "PREFIX" then
                        cfg.prefix = v
                    end
                end
            end
        end
    else
        if meow.write_file then
            local tpl = "# ES7210 TACTICAL AUDIO RECORDER CONFIGURATION\n" ..
                        "# Default recording duration in seconds\n" ..
                        "DEFAULT_DURATION_SEC=10\n" ..
                        "# Output directory on MicroSD card\n" ..
                        "OUTPUT_DIR=/recordings\n" ..
                        "# Filename prefix\n" ..
                        "FILE_PREFIX=wiretap\n"
            meow.write_file("/config/recorder.cfg", tpl)
        end
    end
    return cfg
end

local config = load_recorder_config()

local rec_durations = { 5, 10, 15, 30, 60 }
local dur_idx = 2
for i, d in ipairs(rec_durations) do
    if d == config.default_dur then dur_idx = i break end
end

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

    local btnA  = meow.btn("A")    or meow.btn(0)
    local btnB  = meow.btn("B")    or meow.btn(1)
    local btnUp = meow.btn("UP")   or meow.btn(2)
    local btnDn = meow.btn("DOWN") or meow.btn(3)

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
            meow.led(255, 0, 0)

            meow.rect(215, 4, 100, 18, COL_PANEL, true)
            meow.text(215, 4, "[RECORDING]", COL_RED)

            local dur = rec_durations[dur_idx]
            local filepath = string.format("%s/%s_%03d.wav", config.out_dir, config.prefix, rec_counter)
            rec_counter = rec_counter + 1

            meow.rect(18, 178, 280, 30, COL_PANEL, true)
            meow.text(18, 178, "WRITING: " .. filepath, COL_ORANGE)
            meow.text(18, 192, string.format("CAPTURING %d SECONDS...", dur), COL_RED)

            local ok, samples = meow.record_wav(filepath, dur)

            -- Fallback to root directory if subdirectory fails
            if not ok then
                filepath = string.format("/%s_%03d.wav", config.prefix, rec_counter - 1)
                ok, samples = meow.record_wav(filepath, dur)
            end

            meow.led(0, 0, 0)
            is_recording = false

            meow.rect(215, 4, 100, 18, COL_PANEL, true)
            meow.text(220, 4, "[READY]", COL_CYAN)

            meow.rect(18, 178, 280, 30, COL_PANEL, true)
            if ok then
                last_recorded_file = filepath
                last_recorded_bytes = dur * 16000 * 2
                meow.tone(2400, 100)
                meow.text(18, 178, "SAVED: " .. filepath, COL_LIME)
                meow.text(18, 192, string.format("OK: %d KB | 16kHz WAV", math.floor(last_recorded_bytes / 1024)), COL_WHITE)
            else
                meow.tone(440, 200)
                meow.text(18, 178, "RECORDING FAILED", COL_RED)
                meow.text(18, 192, "ERR: SD OR I2S BUS BUSY", COL_ORANGE)
            end
            meow.delay(200)
        end

        -- ── 2. Adjust Duration (Joystick UP / DOWN) ──
        if btnUp then
            dur_idx = dur_idx + 1
            if dur_idx > #rec_durations then dur_idx = 1 end
            meow.tone(1400, 30)
            meow.rect(18, 100, 250, 18, COL_PANEL, true)
            meow.text(18, 100, string.format("-> [ %d SECONDS ]", rec_durations[dur_idx]), COL_LIME)
            meow.delay(180)
        elseif btnDn then
            dur_idx = dur_idx - 1
            if dur_idx < 1 then dur_idx = #rec_durations end
            meow.tone(1100, 30)
            meow.rect(18, 100, 250, 18, COL_PANEL, true)
            meow.text(18, 100, string.format("-> [ %d SECONDS ]", rec_durations[dur_idx]), COL_LIME)
            meow.delay(180)
        end

        -- ── 3. Live VU Meter Refresh (15 Hz) ──
        if now - last_vu_ms > 65 then
            last_vu_ms = now
            local lvl = meow.mic_level() or 0
            if lvl < 0 then lvl = 0 end
            if lvl > 100 then lvl = 100 end

            local bar_w = math.floor((lvl / 100.0) * 180)
            meow.rect(112, 140, 180, 10, COL_BG, true)
            if bar_w > 0 then
                local col = (lvl > 75) and COL_RED or ((lvl > 45) and COL_ORANGE or COL_LIME)
                meow.rect(112, 140, bar_w, 10, col, true)
            end
        end
    end

    meow.delay(20)
end
