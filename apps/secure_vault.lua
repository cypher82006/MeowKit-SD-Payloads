-- ==============================================================================
-- MEOWKit S3 Dynamic App: Offline Credential Fragment Vault
-- Operator: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/secure_vault.lua)
-- Configuration: /config/vault.cfg (or /vault.cfg)
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

local UNLOCK_SEQ = { "UP", "UP", "DOWN", "DOWN" }
local entered_seq = {}
local is_unlocked = false
local attempts_left = 3
local lockout_until = 0
local last_input_time = 0
local scroll_offset = 1

local function load_vault_config()
    local entries = {}
    local content = (meow.read_file and meow.read_file("/config/vault.cfg")) or
                    (meow.read_file and meow.read_file("/vault.cfg")) or
                    (meow.read_file and meow.read_file("/config/vault.cfg.example"))
    
    if content then
        for line in content:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^[#;]") and not line:match("^%-%-") then
                local k, v = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                if k and v then
                    if k:upper() == "UNLOCK_SEQUENCE" then
                        UNLOCK_SEQ = {}
                        for key in v:gmatch("[^,]+") do
                            key = key:match("^%s*(.-)%s*$"):upper()
                            if key ~= "" then table.insert(UNLOCK_SEQ, key) end
                        end
                        if #UNLOCK_SEQ == 0 then UNLOCK_SEQ = {"UP", "UP", "DOWN", "DOWN"} end
                    else
                        table.insert(entries, {
                            tag = k,
                            secret = v
                        })
                    end
                end
            end
        end
    end

    if #entries == 0 then
        entries = {
            { tag = "LAB_HYPERVISOR", secret = "root // [RESTRICTED_KEY_HERE]" },
            { tag = "STORAGE_NAS",    secret = "admin // volume1_secure_vault" },
            { tag = "CORP_SERVER",    secret = "administrator // id_ed25519" },
            { tag = "GATEWAY_C2",     secret = "c2.operator-node.lab:443" },
            { tag = "TACTICAL_NET",   secret = "SSID: FieldOps // 10.0.0.1" }
        }
        if meow.write_file then
            local tpl = "# SECURE FRAGMENT VAULT CONFIGURATION\n" ..
                        "# Master PIN Sequence (comma-separated: UP, DOWN, LEFT, RIGHT)\n" ..
                        "UNLOCK_SEQUENCE=UP,UP,DOWN,DOWN\n\n" ..
                        "# Vault Fragment Entries: TAG=SECRET\n" ..
                        "LAB_HYPERVISOR=root // [RESTRICTED_KEY_HERE]\n" ..
                        "STORAGE_NAS=admin // volume1_secure_vault\n" ..
                        "CORP_SERVER=administrator // id_ed25519\n" ..
                        "GATEWAY_C2=c2.operator-node.lab:443\n" ..
                        "TACTICAL_NET=SSID: FieldOps // 10.0.0.1\n"
            meow.write_file("/config/vault.cfg", tpl)
        end
    end
    return entries
end

local vault_data = load_vault_config()

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
        meow.text(20, 58, "ENTER OPERATOR PIN:", COL_TEXT)

        -- PIN Slots display
        local slot_w = math.min(45, math.floor(240 / #UNLOCK_SEQ))
        local start_x = 160 - math.floor((#UNLOCK_SEQ * (slot_w + 10)) / 2)
        for i = 1, #UNLOCK_SEQ do
            local sx = start_x + (i - 1) * (slot_w + 10)
            local filled = (i <= #entered_seq)
            meow.rect(sx, 90, slot_w, 35, filled and COL_CYAN or 0x0841, true)
            meow.rect(sx, 90, slot_w, 35, COL_BORDER, false)
            if filled then
                meow.text(sx + math.floor(slot_w / 2) - 4, 98, "*", COL_TEXT)
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
        -- UNLOCKED VAULT BROWSER (SCROLLABLE)
        -- ══════════════════════════════════════════════════════
        -- Scroll navigation on D-Pad
        if #vault_data > 3 and (now - last_input_time > 200) then
            if meow.btn("UP") and scroll_offset > 1 then
                scroll_offset = scroll_offset - 1
                last_input_time = now
                meow.clear(COL_BG)
            elseif meow.btn("DOWN") and scroll_offset <= #vault_data - 3 then
                scroll_offset = scroll_offset + 1
                last_input_time = now
                meow.clear(COL_BG)
            end
        end

        meow.rect(10, 8, 300, 32, COL_PANEL, true)
        meow.rect(10, 8, 300, 32, COL_LIME, false)
        meow.text(18, 16, "SECURE VAULT // DECRYPTED", COL_LIME)
        meow.text(205, 16, string.format("[%d/%d FRAGS]", scroll_offset, #vault_data), COL_CYAN)

        meow.rect(10, 46, 300, 148, COL_PANEL, true)
        meow.rect(10, 46, 300, 148, COL_BORDER, false)

        local max_vis = math.min(3, #vault_data)
        for i = 1, max_vis do
            local idx = scroll_offset + i - 1
            local item = vault_data[idx]
            if item then
                local y = 52 + (i - 1) * 44
                meow.text(16, y, "[" .. item.tag .. "]:", COL_CYAN)
                meow.text(16, y + 14, item.secret, COL_TEXT)
            end
        end

        if #vault_data > 3 then
            meow.text(18, 204, "[A] Lock | ^v Scroll | Hold [B] Exit", COL_ORANGE)
        else
            meow.text(18, 204, "[A] Lock Vault   |   Hold [B] Panic Exit", COL_ORANGE)
        end

        if meow.btn("A") and (now - last_input_time > 300) then
            last_input_time = now
            -- Wipe memory & re-lock
            is_unlocked = false
            entered_seq = {}
            scroll_offset = 1
            meow.tone(880, 80)
            meow.led(40, 0, 0)
            meow.clear(COL_BG)
        end
    end
end
