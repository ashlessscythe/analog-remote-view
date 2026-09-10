--- Procedural glitch / tear / signal-loss engine (client-local, cosmetic).
local util = require("scripts.utilities")
local player_data = require("scripts.player_data")
local overlay = require("scripts.overlay")

local M = {}

local FREQ = {
  rare = 0.0008,
  occasional = 0.0025,
  frequent = 0.006,
}

local DUR = {
  short = { 12, 25 },
  medium = { 25, 50 },
  long = { 45, 90 },
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
      local y = math.random(20, math.max(40, h - 40))
      local band_h = math.random(6, 18)
      tear.location = { 1 + math.random(-8, 8), y }
      tear.style.width = w
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
  -- Dim scan/noise during loss for effect
  local noise = player.gui.screen.rvc_noise
  if noise and noise.valid and on then
    noise.visible = true
  end
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
      tint.visible = not tint.visible
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
  -- Restore noise visibility from settings
  overlay.apply_visibility(player)
end

--- Per-player update; call from nth-tick while overlay active.
--- @param player LuaPlayer
function M.update(player)
  local data = player_data.get(player)
  local tick = game.tick

  if data.signal_loss_until and data.signal_loss_until > 0 then
    if tick >= data.signal_loss_until then
      set_signal_loss(player, false)
      data.signal_loss_until = 0
      overlay.apply_visibility(player)
    end
  end

  if data.glitch_until and data.glitch_until > 0 and tick >= data.glitch_until then
    clear_tears(player)
    data.glitch_until = 0
    overlay.apply_visibility(player)
  end

  -- Flicker: rare brief toggle based on intensity
  if data.flicker_enabled and (data.flicker or 0) > 0 then
    local chance = (data.flicker or 0) * 0.01
    if math.random() < chance then
      local dur = math.random(3, 8)
      M.trigger(player, "flicker", dur)
    end
  end

  local tearing = data.tearing or "off"
  if tearing == "off" then
    return
  end

  -- Already glitching
  if data.glitch_until and tick < data.glitch_until then
    return
  end

  local freq = FREQ[data.glitch_frequency or "occasional"] or FREQ.occasional
  freq = freq * (TEAR_WEIGHT[tearing] or 0.5)
  if math.random() >= freq then
    return
  end

  local span = DUR[data.glitch_duration or "medium"] or DUR.medium
  local ticks = math.random(span[1], span[2])
  local roll = math.random()
  local kind = "tear"
  if roll < 0.08 then
    kind = "signal_loss"
    ticks = ticks * 2
  elseif roll < 0.3 then
    kind = "tracking"
  elseif roll < 0.5 then
    kind = "static_band"
  elseif roll < 0.65 then
    kind = "noise_burst"
  end
  M.trigger(player, kind, ticks)
end

return M
