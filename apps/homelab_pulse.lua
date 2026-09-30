-- ==============================================================================
-- MEOWKit S3 Dynamic App: Homelab Pulse Node (Pocket Status Monitor)
-- Operator: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/homelab_pulse.lua)
-- ==============================================================================

local COL_BG     = 0x0841
local COL_PANEL  = 0x18C3
local COL_BORDER = 0x31A6
local COL_TEXT   = 0xFFFF
local COL_MUTED  = 0x7BEF
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_RED    = 0xF800

-- Monitored Homelab Target Nodes
local nodes = {
    { name = "GATEWAY.LAB", ip = "192.168.1.1",   port = "80",   status = "WAIT", lat = 0, up = false },
    { name = "CORE-SRV.LAB",ip = "192.168.1.10",  port = "80",   status = "WAIT", lat = 0, up = false },
    { name = "OPS-HOST.LAB",ip = "192.168.1.20",  port = "80",   status = "WAIT", lat = 0, up = false },
    { name = "STORAGE.LAB", ip = "192.168.1.50",  port = "5000", status = "WAIT", lat = 0, up = false }
}

local current_check_idx = 1
local last_check_time = 0
local check_interval = 2500 -- check next node every 2.5s
local last_beep_time = 0
local initial_scan_done = false

meow.clear(COL_BG)

function on_loop()
    -- Header Panel
    meow.rect(10, 8, 300, 32, COL_PANEL, true)
    meow.rect(10, 8, 300, 32, COL_CYAN, false)
    meow.text(18, 16, "HOMELAB PULSE // MONITOR", COL_CYAN)

    local wifi_st = meow.wifi_status()
    if wifi_st and wifi_st.connected then
        meow.text(210, 16, "[NET: ONLINE]", COL_LIME)
    else
        meow.text(205, 16, "[NET: DISCONN]", COL_RED)
    end

    -- Node Ping / Check Cycle
    local now = meow.millis()
    if now - last_check_time > check_interval then
        last_check_time = now
        local node = nodes[current_check_idx]
        local t0 = meow.millis()
        
        -- Instant exit check before network call
        if meow.btn("B") then return end

        -- Probe node via HTTP GET
        local url = string.format("http://%s:%s/", node.ip, node.port)
        local code, body = meow.http_get(url, 1200)
        local dt = meow.millis() - t0
        
        local was_up = node.up
        if code and code > 0 then
            node.up = true
            node.lat = dt
            node.status = string.format("ONLINE %dms", dt)
        else
            node.up = false
            node.status = "OFFLINE"
        end

        -- Trigger audio alert on drop
        if initial_scan_done and was_up and not node.up then
            meow.tone(880, 200)
        end

        current_check_idx = current_check_idx + 1
        if current_check_idx > #nodes then
            current_check_idx = 1
            initial_scan_done = true
        end
    end

    -- Update Hardware RGB LED Status
    local all_up = true
    local any_up = false
    for _, n in ipairs(nodes) do
        if n.up then any_up = true else all_up = false end
    end

    if all_up then
        meow.led(0, 40, 0) -- Solid Tactical Green
    elseif any_up then
        meow.led(50, 25, 0) -- Warning Amber
    else
        meow.led(60, 0, 0) -- Alert Red
    end

    -- Render Node Telemetry Cards
    for i, node in ipairs(nodes) do
        local y = 46 + (i - 1) * 38
        local col_card = node.up and COL_LIME or (node.status == "WAIT" and COL_MUTED or COL_RED)
        
        meow.rect(10, y, 300, 34, COL_PANEL, true)
        meow.rect(10, y, 300, 34, col_card, false)
        
        -- Indicator pip
        meow.circle(22, y + 17, 4, col_card, true)
        
        -- Node name & IP
        meow.text(35, y + 9, node.name, COL_TEXT)
        meow.text(145, y + 9, node.ip, COL_MUTED)
        
        -- Status
        meow.text(220, y + 9, node.status, col_card)
    end

    -- Footer / Instructions
    meow.rect(10, 202, 300, 30, COL_PANEL, true)
    meow.rect(10, 202, 300, 30, COL_BORDER, false)
    meow.text(18, 208, "[A] Force Recheck   |   Hold [B] Return", COL_MUTED)

    if meow.btn("A") and (now - last_beep_time > 400) then
        last_beep_time = now
        last_check_time = 0 -- force immediate poll
        meow.tone(1500, 50)
    end
end
