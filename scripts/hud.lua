--- Corner HUD readouts driven by real Factorio API data only.
local util = require("scripts.utilities")
local player_data = require("scripts.player_data")

local HUD_NAME = "rvc_hud"
local DEBUG_NAME = "rvc_debug"

local M = {}

--- @param player LuaPlayer
function M.destroy(player)
  for _, name in pairs({ HUD_NAME, DEBUG_NAME }) do
    local el = player.gui.screen[name]
    if el and el.valid then
      el.destroy()
    end
  end
end

--- @param data table
--- @return string
local function label_style(data)
  return data.label_style or "rvc_hud_label"
end

--- @param player LuaPlayer
--- @param data table
--- @return string, string  date_line, time_line
local function timestamp_lines(player, data)
  local mode = data.timestamp_mode or "off"
  if not data.timestamp or mode == "off" then
    return "", ""
  end
  if mode == "fixed" then
    return data.fixed_date or "08/17/1994", util.format_hms(game.ticks_played)
  end
  if mode == "real" then
    -- No OS clock in the API; use playtime clock.
    return "T+" .. tostring(util.day_index(game.ticks_played, 216000)), util.format_hms(game.ticks_played)
  end
  -- ingame
  local surface = player.surface
  local day = util.day_index(game.tick, surface.ticks_per_day)
  local tod = util.format_daytime(surface.daytime)
  return string.format("DAY %d", day), tod
end

--- @param player LuaPlayer
function M.build(player)
  M.destroy(player)
  local data = player_data.get(player)
  if not data.hud or data.hud_theme == "none" then
    if data.debug then
      M.build_debug(player)
    end
    return
  end

  local w, h = util.gui_size(player)
  local style = label_style(data)

  local root = player.gui.screen.add({
    type = "flow",
    name = HUD_NAME,
    direction = "vertical",
    ignored_by_interaction = true,
  })
  root.location = { 16, 16 }
  root.style.width = w - 32
  root.style.height = h - 32

  local top = root.add({ type = "flow", name = "top", direction = "horizontal", ignored_by_interaction = true })
  top.style.horizontally_stretchable = true
  local top_left = top.add({ type = "flow", name = "left", direction = "vertical", ignored_by_interaction = true })
  local top_spacer = top.add({ type = "empty-widget", name = "spacer", ignored_by_interaction = true })
  top_spacer.style.horizontally_stretchable = true
  local top_right = top.add({ type = "flow", name = "right", direction = "vertical", ignored_by_interaction = true })

  local mid = root.add({ type = "empty-widget", name = "mid", ignored_by_interaction = true })
  mid.style.vertically_stretchable = true

  local bottom = root.add({ type = "flow", name = "bottom", direction = "horizontal", ignored_by_interaction = true })
  bottom.style.horizontally_stretchable = true
  local bottom_left = bottom.add({ type = "flow", name = "left", direction = "vertical", ignored_by_interaction = true })
  local bottom_spacer = bottom.add({ type = "empty-widget", name = "spacer", ignored_by_interaction = true })
  bottom_spacer.style.horizontally_stretchable = true
  local bottom_right = bottom.add({ type = "flow", name = "right", direction = "vertical", ignored_by_interaction = true })

  local function lab(parent, name)
    return parent.add({
      type = "label",
      name = name,
      caption = "",
      style = style,
      ignored_by_interaction = true,
    })
  end

  lab(top_left, "l1")
  lab(top_left, "l2")
  lab(top_left, "l3")
  lab(top_right, "r1")
  lab(top_right, "r2")
  lab(top_right, "r3")
  lab(bottom_left, "bl1")
  lab(bottom_left, "bl2")
  lab(bottom_right, "br1")
  lab(bottom_right, "br2")

  M.refresh(player)

  if data.debug then
    M.build_debug(player)
  end
end

--- @param player LuaPlayer
function M.build_debug(player)
  local existing = player.gui.screen[DEBUG_NAME]
  if existing and existing.valid then
    existing.destroy()
  end
  local frame = player.gui.screen.add({
    type = "frame",
    name = DEBUG_NAME,
    direction = "vertical",
    ignored_by_interaction = true,
  })
  frame.location = { 16, 200 }
  for i = 1, 5 do
    frame.add({
      type = "label",
      name = "d" .. i,
      caption = "",
      style = "rvc_debug_label",
      ignored_by_interaction = true,
    })
  end
  M.refresh_debug(player)
end

