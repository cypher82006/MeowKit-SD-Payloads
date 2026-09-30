-- ══════════════════════════════════════════════════════════════
-- MEOWKit S3 // IT Admin Field Reference: Cable Pinouts & Ports
-- Author: DarkCyfr
-- Visual RJ-45 T568A / T568B Crimping Guide & Server Port Matrix
-- ══════════════════════════════════════════════════════════════

local COL_BG     = 0x10A2
local COL_PANEL  = 0x18E4
local COL_BORDER = 0x31A6
local COL_LIME   = 0xBEE7
local COL_CYAN   = 0x07FF
local COL_ORANGE = 0xFD20
local COL_WHITE  = 0xFFFF
local COL_MUTED  = 0x8410
local COL_GREEN  = 0x07E0
local COL_BLUE   = 0x001F
local COL_BROWN  = 0x9240

local current_tab = 1 -- 1 = T568B, 2 = T568A, 3 = Ports
local b_hold_start = 0

-- RJ45 Wire Colors (Name, Hex Color)
local t568b_wires = {
    {"1. W-ORG", COL_ORANGE}, {"2. ORG",   COL_ORANGE},
    {"3. W-GRN", COL_GREEN},  {"4. BLUE",  COL_CYAN},
    {"5. W-BLU", COL_CYAN},   {"6. GRN",   COL_GREEN},
    {"7. W-BRN", COL_BROWN},  {"8. BRN",   COL_BROWN}
}

local t568a_wires = {
    {"1. W-GRN", COL_GREEN},  {"2. GRN",   COL_GREEN},
    {"3. W-ORG", COL_ORANGE}, {"4. BLUE",  COL_CYAN},
    {"5. W-BLU", COL_CYAN},   {"6. ORG",   COL_ORANGE},
    {"7. W-BRN", COL_BROWN},  {"8. BRN",   COL_BROWN}
}

local server_ports = {
    {"DNS", "53 UDP/TCP", "Domain Name System"},
    {"DHCP", "67/68 UDP", "Bootstrap / IP Lease"},
    {"Kerberos", "88 TCP/UDP", "Active Directory Auth"},
    {"NTP", "123 UDP", "Network Time Sync"},
    {"SNMP", "161 UDP", "Hardware Telemetry"},
    {"LDAP/S", "389/636 TCP", "Directory Services"},
    {"SMB", "445 TCP", "Windows File Sharing"},
    {"RDP", "3389 TCP", "Remote Desktop Protocol"}
}

function draw_screen()
    meow.clear(COL_BG)

    -- Header
    meow.rect(0, 0, 320, 24, COL_PANEL, true)
    local titles = {
        "[ RJ-45 CABLE PINOUT: T568B ]",
        "[ RJ-45 CABLE PINOUT: T568A ]",
        "[ INFRASTRUCTURE PORT MATRIX ]"
    }
    meow.text(8, 4, titles[current_tab], COL_LIME)

    if current_tab == 1 or current_tab == 2 then
        local wires = (current_tab == 1) and t568b_wires or t568a_wires
        meow.text(10, 30, "STANDARD STRAIGHT-THROUGH CRIMP (PIN 1-8):", COL_MUTED)

        -- Draw 8 Wire Bars
        local y = 48
        for i = 1, 8 do
            local wire = wires[i]
            meow.rect(10, y, 300, 18, COL_PANEL, true)
            meow.rect(10, y, 300, 18, COL_BORDER, false)

            -- Color Swatch Strip
            meow.rect(14, y + 3, 24, 12, wire[2], true)
            meow.text(48, y + 1, wire[1], COL_WHITE)

            local role = (i == 1 or i == 2) and "TX+/TX-" or ((i == 3 or i == 6) and "RX+/RX-" or "PoE / Spare")
            meow.text(210, y + 1, role, COL_CYAN)

            y = y + 20
        end
    else
        -- Server Port Matrix Tab
        meow.text(10, 30, "ENTERPRISE & HOMELAB DEFAULT PORTS:", COL_MUTED)
        local y = 48
        for i = 1, 8 do
            local p = server_ports[i]
            meow.rect(10, y, 300, 18, COL_PANEL, true)
            meow.rect(10, y, 300, 18, COL_BORDER, false)

            meow.text(16, y + 1, p[1], COL_ORANGE)
            meow.text(90, y + 1, p[2], COL_LIME)
            meow.text(175, y + 1, p[3], COL_WHITE)

            y = y + 20
        end
    end

    -- Footer
    meow.rect(0, 216, 320, 24, COL_PANEL, true)
    meow.text(8, 220, "[<>]Switch Tab  [A]Next  [Hold B]Exit", COL_WHITE)
end

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

    -- Tab Switching
    local changed = false
    if meow.btn("RIGHT") or meow.btn("A") then
        current_tab = (current_tab % 3) + 1
        changed = true
        meow.tone(1400, 20)
    elseif meow.btn("LEFT") then
        current_tab = (current_tab == 1) and 3 or current_tab - 1
        changed = true
        meow.tone(1200, 20)
    end

    if changed then
        draw_screen()
        meow.delay(200)
    end

    meow.delay(20)
    return true
end
