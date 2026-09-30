-- ==============================================================================
-- MEOWKit S3 Dynamic App: Covert P2P Walkie Terminal
-- Operator: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/walkie_terminal.lua)
-- ==============================================================================

local COL_BG     = 0x0000
local COL_PANEL  = 0x10A2
local COL_BORDER = 0x2124
local COL_CYAN   = 0x07FF
local COL_LIME   = 0xBEE7
local COL_ORANGE = 0xFD20
local COL_TEXT   = 0xFFFF
local COL_MUTED  = 0x632C

local UDP_PORT = 8765
local messages = {
    ">> WALKIE TERMINAL INITIALIZED",
    ">> LISTENING ON UDP PORT " .. UDP_PORT
}

local quick_messages = {
    "[ACK]",
    "[STANDBY]",
    "[DEPLOYED]",
    "[STATUS_OK]",
    "[ALERT_LAB]",
    "[BEACON_PING]"
}

local selected_msg_idx = 1
local last_beacon = 0
local last_btn_time = 0

meow.clear(COL_BG)
meow.udp_bind(UDP_PORT)
meow.led(0, 20, 40) -- Stealth Cyan LED

function add_log(msg)
    table.insert(messages, msg)
    if #messages > 7 then
        table.remove(messages, 1)
    end
end

function on_loop()
    local now = meow.millis()

    -- 1. Heartbeat Beacon every 10s
    if now - last_beacon > 10000 then
        last_beacon = now
        meow.udp_send("255.255.255.255", UDP_PORT, "BEACON//DARKCYFR_MEOW_S3")
    end

    -- 2. Non-blocking Receive UDP Packets
    local data, remote_ip, remote_port = meow.udp_recv()
    if data then
        add_log(string.format("[%s]: %s", remote_ip, data))
        meow.tone(2000, 60)
        meow.led(0, 80, 80) -- Flash Cyan
        -- Append to SD card log
        local cur_log = meow.read_file("/logs/walkie_comms.log") or ""
        meow.write_file("/logs/walkie_comms.log", cur_log .. string.format("[%d] %s: %s\n", now, remote_ip, data))
    end

    -- 3. Header Panel
    meow.rect(8, 6, 304, 28, COL_PANEL, true)
    meow.rect(8, 6, 304, 28, COL_CYAN, false)
    meow.text(14, 12, "WALKIE P2P // TERMINAL", COL_CYAN)
    meow.text(210, 12, string.format("PORT: %d", UDP_PORT), COL_LIME)

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
    meow.text(105, 174, quick_messages[selected_msg_idx], COL_LIME)
    meow.text(14, 192, "[A] Transmit   |   [UP/DN] Change Msg", COL_MUTED)

    -- 6. Navigation / Inputs
    if meow.btn("UP") and (now - last_btn_time > 200) then
        selected_msg_idx = selected_msg_idx - 1
        if selected_msg_idx < 1 then selected_msg_idx = #quick_messages end
        last_btn_time = now
        meow.tone(1200, 20)
    elseif meow.btn("DOWN") and (now - last_btn_time > 200) then
        selected_msg_idx = selected_msg_idx + 1
        if selected_msg_idx > #quick_messages then selected_msg_idx = 1 end
        last_btn_time = now
        meow.tone(1200, 20)
    elseif meow.btn("A") and (now - last_btn_time > 300) then
        last_btn_time = now
        local payload = quick_messages[selected_msg_idx]
        meow.udp_send("255.255.255.255", UDP_PORT, payload)
        add_log("[TX BROADCAST]: " .. payload)
        meow.tone(2500, 80)
        meow.led(80, 40, 0)
    end

    -- Footer
    meow.text(14, 218, "HOLD [B] TO RETURN TO SD APPS", COL_MUTED)
end
