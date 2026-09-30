-- ══════════════════════════════════════════════════════════════
-- MEOWKit S3 // Tactical CIDR & Subnet Calculator (Lua 5.4 Edition)
-- Author: DarkCyfr
-- Features: IP/CIDR Subnet Math, Network Range, Usable Hosts,
--           Interactive D-Pad & Button Preset Cycling
-- Configuration: /config/subnets.cfg (or /subnets.cfg)
-- ══════════════════════════════════════════════════════════════

local COL_BG     = 0x10A2
local COL_PANEL  = 0x18E4
local COL_BORDER = 0x31A6
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_WHITE  = 0xFFFF
local COL_MUTED  = 0x8410

-- Load presets dynamically from /config/subnets.cfg
local function load_subnet_presets()
    local presets = {}
    local content = (meow.read_file and meow.read_file("/config/subnets.cfg")) or
                    (meow.read_file and meow.read_file("/subnets.cfg")) or
                    (meow.read_file and meow.read_file("/config/subnets.cfg.example"))

    if content then
        for line in content:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^[#;]") and not line:match("^%-%-") then
                local name, ip_str, pfx_str = line:match("^([^,]+),%s*([^,]+),%s*(%d+)")
                if name and ip_str and pfx_str then
                    local o1, o2, o3, o4 = ip_str:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
                    if o1 and o2 and o3 and o4 then
                        table.insert(presets, {
                            name = name:match("^%s*(.-)%s*$"),
                            ip = { tonumber(o1), tonumber(o2), tonumber(o3), tonumber(o4) },
                            pfx = tonumber(pfx_str)
                        })
                    end
                end
            end
        end
    end

    if #presets == 0 then
        presets = {
            { name = "Standard LAN",   ip = {192, 168, 1, 1},  pfx = 24 },
            { name = "Security VLAN",  ip = {192, 168, 10, 1}, pfx = 24 },
            { name = "VPN Overlay",    ip = {10, 8, 0, 1},     pfx = 24 },
            { name = "Class B Lab",    ip = {172, 16, 0, 1},   pfx = 16 },
            { name = "Enterprise WAN", ip = {10, 0, 0, 1},     pfx = 8  }
        }
        if meow.write_file then
            local tpl = "# TACTICAL SUBNET CALCULATOR PRESETS\n" ..
                        "# Format: NAME,IP,CIDR\n" ..
                        "Standard LAN,192.168.1.1,24\n" ..
                        "Security VLAN,192.168.10.1,24\n" ..
                        "VPN Overlay,10.8.0.1,24\n" ..
                        "Class B Lab,172.16.0.1,16\n" ..
                        "Enterprise WAN,10.0.0.1,8\n"
            meow.write_file("/config/subnets.cfg", tpl)
        end
    end
    return presets
end

local PRESETS = load_subnet_presets()
local preset_idx = 1
local octets = { PRESETS[1].ip[1], PRESETS[1].ip[2], PRESETS[1].ip[3], PRESETS[1].ip[4] }
local prefix = PRESETS[1].pfx
local cur_octet = 3
local b_hold_start = 0

-- Bitwise 32-bit math helpers in Lua 5.4
local function ip_to_u32(o)
    return ((o[1] & 0xFF) << 24) | ((o[2] & 0xFF) << 16) | ((o[3] & 0xFF) << 8) | (o[4] & 0xFF)
end

local function u32_to_ip(u)
    local o1 = (u >> 24) & 0xFF
    local o2 = (u >> 16) & 0xFF
    local o3 = (u >> 8)  & 0xFF
    local o4 = u & 0xFF
    return string.format("%d.%d.%d.%d", o1, o2, o3, o4)
end

local function draw_calc()
    meow.clear(COL_BG)

    -- Header
    meow.rect(0, 0, 320, 24, COL_PANEL, true)
    meow.text(8, 4, "[ TACTICAL CIDR / SUBNET CALC ]", COL_LIME)
    local cur_name = PRESETS[preset_idx] and PRESETS[preset_idx].name or "CUSTOM"
    meow.text(210, 4, cur_name, COL_CYAN)

    local ip_val = ip_to_u32(octets)
    local mask_val = (prefix == 0) and 0 or ((~0 << (32 - prefix)) & 0xFFFFFFFF)
    local wild_val = (~mask_val) & 0xFFFFFFFF
    local net_val  = ip_val & mask_val
    local bcast_val = ip_val | wild_val
    local first_host = (prefix >= 31) and net_val or (net_val + 1)
    local last_host  = (prefix >= 31) and bcast_val or (bcast_val - 1)
    local host_count = (prefix >= 31) and 2 or ((1 << (32 - prefix)) - 2)

    -- IP / CIDR Input Card
    meow.rect(8, 30, 304, 38, COL_PANEL, true)
    meow.rect(8, 30, 304, 38, COL_BORDER, false)
    meow.text(16, 38, "IP/CIDR:", COL_MUTED)

    -- Display IP with highlighted active octet
    local ip_str = string.format("%d.%d.%d.%d", octets[1], octets[2], octets[3], octets[4])
    meow.text(85, 38, ip_str, COL_WHITE)
    meow.text(215, 38, string.format("/%d", prefix), COL_ORANGE)
    meow.text(250, 38, string.format("[O%d]", cur_octet), COL_CYAN)

    -- Subnet Calculations Table
    local rows = {
        { lbl = "Netmask:",   val = u32_to_ip(mask_val),  col = COL_CYAN },
        { lbl = "Wildcard:",  val = u32_to_ip(wild_val),  col = COL_MUTED },
        { lbl = "Network ID:",val = u32_to_ip(net_val),   col = COL_LIME },
        { lbl = "Broadcast:", val = u32_to_ip(bcast_val), col = COL_ORANGE },
        { lbl = "First Host:",val = u32_to_ip(first_host),col = COL_WHITE },
        { lbl = "Last Host:", val = u32_to_ip(last_host), col = COL_WHITE },
        { lbl = "Usable IPs:",val = string.format("%d hosts", host_count), col = COL_LIME }
    }

    local y = 72
    local row_h = 20
    for _, r in ipairs(rows) do
        meow.rect(8, y, 304, row_h - 2, COL_PANEL, true)
        meow.text(16, y + 2, r.lbl, COL_MUTED)
        meow.text(110, y + 2, r.val, r.col)
        y = y + row_h
    end

    -- Footer
    meow.rect(0, 216, 320, 24, COL_PANEL, true)
    meow.text(8, 220, "[^v]Pfx [<>]Octet [A]Preset Hold[B]Exit", COL_WHITE)
end

draw_calc()

function on_loop()
    -- Quick check on Button B
    if meow.btn("B") or meow.btn(1) then
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

    -- Joystick UP: Increase Prefix length (/24 -> /25)
    if meow.btn("UP") or meow.btn(2) then
        if prefix < 30 then
            prefix = prefix + 1
            changed = true
            meow.tone(1600, 20)
        end
    -- Joystick DOWN: Decrease Prefix length (/24 -> /23)
    elseif meow.btn("DOWN") or meow.btn(3) then
        if prefix > 8 then
            prefix = prefix - 1
            changed = true
            meow.tone(1300, 20)
        end
    -- Joystick RIGHT: Increment octet value
    elseif meow.btn("RIGHT") or meow.btn(5) then
        octets[cur_octet] = (octets[cur_octet] + 1) % 256
        changed = true
        meow.tone(1100, 15)
    -- Joystick LEFT: Decrement octet value
    elseif meow.btn("LEFT") or meow.btn(4) then
        octets[cur_octet] = (octets[cur_octet] - 1) % 256
        if octets[cur_octet] < 0 then octets[cur_octet] = 255 end
        changed = true
        meow.tone(1100, 15)
    -- Button A: Cycle Network Presets
    elseif meow.btn("A") or meow.btn(0) then
        preset_idx = (preset_idx % #PRESETS) + 1
        local p = PRESETS[preset_idx]
        for i = 1, 4 do octets[i] = p.ip[i] end
        prefix = p.pfx
        changed = true
        meow.tone(2000, 40)
    end

    if changed then
        draw_calc()
        meow.delay(160)
    end

    meow.delay(20)
    return true
end
