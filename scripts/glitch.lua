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

-- Must match effect_manager ANIM_NTH. Speeds are stored in pixels per anim step.
local ANIM_DT = 2

--- @param player LuaPlayer
--- @param i integer
--- @param band table
--- @param w integer
local function apply_band(player, i, band, w)
  local tear = player.gui.screen["rvc_tear" .. i]
  if not tear or not tear.valid then
    return
  end
  tear.sprite = band.sprite
  tear.location = { math.floor(band.x), math.floor(band.y) }
  tear.style.width = w + (band.w_extra or 0)
  tear.style.height = math.max(8, math.floor(band.band_h))
  tear.style.stretch_image_to_widget_size = true
  tear.visible = true
end

--- @param player LuaPlayer
local function clear_tears(player)
  local data = player_data.get(player)
  data.tear_bands = nil
  for i = 1, 3 do
    local tear = player.gui.screen["rvc_tear" .. i]
    if tear and tear.valid then
      tear.visible = false
    end
  end
end

--- @param player LuaPlayer
--- @param kind string
--- @param strength number
--- @param duration_ticks number
local function show_tears(player, kind, strength, duration_ticks)
  local data = player_data.get(player)
  local w, h = util.gui_size(player)
  for i = 1, 3 do
    local tear = player.gui.screen["rvc_tear" .. i]
    if tear and tear.valid then
      tear.visible = false
    end
  end

  local count = 1
  if strength > 0.6 then
    count = 3
  elseif strength > 0.35 then
    count = 2
  end

  local going_down = math.random() < 0.5
  local dy_sign = going_down and 1 or -1
  local mode = "static"
  if kind == "tear" then
    mode = "roll"
  elseif kind == "tracking" then
    mode = "drift"
  end
  local sprite = (kind == "tracking") and "rvc-tracking" or "rvc-tear"
  local ticks = math.max(duration_ticks or 40, 1)
  local zone_h = math.max(48, math.floor(h * (0.22 + math.random() * 0.08)))

  data.tear_bands = {}
  for i = 1, count do
    local base_h = math.random(14, 36)
    if mode == "drift" then
      base_h = math.random(18, 42)
    end
    local stagger = (i - 1) * math.random(10, 28)
    local y
    local dy = 0
    if mode == "static" then
      y = math.random(24, math.max(48, h - 48))
    elseif mode == "roll" then
      local dist = h + base_h
      dy = dy_sign * (dist / ticks) * ANIM_DT
      if going_down then
        y = -base_h - stagger
      else
        y = h + stagger
      end
    else
      -- Edge-weighted tracking: crawl the chosen edge zone, wrap while the burst lasts.
      dy = dy_sign * math.max(1.2, (zone_h / ticks) * ANIM_DT * 0.9)
      if going_down then
        y = -base_h - stagger * 0.25
      else
        y = h + stagger * 0.25
      end
    end

    local band = {
      y = y,
      dy = dy,
      x = 1 + math.random(-12, 12),
      band_h = base_h,
      base_h = base_h,
      w_extra = math.random(0, 24),
      mode = mode,
      going_down = going_down,
      zone_h = zone_h,
      sprite = sprite,
      done = false,
    }
    data.tear_bands[i] = band
    apply_band(player, i, band, w)
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

--- True while a tear/tracking band still needs the fast anim tick.
--- @param player LuaPlayer
--- @return boolean
function M.is_rolling(player)
  if not player or not player.valid then
    return false
  end
  local data = player_data.get(player)
  local bands = data.tear_bands
  if not bands then
    return false
  end
  if not data.glitch_until or data.glitch_until <= 0 or game.tick >= data.glitch_until then
    return false
  end
  for i = 1, #bands do
    local band = bands[i]
    if band and not band.done and band.mode ~= "static" then
      return true
    end
  end
  return false
end

--- Step rolling/drifting bands. Call from the 2-tick anim handler.
--- @param player LuaPlayer
--- @return boolean  still rolling
function M.animate(player)
  local data = player_data.get(player)
  if data.glitch_until and data.glitch_until > 0 and game.tick >= data.glitch_until then
    clear_tears(player)
    data.glitch_until = 0
    overlay.apply_visibility(player)
    return false
  end

  local bands = data.tear_bands
  if not bands then
    return false
  end

  local w, h = util.gui_size(player)
  local any_rolling = false
  for i = 1, #bands do
    local band = bands[i]
    if band and not band.done then
      if band.mode ~= "static" then
        band.y = band.y + band.dy
      end
      if math.random() < 0.2 then
        band.x = 1 + math.random(-12, 12)
      else
        band.x = 1 + math.random(-4, 4)
      end
      if math.random() < 0.18 then
        band.base_h = util.clamp(band.base_h + math.random(-3, 3), 12, 48)
      end

      if band.mode == "drift" then
        local zone_h = band.zone_h or math.floor(h * 0.25)
        local t
        if band.going_down then
          if band.y > zone_h then
            band.y = -band.base_h
          end
          t = util.clamp((band.y + band.base_h) / zone_h, 0, 1)
        else
          if band.y + band.base_h < h - zone_h then
            band.y = h
          end
          t = util.clamp((h - band.y) / zone_h, 0, 1)
        end
        -- Taller toward the outer edge, like ntsc-rs intensity_scale.
        band.band_h = band.base_h * (1.35 - 0.55 * t)
        any_rolling = true
      elseif band.mode == "roll" then
        band.band_h = band.base_h
        local off = band.going_down and (band.y > h) or (band.y + band.band_h < 0)
        if off then
          band.done = true
          local tear = player.gui.screen["rvc_tear" .. i]
          if tear and tear.valid then
            tear.visible = false
          end
        else
          any_rolling = true
        end
      else
        band.band_h = band.base_h
      end

      if not band.done then
        apply_band(player, i, band, w)
      end
    end
  end

  return any_rolling
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
    show_tears(player, kind, TEAR_WEIGHT[data.tearing or "low"] or 0.35, ticks)
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

  -- Active burst: keep stepping via animate(); do not schedule a second burst.
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
