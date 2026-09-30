-- ==============================================================================
-- MEOWKit S3 Dynamic App: Covert P2P Walkie Terminal
-- Operator: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/walkie_terminal.lua)
-- Configuration: /config/walkie.cfg and /config/wifi.cfg
-- ==============================================================================

local COL_BG     = 0x0000
local COL_PANEL  = 0x10A2
local COL_BORDER = 0x2124
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_TEXT   = 0xFFFF
local COL_MUTED  = 0x632C

-- ── Configuration Loader ──
local function load_walkie_config()
    local cfg = {
        callsign = "OPERATOR",
        port = 8765,
        broadcast_ip = "255.255.255.255",
        beacon_interval = 10000,
        quick_msgs = { "[ACK]", "[STANDBY]", "[DEPLOYED]", "[STATUS_OK]", "[ALERT_LAB]", "[BEACON_PING]" }
    }

    local content = (meow.read_file and meow.read_file("/config/walkie.cfg")) or
                    (meow.read_file and meow.read_file("/walkie.cfg")) or
                    (meow.read_file and meow.read_file("/config/walkie.cfg.example"))

    if content then
        for line in content:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" and not line:match("^[#;]") and not line:match("^%-%-") then
                local k, v = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                if k and v then
                    k = k:upper()
                    if k == "CALLSIGN" then
                        cfg.callsign = v
                    elseif k == "PORT" or k == "UDP_PORT" then
                        cfg.port = tonumber(v) or 8765
                    elseif k == "BROADCAST_IP" or k == "BROADCAST" then
                        cfg.broadcast_ip = v
                    elseif k == "BEACON_INTERVAL_MS" or k == "BEACON_INTERVAL" then
                        cfg.beacon_interval = tonumber(v) or 10000
                    elseif k == "QUICK_MESSAGES" or k == "MESSAGES" then
                        cfg.quick_msgs = {}
                        for m in v:gmatch("[^,]+") do
                            m = m:match("^%s*(.-)%s*$")
                            if m ~= "" then table.insert(cfg.quick_msgs, m) end
                        end
                        if #cfg.quick_msgs == 0 then
                            cfg.quick_msgs = { "[ACK]", "[STANDBY]", "[STATUS_OK]" }
                        end
                    end
                end
            end
        end
    else
        if meow.write_file then
            local tpl = "# COVERT P2P WALKIE TERMINAL CONFIGURATION\n" ..
                        "# Callsign used in heartbeat beacons\n" ..
                        "CALLSIGN=OPERATOR\n" ..
                        "# UDP Listening and Transmit Port\n" ..
                        "UDP_PORT=8765\n" ..
                        "# Broadcast Target IP Address\n" ..
                        "BROADCAST_IP=255.255.255.255\n" ..
                        "# Heartbeat interval in milliseconds (0 to disable)\n" ..
                        "BEACON_INTERVAL_MS=10000\n" ..
                        "# Comma-separated list of quick-reply messages\n" ..
                        "QUICK_MESSAGES=[ACK],[STANDBY],[DEPLOYED],[STATUS_OK],[ALERT_LAB],[BEACON_PING]\n"
            meow.write_file("/config/walkie.cfg", tpl)
        end
    end
    return cfg
end

-- ── Auto-Connect Wi-Fi ──
local function ensure_wifi()
    local stat = meow.wifi_status()
    if stat and stat.connected then return end
    local content = (meow.read_file and meow.read_file("/config/wifi.cfg")) or
                    (meow.read_file and meow.read_file("/wifi.cfg"))
    if content then
        local ssid = content:match("SSID=([^\r\n]+)")
        local pass = content:match("PASSWORD=([^\r\n]+)")
        if ssid and pass and ssid ~= "YOUR_SSID" then
            meow.wifi_connect(ssid, pass)
            meow.delay(1000)
        end
    end
end

ensure_wifi()
local config = load_walkie_config()

local messages = {
    ">> WALKIE TERMINAL INITIALIZED",
    ">> LISTENING ON UDP PORT " .. config.port
}
local selected_msg_idx = 1
local last_beacon = 0
local last_btn_time = 0

meow.clear(COL_BG)
meow.udp_bind(config.port)
meow.led(0, 20, 40) -- Stealth Cyan LED

local function add_log(msg)
    table.insert(messages, msg)
    if #messages > 7 then
        table.remove(messages, 1)
    end
end

function on_loop()
    local now = meow.millis()

    -- 1. Heartbeat Beacon
    if config.beacon_interval > 0 and (now - last_beacon > config.beacon_interval) then
        last_beacon = now
        meow.udp_send(config.broadcast_ip, config.port, "BEACON//" .. config.callsign .. "_MEOW_S3")
    end

    -- 2. Non-blocking Receive UDP Packets
    local data, remote_ip, remote_port = meow.udp_recv()
    if data then
        add_log(string.format("[%s]: %s", remote_ip, data))
        meow.tone(2000, 60)
        meow.led(0, 80, 80) -- Flash Cyan
        local cur_log = (meow.read_file and meow.read_file("/logs/walkie_comms.log")) or ""
        if meow.write_file then
            meow.write_file("/logs/walkie_comms.log", cur_log .. string.format("[%d] %s: %s\n", now, remote_ip, data))
        end
    end

    -- 3. Header Panel
    meow.rect(8, 6, 304, 28, COL_PANEL, true)
    meow.rect(8, 6, 304, 28, COL_CYAN, false)
    meow.text(14, 12, "WALKIE P2P // " .. config.callsign, COL_CYAN)
    meow.text(210, 12, string.format("PORT: %d", config.port), COL_LIME)

    -- 4. Message History Window
    meow.rect(8, 38, 304, 128, COL_PANEL, true)
    meow.rect(8, 38, 304, 128, COL_BORDER, false)
    for i, m in ipairs(messages) do
        local my = 42 + (i - 1) * 17
        meow.text(12, my, m, (i == #messages) and COL_LIME or COL_TEXT)
    end

    -- 5. Quick Transmit Selector
    meow.rect(8, 170, 304, 38, COL_PANEL, true)
    meow.rect(8, 170, 304, 38, COL_ORANGE, false)
    meow.text(14, 174, "TX SELECT:", COL_ORANGE)
    local cur_tx = config.quick_msgs[selected_msg_idx] or "[PING]"
    meow.text(105, 174, cur_tx, COL_LIME)
    meow.text(14, 192, "[A] Transmit   |   [UP/DN] Change Msg", COL_MUTED)

    -- 6. Navigation / Inputs
    if meow.btn("UP") and (now - last_btn_time > 200) then
        selected_msg_idx = selected_msg_idx - 1
        if selected_msg_idx < 1 then selected_msg_idx = #config.quick_msgs end
        last_btn_time = now
        meow.tone(1200, 20)
    elseif meow.btn("DOWN") and (now - last_btn_time > 200) then
        selected_msg_idx = selected_msg_idx + 1
        if selected_msg_idx > #config.quick_msgs then selected_msg_idx = 1 end
        last_btn_time = now
        meow.tone(1200, 20)
    elseif meow.btn("A") and (now - last_btn_time > 300) then
        last_btn_time = now
        local payload = config.quick_msgs[selected_msg_idx] or "[PING]"
        meow.udp_send(config.broadcast_ip, config.port, payload)
        add_log("[TX BROADCAST]: " .. payload)
        meow.tone(2500, 80)
        meow.led(80, 40, 0)
    end

    -- Footer
    meow.text(14, 218, "HOLD [B] TO RETURN TO SD APPS", COL_MUTED)
end
