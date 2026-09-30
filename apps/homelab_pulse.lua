-- ==============================================================================
-- MEOWKit S3 Dynamic App: Homelab Pulse Node (Pocket Status Monitor)
-- Operator: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/homelab_pulse.lua)
-- Configuration: /config/homelab.cfg (or /homelab.cfg)
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

-- Wi-Fi credential loader from SD card
local function check_wifi_connect()
    local st = meow.wifi_status()
    if st and st.connected then return end
    local content = (meow.read_file and meow.read_file("/config/wifi.cfg")) or
                    (meow.read_file and meow.read_file("/wifi.cfg"))
    if content then
        local ssid = content:match("SSID=([^\r\n]+)")
        local pass = content:match("PASSWORD=([^\r\n]+)")
        if ssid and pass and ssid ~= "YOUR_SSID" then
            meow.text(18, 16, "CONNECTING TO WIFI...", COL_ORANGE)
            meow.wifi_connect(ssid, pass)
            meow.delay(1000)
        end
    end
end

-- Load monitored nodes dynamically from /config/homelab.cfg
local function load_nodes()
    local targets = {}
    local content = (meow.read_file and meow.read_file("/config/homelab.cfg")) or
                    (meow.read_file and meow.read_file("/homelab.cfg")) or
                    (meow.read_file and meow.read_file("/config/homelab.cfg.example"))
    
    if content then
        for line in content:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^[#;]") and not line:match("^%-%-") then
                local name, ip, port = line:match("^([^,]+),%s*([^,]+),%s*(%d+)")
                if name and ip and port then
                    table.insert(targets, {
                        name = name:match("^%s*(.-)%s*$"),
                        ip = ip:match("^%s*(.-)%s*$"),
                        port = port:match("^%s*(.-)%s*$"),
                        status = "WAIT",
                        lat = 0,
                        up = false
                    })
                end
            end
        end
    end

    -- If no targets loaded, generate documented template and default fallback
    if #targets == 0 then
        targets = {
            { name = "GATEWAY.LAB", ip = "192.168.1.1",   port = "80",   status = "WAIT", lat = 0, up = false },
            { name = "CORE-SRV.LAB",ip = "192.168.1.10",  port = "80",   status = "WAIT", lat = 0, up = false },
            { name = "OPS-HOST.LAB",ip = "192.168.1.20",  port = "80",   status = "WAIT", lat = 0, up = false },
            { name = "STORAGE.LAB", ip = "192.168.1.50",  port = "5000", status = "WAIT", lat = 0, up = false }
        }
        if meow.write_file then
            local tpl = "# HOMELAB PULSE MONITOR TARGETS\n" ..
                        "# Format: NAME,IP,PORT\n" ..
                        "GATEWAY.LAB,192.168.1.1,80\n" ..
                        "CORE-SRV.LAB,192.168.1.10,80\n" ..
                        "OPS-HOST.LAB,192.168.1.20,80\n" ..
                        "STORAGE.LAB,192.168.1.50,5000\n"
            meow.write_file("/config/homelab.cfg", tpl)
        end
    end
    return targets
end

local nodes = load_nodes()
local scroll_offset = 1
local current_check_idx = 1
local last_check_time = 0
local check_interval = 2000
local last_beep_time = 0
local last_scroll_time = 0
local initial_scan_done = false

meow.clear(COL_BG)
check_wifi_connect()

function on_loop()
    local now = meow.millis()

    -- D-Pad Scroll navigation for large lists (> 4 nodes)
    if #nodes > 4 and (now - last_scroll_time > 200) then
        if meow.btn("UP") then
            if scroll_offset > 1 then
                scroll_offset = scroll_offset - 1
                last_scroll_time = now
            end
        elseif meow.btn("DOWN") then
            if scroll_offset <= #nodes - 4 then
                scroll_offset = scroll_offset + 1
                last_scroll_time = now
            end
        end
    end

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

        -- Audio alert on node drop
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

    -- Render 4 Visible Node Telemetry Cards
    local max_visible = math.min(4, #nodes)
    for i = 1, max_visible do
        local node_idx = scroll_offset + i - 1
        local node = nodes[node_idx]
        if node then
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
    end

    -- Footer / Instructions
    meow.rect(10, 202, 300, 30, COL_PANEL, true)
    meow.rect(10, 202, 300, 30, COL_BORDER, false)
    if #nodes > 4 then
        meow.text(18, 208, string.format("[A] Recheck | ^v Scroll (%d/%d) | [B] Exit", scroll_offset, #nodes), COL_MUTED)
    else
        meow.text(18, 208, "[A] Force Recheck   |   Hold [B] Return", COL_MUTED)
    end

    if meow.btn("A") and (now - last_beep_time > 400) then
        last_beep_time = now
        last_check_time = 0
        meow.tone(1500, 50)
    end
end
