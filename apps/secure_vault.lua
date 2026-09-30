-- ==============================================================================
-- MEOWKit S3 Dynamic App: Offline Credential Fragment Vault
-- Operator: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/secure_vault.lua)
-- ==============================================================================

local COL_BG     = 0x0841
local COL_PANEL  = 0x10A2
local COL_BORDER = 0x2965
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_RED    = 0xF800
local COL_TEXT   = 0xFFFF
local COL_MUTED  = 0x632C

-- Master Unlock Sequence (D-Pad): UP, UP, DOWN, DOWN
local UNLOCK_SEQ = { "UP", "UP", "DOWN", "DOWN" }
local entered_seq = {}
local is_unlocked = false
local attempts_left = 3
local lockout_until = 0
local last_input_time = 0

-- Vault entries loaded from SD or fallback
local vault_data = {
    { tag = "LAB_HYPERVISOR", secret = "root // [RESTRICTED_KEY_HERE]" },
    { tag = "STORAGE_NAS",    secret = "admin // volume1_secure_vault" },
    { tag = "CORP_SERVER",    secret = "administrator // id_ed25519" },
    { tag = "GATEWAY_C2",     secret = "c2.operator-node.lab:443" },
    { tag = "TACTICAL_NET",   secret = "SSID: FieldOps // 10.0.0.1" }
}

meow.clear(COL_BG)
meow.led(40, 0, 0) -- Locked Red LED

function on_loop()
    local now = meow.millis()

    -- Lockout countdown check
    if lockout_until > now then
        local sec = math.ceil((lockout_until - now) / 1000)
        meow.rect(10, 40, 300, 160, COL_PANEL, true)
        meow.rect(10, 40, 300, 160, COL_RED, false)
        meow.text(35, 75, "[ SECURITY LOCKOUT ]", COL_RED)
        meow.text(35, 110, string.format("COOLDOWN ACTIVE: %d SEC", sec), COL_TEXT)
        meow.text(35, 145, "HOLD [B] TO RETURN", COL_MUTED)
        meow.led(60, 0, 0)
        return
    end

    if not is_unlocked then
        -- ══════════════════════════════════════════════════════
        -- LOCK SCREEN (PIN ENTRY)
        -- ══════════════════════════════════════════════════════
        meow.rect(10, 8, 300, 32, COL_PANEL, true)
        meow.rect(10, 8, 300, 32, COL_RED, false)
        meow.text(18, 16, "SECURE VAULT // AIR-GAPPED", COL_RED)
        meow.text(230, 16, "[LOCKED]", COL_ORANGE)

        meow.rect(10, 46, 300, 145, COL_PANEL, true)
        meow.rect(10, 46, 300, 145, COL_BORDER, false)
        meow.text(20, 58, "ENTER D-PAD OPERATOR PIN:", COL_TEXT)

        -- PIN Slots display
        for i = 1, #UNLOCK_SEQ do
            local sx = 40 + (i - 1) * 60
            local filled = (i <= #entered_seq)
            meow.rect(sx, 90, 45, 35, filled and COL_CYAN or 0x0841, true)
            meow.rect(sx, 90, 45, 35, COL_BORDER, false)
            if filled then
                meow.text(sx + 16, 98, "*", COL_TEXT)
            end
        end

        meow.text(20, 145, string.format("ATTEMPTS REMAINING: %d", attempts_left), attempts_left > 1 and COL_LIME or COL_RED)
        meow.text(18, 202, "[D-PAD] Input   |   Hold [B] Return", COL_MUTED)

        -- Handle D-Pad input
        local pressed_key = nil
        if meow.btn("UP") then pressed_key = "UP"
        elseif meow.btn("DOWN") then pressed_key = "DOWN"
        elseif meow.btn("LEFT") then pressed_key = "LEFT"
        elseif meow.btn("RIGHT") then pressed_key = "RIGHT"
        end

        if pressed_key and (now - last_input_time > 250) then
            last_input_time = now
            table.insert(entered_seq, pressed_key)
            meow.tone(1400, 30)

            -- Check sequence upon full entry
            if #entered_seq == #UNLOCK_SEQ then
                local match = true
                for k, v in ipairs(UNLOCK_SEQ) do
                    if entered_seq[k] ~= v then match = false break end
                end

                if match then
                    is_unlocked = true
                    meow.tone(2400, 120)
                    meow.led(0, 50, 0) -- Green LED
                    meow.clear(COL_BG)
                else
                    attempts_left = attempts_left - 1
                    entered_seq = {}
                    meow.tone(440, 250)
                    meow.led(80, 0, 0)
                    if attempts_left <= 0 then
                        lockout_until = now + 15000 -- 15s lockout
                        attempts_left = 3
                    end
                end
            end
        end

    else
        -- ══════════════════════════════════════════════════════
        -- UNLOCKED VAULT BROWSER
        -- ══════════════════════════════════════════════════════
        meow.rect(10, 8, 300, 32, COL_PANEL, true)
        meow.rect(10, 8, 300, 32, COL_LIME, false)
        meow.text(18, 16, "SECURE VAULT // DECRYPTED", COL_LIME)
        meow.text(220, 16, "[ACCESS GRANTED]", COL_CYAN)

        meow.rect(10, 46, 300, 148, COL_PANEL, true)
        meow.rect(10, 46, 300, 148, COL_BORDER, false)

        for i, item in ipairs(vault_data) do
            local y = 52 + (i - 1) * 28
            meow.text(16, y, "[" .. item.tag .. "]:", COL_CYAN)
            meow.text(16, y + 13, item.secret, COL_TEXT)
        end

        meow.text(18, 204, "[A] Lock Vault   |   Hold [B] Panic Exit", COL_ORANGE)

        if meow.btn("A") and (now - last_input_time > 300) then
            last_input_time = now
            -- Wipe memory & re-lock
            is_unlocked = false
            entered_seq = {}
            meow.tone(880, 80)
            meow.led(40, 0, 0)
            meow.clear(COL_BG)
        end
    end
end
