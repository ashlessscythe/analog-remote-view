--- Full-screen CRT overlay layers on player.gui.screen.
local util = require("scripts.utilities")
local player_data = require("scripts.player_data")

local LAYER_NAMES = {
  "rvc_tint",
  "rvc_scanlines",
  "rvc_phosphor",
  "rvc_vignette",
  "rvc_noise",
  "rvc_bezel",
  "rvc_brackets",
  "rvc_tear1",
  "rvc_tear2",
  "rvc_tear3",
  "rvc_signal_loss",
  "rvc_hud",
  "rvc_debug",
}

local M = {}

--- @param tint Color|nil
--- @return string
local function wash_sprite_for_tint(tint)
  if not tint then
    return "rvc-wash-neutral"
  end
  local r, g, b = tint.r or 0, tint.g or 0, tint.b or 0
  if g > r and g > b and g > 0.5 then
    return "rvc-wash-green"
  end
  if r > 0.7 and g > 0.4 and b < 0.4 then
    return "rvc-wash-amber"
  end
  if b > r and b > 0.5 then
    return "rvc-wash-cyan"
  end
  if r > 0.5 and g > 0.4 and b > 0.3 and r < 0.85 then
    return "rvc-wash-vhs"
  end
  return "rvc-wash-neutral"
end

--- @param player LuaPlayer
function M.destroy(player)
  local screen = player.gui.screen
  for _, name in pairs(LAYER_NAMES) do
    local el = screen[name]
    if el and el.valid then
      el.destroy()
    end
  end
  storage.active_overlays = storage.active_overlays or {}
  storage.active_overlays[player.index] = nil
end

--- @param player LuaPlayer
--- @param name string
--- @param sprite_path string
--- @param w integer
--- @param h integer
--- @param visible boolean
--- @return LuaGuiElement
local function place_fullscreen(player, name, sprite_path, w, h, visible)
  local el = player.gui.screen.add({
    type = "sprite",
    name = name,
    sprite = sprite_path,
    ignored_by_interaction = true,
    resize_to_sprite = false,
    style = "rvc_fullscreen_sprite",
  })
  el.location = { 1, 0 }
  el.style.width = w
  el.style.height = h
  el.style.stretch_image_to_widget_size = true
  el.visible = not not visible
  return el
end

--- @param player LuaPlayer
function M.build(player)
  M.destroy(player)
  local w, h = util.gui_size(player)
  local data = player_data.get(player)
  local intensity = util.clamp(data.master_intensity or 1, 0, 1.5)

  local show_tint = data.crt and (data.opacity or 0) * intensity > 0.01
  local show_scan = data.scanlines and (data.scanline_strength or 0) * intensity > 0.01
  local scan_sprite = ((data.scanline_strength or 0) >= 0.6) and "rvc-scanlines-strong" or "rvc-scanlines"
  local show_phos = data.phosphor and intensity > 0.01 and data.preset ~= "clean"
  local show_vig = data.vignette_enabled and (data.vignette or 0) * intensity > 0.01
  local show_noise = data.noise_enabled and (data.noise or 0) * intensity > 0.01

  place_fullscreen(player, "rvc_tint", wash_sprite_for_tint(data.tint), w, h, show_tint)
  place_fullscreen(player, "rvc_scanlines", scan_sprite, w, h, show_scan)
  place_fullscreen(player, "rvc_phosphor", "rvc-phosphor", w, h, show_phos)
  place_fullscreen(player, "rvc_vignette", "rvc-vignette", w, h, show_vig)
  place_fullscreen(player, "rvc_noise", "rvc-noise", w, h, show_noise)
  place_fullscreen(player, "rvc_bezel", "rvc-bezel", w, h, data.border)
  place_fullscreen(player, "rvc_brackets", "rvc-brackets", w, h, data.brackets)

  for i = 1, 3 do
    local tear = player.gui.screen.add({
      type = "sprite",
      name = "rvc_tear" .. i,
      sprite = (i == 2) and "rvc-tracking" or "rvc-tear",
      ignored_by_interaction = true,
      resize_to_sprite = false,
    })
    tear.location = { 1, math.floor(h * (0.15 + 0.22 * i)) }
    tear.style.width = w
    tear.style.height = 8 + i * 2
    tear.style.stretch_image_to_widget_size = true
    tear.visible = false
  end

  local loss = player.gui.screen.add({
    type = "frame",
    name = "rvc_signal_loss",
    direction = "vertical",
    ignored_by_interaction = true,
  })
  loss.auto_center = true
  loss.visible = false
  loss.add({
    type = "label",
    name = "title",
    caption = { "rvc.hud-signal-lost" },
    style = "rvc_hud_label_vhs",
  })
  loss.add({
    type = "label",
    name = "sub",
    caption = { "rvc.hud-link-failure" },
    style = "rvc_hud_label",
  })
  loss.add({
    type = "label",
    name = "rec",
    caption = { "rvc.hud-reconnecting" },
    style = "rvc_hud_label",
  })

  storage.active_overlays = storage.active_overlays or {}
  storage.active_overlays[player.index] = true
end

--- @param player LuaPlayer
function M.resize(player)
  if not storage.active_overlays or not storage.active_overlays[player.index] then
    return
  end
  local w, h = util.gui_size(player)
  for _, name in pairs({
    "rvc_tint",
    "rvc_scanlines",
    "rvc_phosphor",
    "rvc_vignette",
    "rvc_noise",
    "rvc_bezel",
    "rvc_brackets",
  }) do
    local el = player.gui.screen[name]
    if el and el.valid then
      el.location = { 1, 0 }
      el.style.width = w
      el.style.height = h
    end
  end
  for i = 1, 3 do
    local tear = player.gui.screen["rvc_tear" .. i]
    if tear and tear.valid then
      tear.style.width = w
    end
  end
end

--- @param player LuaPlayer
function M.apply_visibility(player)
  local data = player_data.get(player)
  local intensity = util.clamp(data.master_intensity or 1, 0, 1.5)
  local screen = player.gui.screen

  local function set_vis(name, on)
    local el = screen[name]
    if el and el.valid then
      el.visible = not not on
    end
  end

  set_vis("rvc_tint", data.crt and (data.opacity or 0) * intensity > 0.01)
  local tint = screen.rvc_tint
  if tint and tint.valid and data.tint then
    tint.sprite = wash_sprite_for_tint(data.tint)
  end

  local show_scan = data.scanlines and (data.scanline_strength or 0) * intensity > 0.01
  set_vis("rvc_scanlines", show_scan)
  local scan = screen.rvc_scanlines
  if scan and scan.valid then
    scan.sprite = ((data.scanline_strength or 0) >= 0.6) and "rvc-scanlines-strong" or "rvc-scanlines"
  end

  set_vis("rvc_phosphor", data.phosphor and intensity > 0.01 and data.preset ~= "clean")
  set_vis("rvc_vignette", data.vignette_enabled and (data.vignette or 0) * intensity > 0.01)
  set_vis("rvc_noise", data.noise_enabled and (data.noise or 0) * intensity > 0.01)
  set_vis("rvc_bezel", data.border)
  set_vis("rvc_brackets", data.brackets)
end

--- @param player LuaPlayer
--- @return boolean
function M.is_active(player)
  return storage.active_overlays and storage.active_overlays[player.index] == true
end

return M