--- @param player LuaPlayer
function M.refresh(player)
  local root = player.gui.screen[HUD_NAME]
  local data = player_data.get(player)
  if not root or not root.valid then
    if data.debug then
      M.refresh_debug(player)
    end
    return
  end

  local surface = player.surface
  local pos = player.position
  local cam = string.format("%02d", data.camera_seed or util.camera_id(surface, pos))
  local signal = util.signal_percent(player, data._signal_jitter)
  local date_line, time_line = timestamp_lines(player, data)
  local theme = data.hud_theme or "crt"
  local top_left = root.top.left
  local top_right = root.top.right
  local bottom_left = root.bottom.left
  local bottom_right = root.bottom.right

  local function set(el, caption)
    if el and el.valid then
      el.caption = caption
    end
  end

  if theme == "vhs" then
    -- ~1 Hz REC blink (HUD refresh is gated ~1/sec)
    local rec_on = (math.floor(game.tick / 60) % 2) == 0
    set(top_left.l1, rec_on and { "rvc.hud-rec-dot" } or { "rvc.hud-rec" })
    set(top_left.l2, { "rvc.hud-cam", cam })
    set(top_left.l3, date_line)
    set(top_right.r1, time_line)
    set(top_right.r2, { "rvc.hud-signal", tostring(signal) })
    set(top_right.r3, { "rvc.hud-play" })
    set(bottom_left.bl1, surface.name)
    set(bottom_left.bl2, { "rvc.hud-coords", string.format("%.0f", pos.x), string.format("%.0f", pos.y) })
    set(bottom_right.br1, { "rvc.hud-auto-tracking" })
    set(bottom_right.br2, { "rvc.hud-sp-hifi" })
  elseif theme == "pipboy" then
    set(top_left.l1, { "rvc.hud-remote-surveillance" })
    set(top_left.l2, "--------------------")
    set(top_left.l3, { "rvc.hud-location", surface.name })
    set(top_right.r1, { "rvc.hud-system" })
    set(top_right.r2, { "rvc.hud-power" })
    set(top_right.r3, { "rvc.hud-remote-link" })
    local filled = math.floor(signal / 10)
    local bar = string.rep("#", filled) .. string.rep("-", 10 - filled)
    set(bottom_left.bl1, { "rvc.hud-signal", tostring(signal) })
    set(bottom_left.bl2, bar)
    set(bottom_right.br1, { "rvc.hud-threats", tostring(math.floor(signal / 7)) })
    set(bottom_right.br2, { "rvc.hud-coords", string.format("%.0f", pos.x), string.format("%.0f", pos.y) })
  elseif theme == "military" then
    set(top_left.l1, { "rvc.hud-remote-uplink" })
    set(top_left.l2, "-------------")
    set(top_left.l3, { "rvc.hud-camera", "R-" .. cam })
    set(top_right.r1, { "rvc.hud-surface", string.upper(surface.name) })
    set(top_right.r2, { "rvc.hud-link" })
    set(top_right.r3, { "rvc.hud-status" })
    set(bottom_left.bl1, { "rvc.hud-grid-x", string.format("%.0f", pos.x) })
    set(bottom_left.bl2, { "rvc.hud-grid-y", string.format("%.0f", pos.y) })
    set(bottom_right.br1, { "rvc.hud-hostiles" })
    set(bottom_right.br2, date_line .. " " .. time_line)
  elseif theme == "scifi" then
    set(top_left.l1, { "rvc.hud-sensor-feed" })
    set(top_left.l2, { "rvc.hud-camera", "S-" .. cam })
    set(top_left.l3, { "rvc.hud-surface", surface.name })
    set(top_right.r1, { "rvc.hud-signal", tostring(signal) })
    set(top_right.r2, { "rvc.hud-link" })
    set(top_right.r3, time_line)
    set(bottom_left.bl1, { "rvc.hud-coords", string.format("%.1f", pos.x), string.format("%.1f", pos.y) })
    set(bottom_left.bl2, "ZOOM " .. string.format("%.2f", player.zoom or 1))
    set(bottom_right.br1, { "rvc.hud-preset", data.preset or "?" })
    set(bottom_right.br2, player.name)
  else
    -- crt / mono / default
    set(top_left.l1, { "rvc.hud-cam", cam })
    set(top_left.l2, surface.name)
    set(top_left.l3, date_line)
    set(top_right.r1, time_line)
    set(top_right.r2, { "rvc.hud-signal", tostring(signal) })
    set(top_right.r3, { "rvc.hud-preset", data.preset or "?" })
    set(bottom_left.bl1, { "rvc.hud-coords", string.format("%.0f", pos.x), string.format("%.0f", pos.y) })
    set(bottom_left.bl2, player.name)
    set(bottom_right.br1, { "rvc.hud-remote-link" })
    set(bottom_right.br2, "")
  end

  if data.debug then
    M.refresh_debug(player)
  end
end

--- @param player LuaPlayer
function M.refresh_debug(player)
  local frame = player.gui.screen[DEBUG_NAME]
  if not frame or not frame.valid then
    return
  end
  local data = player_data.get(player)
  local remote = util.is_remote(player) and "YES" or "NO"
  local surface = player.surface and player.surface.name or "?"
  local overlay = (storage.active_overlays and storage.active_overlays[player.index]) and "ACTIVE" or "OFF"
  frame.d1.caption = { "rvc.debug-remote", remote }
  frame.d2.caption = { "rvc.debug-surface", surface }
  frame.d3.caption = { "rvc.debug-overlay", overlay }
  frame.d4.caption = { "rvc.debug-preset", data.preset or "?" }
  frame.d5.caption = { "rvc.debug-glitch", data.last_glitch or "none" }
end

return M
