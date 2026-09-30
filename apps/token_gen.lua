-- ══════════════════════════════════════════════════════════════
-- MEOWKit S3 // IT Admin Offline Cryptographic Token & Pass Gen
-- Author: DarkCyfr
-- Standalone entropy-driven secret generator (No internet required)
-- ══════════════════════════════════════════════════════════════

local COL_BG     = 0x10A2
local COL_PANEL  = 0x18E4
local COL_BORDER = 0x31A6
local COL_LIME   = 0xBEE7
local COL_CYAN   = 0x07FF
local COL_ORANGE = 0xFD20
local COL_WHITE  = 0xFFFF
local COL_MUTED  = 0x8410

local modes = {"COMPLEX_16", "ENTERPRISE_24", "HEX_KEY_32", "DICEWARE"}
local mode_idx = 1
local generated_token = ""
local b_hold_start = 0

-- Hardware noise entropy gathering
function seed_entropy()
    local ax, ay, az = meow.imu()
    local vbat = meow.bat()
    local t = meow.millis()
    local seed = math.floor((math.abs(ax) * 1000 + math.abs(ay) * 1000 + vbat * 100 + t) % 1000000)
    math.randomseed(seed)
end

local word_list = {
    "shadow", "operator", "quantum", "cipher", "matrix", "falcon", "sector", "delta",
    "cyber", "plasma", "stealth", "terminal", "packet", "firewall", "router", "kernel",
    "daemon", "socket", "beacon", "crypto", "switch", "gateway", "titan", "vector"
}

function generate_secret()
    seed_entropy()
    local mode = modes[mode_idx]

    if mode == "COMPLEX_16" then
        local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        local res = ""
        for i = 1, 16 do
            local idx = math.random(1, #chars)
            res = res .. chars:sub(idx, idx)
        end
        generated_token = res

    elseif mode == "ENTERPRISE_24" then
        local chars = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789-_#@"
        local res = ""
        for i = 1, 24 do
            local idx = math.random(1, #chars)
            res = res .. chars:sub(idx, idx)
        end
        generated_token = res

    elseif mode == "HEX_KEY_32" then
        local hex_chars = "0123456789abcdef"
        local res = ""
        for i = 1, 32 do
            local idx = math.random(1, #hex_chars)
            res = res .. hex_chars:sub(idx, idx)
        end
        generated_token = res

    elseif mode == "DICEWARE" then
        local w1 = word_list[math.random(1, #word_list)]
        local w2 = word_list[math.random(1, #word_list)]
        local w3 = word_list[math.random(1, #word_list)]
        local num = tostring(math.random(10, 99))
        generated_token = w1 .. "-" .. w2 .. "-" .. w3 .. "-" .. num
    end
end

function draw_screen()
    meow.clear(COL_BG)

    -- Header
    meow.rect(0, 0, 320, 24, COL_PANEL, true)
    meow.text(8, 4, "[ OFFLINE TOKEN & KEY GENERATOR ]", COL_LIME)

    -- Mode Selector
    meow.text(12, 34, "PROFILE / COMPLEXITY:", COL_MUTED)
    meow.rect(10, 52, 300, 32, COL_PANEL, true)
    meow.rect(10, 52, 300, 32, COL_BORDER, false)
    meow.text(20, 60, "<  " .. modes[mode_idx] .. "  >", COL_CYAN)

    -- Token Output Card
    meow.text(12, 94, "GENERATED SECRET KEY (AIR-GAPPED):", COL_MUTED)
    meow.rect(10, 112, 300, 60, COL_PANEL, true)
    meow.rect(10, 112, 300, 60, COL_LIME, false)

    -- Word wrap / split for long keys
    if #generated_token <= 20 then
        meow.text(20, 132, generated_token, COL_WHITE)
    else
        local part1 = generated_token:sub(1, 20)
        local part2 = generated_token:sub(21)
        meow.text(20, 122, part1, COL_WHITE)
        meow.text(20, 142, part2, COL_WHITE)
    end

    -- Entropy indicator
    local ax, ay, az = meow.imu()
    local ent_val = math.floor(math.abs(ax + ay + az) * 100)
    meow.text(12, 184, string.format("Hardware Entropy Noise: %d uG", ent_val), COL_MUTED)

    -- Footer
    meow.rect(0, 216, 320, 24, COL_PANEL, true)
    meow.text(8, 220, "[<>]Mode  [A]Regenerate  [Hold B]Exit", COL_WHITE)
end

generate_secret()
draw_screen()

function on_loop()
    -- Immediate Button [B] Hold-to-Exit check
    if meow.btn("B") then
        if b_hold_start == 0 then
            b_hold_start = meow.millis()
        elseif meow.millis() - b_hold_start > 400 then
            meow.tone(1200, 60)
            return false
        end
    else
        b_hold_start = 0
    end

    local changed = false

    -- Switch Modes
    if meow.btn("RIGHT") then
        mode_idx = (mode_idx % #modes) + 1
        generate_secret()
        changed = true
        meow.tone(1400, 20)
    elseif meow.btn("LEFT") then
        mode_idx = (mode_idx == 1) and #modes or mode_idx - 1
        generate_secret()
        changed = true
        meow.tone(1200, 20)
    end

    -- Regenerate Secret on [A]
    if meow.btn("A") then
        generate_secret()
        changed = true
        meow.tone(1800, 30)
    end

    if changed then
        draw_screen()
        meow.delay(180)
    end

    meow.delay(20)
    return true
end
