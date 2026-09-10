--- Procedural glitch / tear / signal-loss engine (client-local, cosmetic).
local util = require("scripts.utilities")
local player_data = require("scripts.player_data")
local overlay = require("scripts.overlay")

local M = {}

-- Mean seconds between glitch bursts (nth-tick scheduler, not tiny per-tick odds).
local INTERVAL = {
  rare = { 45, 90 },
  occasional = { 8, 18 },
  frequent = { 3, 7 },
}

local DUR = {
  short = { 20, 40 },
  medium = { 35, 70 },
  long = { 60, 120 },
}

local TEAR_WEIGHT = {
  off = 0,
  low = 0.35,
  medium = 0.7,
  high = 1.0,
}

--- @param player LuaPlayer
local function clear_tears(player)
  for i = 1, 3 do
    local tear = player.gui.screen["rvc_tear" .. i]
    if tear and tear.valid then
      tear.visible = false
    end
  end
end

--- @param player LuaPlayer
--- @param strength number
local function show_tears(player, strength)
  local w, h = util.gui_size(player)
  local count = 1
  if strength > 0.6 then
    count = 3
  elseif strength > 0.35 then
    count = 2
  end
  for i = 1, count do
    local tear = player.gui.screen["rvc_tear" .. i]
    if tear and tear.valid then
      local y = math.random(24, math.max(48, h - 48))
      local band_h = math.random(14, 36)
      tear.location = { 1 + math.random(-12, 12), y }
      tear.style.width = w + math.random(0, 24)
      tear.style.height = band_h
      tear.visible = true
    end
  end
end

--- @param player LuaPlayer
--- @param on boolean
local function set_signal_loss(player, on)
  local loss = player.gui.screen.rvc_signal_loss
  if loss and loss.valid then
    loss.visible = on
  end
  local noise = player.gui.screen.rvc_noise
  if noise and noise.valid and on then
    noise.visible = true
  end
end

--- Schedule the next glitch time from frequency setting.
--- @param data table
--- @param from_tick uint
local function schedule_next(data, from_tick)
  local span = INTERVAL[data.glitch_frequency or "occasional"] or INTERVAL.occasional
  local tearing = data.tearing or "off"
  local weight = TEAR_WEIGHT[tearing] or 0.5
  if weight <= 0 then
    data.next_glitch_tick = nil
    return
  end
  -- Higher tearing → slightly shorter gaps
  local lo = math.floor(span[1] * (1.35 - 0.35 * weight))
  local hi = math.floor(span[2] * (1.35 - 0.35 * weight))
  if hi < lo then
    hi = lo
  end
  local seconds = math.random(lo, hi)
  data.next_glitch_tick = from_tick + seconds * 60
end

--- @param player LuaPlayer
--- @param kind string
--- @param ticks uint
function M.trigger(player, kind, ticks)
  local data = player_data.get(player)
  data.last_glitch = kind
  data.glitch_until = game.tick + ticks
  if kind == "signal_loss" then
    data.signal_loss_until = game.tick + ticks
    set_signal_loss(player, true)
  elseif kind == "tear" or kind == "tracking" or kind == "static_band" then
    show_tears(player, TEAR_WEIGHT[data.tearing or "low"] or 0.35)
  elseif kind == "flicker" then
    local tint = player.gui.screen.rvc_tint
    if tint and tint.valid then
      tint.visible = false
    end
  elseif kind == "noise_burst" then
    local noise = player.gui.screen.rvc_noise
    if noise and noise.valid then
      noise.visible = true
    end
  end
end

--- End active glitch visuals.
--- @param player LuaPlayer
function M.clear(player)
  local data = player_data.get(player)
  clear_tears(player)
  set_signal_loss(player, false)
  data.glitch_until = 0
  data.signal_loss_until = 0
  data.next_glitch_tick = nil
  overlay.apply_visibility(player)
end

--- Call when preset/tearing settings change so the schedule resets.
--- @param player LuaPlayer
function M.reschedule(player)
  local data = player_data.get(player)
  if (data.tearing or "off") == "off" then
    data.next_glitch_tick = nil
    return
  end
  -- First burst soon so VHS tearing is noticeable without a long wait
  local weight = TEAR_WEIGHT[data.tearing or "low"] or 0.5
  local first_sec = math.random(2, 5)
  if weight >= 0.9 then
    first_sec = math.random(1, 3)
  end
  data.next_glitch_tick = game.tick + first_sec * 60
end

--- Per-player update; call from nth-tick while overlay active.
--- @param player LuaPlayer
function M.update(player)
  local data = player_data.get(player)
  local tick = game.tick

  if data.signal_loss_until and data.signal_loss_until > 0 and tick >= data.signal_loss_until then
    set_signal_loss(player, false)
    data.signal_loss_until = 0
    overlay.apply_visibility(player)
  end

  if data.glitch_until and data.glitch_until > 0 and tick >= data.glitch_until then
    clear_tears(player)
    data.glitch_until = 0
    overlay.apply_visibility(player)
  end

  -- Subtle independent flicker (does not consume the tear schedule)
  if data.flicker_enabled and (data.flicker or 0) > 0 then
    local chance = (data.flicker or 0) * 0.008
    if math.random() < chance then
      local tint = player.gui.screen.rvc_tint
      if tint and tint.valid then
        local was = tint.visible
        tint.visible = false
        data._flicker_restore = tick + math.random(2, 6)
        data._flicker_was = was
      end
    end
  end
  if data._flicker_restore and tick >= data._flicker_restore then
    local tint = player.gui.screen.rvc_tint
    if tint and tint.valid then
      tint.visible = data._flicker_was and true or false
      if data.crt and (data.opacity or 0) > 0.01 then
        tint.visible = true
      end
    end
    data._flicker_restore = nil
  end

  local tearing = data.tearing or "off"
  if tearing == "off" then
    return
  end

  if data.glitch_until and tick < data.glitch_until then
    return
  end

  if not data.next_glitch_tick then
    schedule_next(data, tick)
    return
  end

  if tick < data.next_glitch_tick then
    return
  end

  local span = DUR[data.glitch_duration or "medium"] or DUR.medium
  local ticks_len = math.random(span[1], span[2])
  local roll = math.random()
  local kind = "tear"
  -- Bias toward visible tear/tracking for high tearing (VHS)
  local weight = TEAR_WEIGHT[tearing] or 0.5
  if weight >= 0.9 then
    if roll < 0.05 then
      kind = "signal_loss"
      ticks_len = ticks_len * 2
    elseif roll < 0.45 then
      kind = "tracking"
    elseif roll < 0.85 then
      kind = "tear"
    else
      kind = "static_band"
    end
  else
    if roll < 0.06 then
      kind = "signal_loss"
      ticks_len = ticks_len * 2
    elseif roll < 0.35 then
      kind = "tracking"
    elseif roll < 0.7 then
      kind = "tear"
    elseif roll < 0.85 then
      kind = "static_band"
    else
      kind = "noise_burst"
    end
  end

  M.trigger(player, kind, ticks_len)
  schedule_next(data, tick)
end

return M
