-- ==============================================================================
-- MEOWKit S3 Dynamic App: Tactical Radar Recon
-- Author: DarkCyfr
-- Dynamic Lua 5.4 Application loaded from MicroSD (/apps/radar_recon.lua)
-- ==============================================================================

local COL_BG     = 0x0000
local COL_RADAR  = 0x03E0
local COL_SWEEP  = 0x07E0
local COL_BLIP   = 0xF800
local COL_TEXT   = 0x07FF
local COL_MUTED  = 0x0200
local COL_WHITE  = 0xFFFF

local angle = 0
local cx = 160
local cy = 120
local radius = 85
local r_outer = math.floor(radius)
local r_mid   = math.floor(radius * 0.66)
local r_inner = math.floor(radius * 0.33)

-- Simulated target contacts (r, angle_deg)
local targets = {
    { r = 40, a = 45,  hit = false },
    { r = 65, a = 160, hit = false },
    { r = 30, a = 230, hit = false },
    { r = 75, a = 310, hit = false }
}

-- Initial static HUD draw
meow.clear(COL_BG)
meow.text(10, 10,  "TACTICAL RADAR // ACTIVE", COL_TEXT)
meow.text(10, 215, "HOLD [B] TO RETURN", COL_MUTED)

local last_deg_drawn = -1

function on_loop()
    -- Quick check on Button B
    if meow.btn("B") or meow.btn(1) then
        -- Allow firmware hold-B detector to exit smoothly
    end

    -- Clear central radar ring area (interior circle)
    meow.circle(cx, cy, r_outer - 1, COL_BG, true)

    -- Draw concentric radar rings with explicit integer radii
    meow.circle(cx, cy, r_outer, COL_RADAR, false)
    meow.circle(cx, cy, r_mid,   COL_RADAR, false)
    meow.circle(cx, cy, r_inner, COL_RADAR, false)

    -- Crosshair lines
    meow.rect(cx - r_outer, cy, r_outer * 2, 1, COL_MUTED, true)
    meow.rect(cx, cy - r_outer, 1, r_outer * 2, COL_MUTED, true)

    -- Sweep line
    angle = (angle + 4) % 360
    local rad = angle * (3.14159265 / 180.0)
    local sx = math.floor(cx + math.cos(rad) * radius)
    local sy = math.floor(cy + math.sin(rad) * radius)
    meow.circle(sx, sy, 3, COL_SWEEP, true)

    -- Draw contacts and ping on sweep intercept
    for _, t in ipairs(targets) do
        local diff = math.abs(angle - t.a)
        if diff < 6 then
            if not t.hit then
                meow.tone(2400, 30)
                t.hit = true
            end
        else
            t.hit = false
        end

        local tr = t.a * (3.14159265 / 180.0)
        local tx = math.floor(cx + math.cos(tr) * t.r)
        local ty = math.floor(cy + math.sin(tr) * t.r)
        local blip_col = t.hit and COL_WHITE or COL_BLIP
        local blip_size = t.hit and 4 or 2
        meow.circle(tx, ty, blip_size, blip_col, true)
    end

    -- Update bearing readout (clear 110x18 area first to prevent font artifacting)
    if angle ~= last_deg_drawn then
        meow.rect(210, 10, 105, 18, COL_BG, true)
        meow.text(210, 10, string.format("BRG:%03d DEG", math.floor(angle)), COL_SWEEP)
        last_deg_drawn = angle
    end

    meow.delay(25) -- ~40 FPS smooth radar sweep
end
