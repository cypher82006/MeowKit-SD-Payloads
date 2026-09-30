-- ==============================================================================
-- MEOWKit S3 Dynamic App: Pocket Synth
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/pocket_synth.lua)
-- ==============================================================================

local COL_BG     = 0x0841
local COL_PANEL  = 0x18C3
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_TEXT   = 0xFFFF
local COL_MUTED  = 0x7BEF

local scale = { 261, 293, 329, 349, 392, 440, 493, 523 }
local scale_names = { "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5" }
local note_idx = 1
local last_trigger = 0

meow.clear(COL_BG)

function on_loop()
    -- Panel
    meow.rect(15, 15, 290, 210, COL_PANEL, true)
    meow.rect(15, 15, 290, 210, COL_CYAN, false)

    meow.text(30, 30, "MEOW-S3 POCKET SYNTH", COL_CYAN)
    meow.text(30, 50, "PRESS [A] TO PLAY NOTE", COL_TEXT)
    meow.text(30, 70, "DPAD UP/DOWN TO CHANGE PITCH", COL_MUTED)

    if meow.btn("UP") and (meow.millis() - last_trigger > 200) then
        note_idx = math.min(#scale, note_idx + 1)
        last_trigger = meow.millis()
    elseif meow.btn("DOWN") and (meow.millis() - last_trigger > 200) then
        note_idx = math.max(1, note_idx - 1)
        last_trigger = meow.millis()
    end

    local freq = scale[note_idx]
    local name = scale_names[note_idx]

    -- Display Note
    meow.text(30, 110, string.format("NOTE: %s (%d Hz)", name, freq), COL_LIME)

    -- Piano key visuals
    for i = 1, #scale do
        local kx = 30 + (i - 1) * 32
        local is_sel = (i == note_idx)
        meow.rect(kx, 140, 28, 45, is_sel and COL_LIME or 0xFFFF, true)
        meow.rect(kx, 140, 28, 45, 0x0000, false)
    end

    if meow.btn("A") then
        meow.tone(freq, 60)
        meow.text(30, 195, ">> PLAYING AUDIO <<", COL_ORANGE)
    else
        meow.text(30, 195, "HOLD [B] TO RETURN ", COL_MUTED)
    end
end
