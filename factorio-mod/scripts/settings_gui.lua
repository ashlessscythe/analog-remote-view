--- In-game settings window for Analog Remote View.
local presets = require("scripts.presets")
local player_data = require("scripts.player_data")
local effect_manager = require("scripts.effect_manager")

local ROOT = "rvc_settings"

local M = {}

local PRESET_IDS = presets.order()
local TEARING = { "off", "low", "medium", "high" }
local FREQ = { "rare", "occasional", "frequent" }
local DUR = { "short", "medium", "long" }
local TS = { "real", "ingame", "fixed", "off" }

local function index_of(list, value)
  for i, v in pairs(list) do
    if v == value then
      return i
    end
  end
  return 1
end

--- @param player LuaPlayer
function M.destroy(player)
  local el = player.gui.screen[ROOT]
  if el and el.valid then
    el.destroy()
  end
  local data = player_data.get(player)
  data.settings_open = false
end

--- @param player LuaPlayer
--- @return boolean
function M.is_open(player)
  local el = player.gui.screen[ROOT]
  return el ~= nil and el.valid
end

--- @param parent LuaGuiElement
--- @param name string
--- @param caption LocalisedString
--- @param state boolean
local function add_check(parent, name, caption, state)
  return parent.add({
    type = "checkbox",
    name = name,
    caption = caption,
    state = not not state,
    tags = { rvc = true, action = name },
  })
end

--- @param parent LuaGuiElement
--- @param name string
--- @param caption LocalisedString
--- @param value number
--- @param min number
--- @param max number
local function add_slider_row(parent, name, caption, value, min, max)
  local row = parent.add({ type = "flow", name = name .. "_row", direction = "horizontal" })
  row.add({ type = "label", caption = caption })
  local slider = row.add({
    type = "slider",
    name = name,
    minimum_value = min,
    maximum_value = max,
    value = value,
    value_step = 0.05,
    tags = { rvc = true, action = name },
  })
  slider.style.width = 160
  row.add({
    type = "label",
    name = name .. "_val",
    caption = string.format("%.0f%%", value * 100),
  })
  return slider
end

--- @param parent LuaGuiElement
--- @param name string
--- @param caption LocalisedString
--- @param items LocalisedString[]
--- @param selected uint
local function add_drop(parent, name, caption, items, selected)
  local row = parent.add({ type = "flow", name = name .. "_row", direction = "horizontal" })
  row.add({ type = "label", caption = caption })
  return row.add({
    type = "drop-down",
    name = name,
    items = items,
    selected_index = selected,
    tags = { rvc = true, action = name },
  })
end

--- @param player LuaPlayer
function M.toggle(player)
  if M.is_open(player) then
    M.destroy(player)
  else
    M.open(player)
  end
end

--- @param player LuaPlayer
function M.open(player)
  M.destroy(player)
  local data = player_data.get(player)

  local frame = player.gui.screen.add({
    type = "frame",
    name = ROOT,
    direction = "vertical",
  })
  frame.auto_center = true

  local title = frame.add({ type = "flow", name = "titlebar", direction = "horizontal", style = "rvc_titlebar_flow" })
  title.add({ type = "label", caption = { "rvc.settings-title" }, style = "frame_title" })
  local drag = title.add({
    type = "empty-widget",
    name = "drag",
    style = "rvc_draggable_space",
  })
  drag.drag_target = frame
  title.add({
    type = "sprite-button",
    name = "rvc_settings_close",
    style = "frame_action_button",
    sprite = "utility/close",
    tooltip = { "rvc.settings-close" },
    tags = { rvc = true, action = "close" },
  })

  local body = frame.add({
    type = "frame",
    name = "body",
    direction = "vertical",
    style = "rvc_settings_frame",
  })

  local preset_items = {}
  for _, id in pairs(PRESET_IDS) do
    preset_items[#preset_items + 1] = { "rvc.preset-" .. id }
  end
  add_drop(body, "rvc_preset", { "rvc.preset" }, preset_items, index_of(PRESET_IDS, data.preset))

  body.add({ type = "label", caption = { "rvc.effects" }, style = "bold_label" })

  add_check(body, "rvc_crt", { "rvc.crt" }, data.crt)
  add_check(body, "rvc_scanlines", { "rvc.scanlines" }, data.scanlines)
  add_slider_row(body, "rvc_scanline_strength", { "rvc.scanline-strength" }, data.scanline_strength or 0.5, 0, 1)
  add_check(body, "rvc_vignette", { "rvc.vignette" }, data.vignette_enabled)
  add_check(body, "rvc_noise", { "rvc.noise" }, data.noise_enabled)
  add_check(body, "rvc_flicker", { "rvc.flicker" }, data.flicker_enabled)

  local tear_items = {}
  for _, id in pairs(TEARING) do
    tear_items[#tear_items + 1] = { "rvc.tearing-" .. id }
  end
  add_drop(body, "rvc_tearing", { "rvc.tearing" }, tear_items, index_of(TEARING, data.tearing))

  local freq_items = {}
  for _, id in pairs(FREQ) do
    freq_items[#freq_items + 1] = { "rvc.freq-" .. id }
  end
  add_drop(body, "rvc_glitch_frequency", { "rvc.glitch-frequency" }, freq_items, index_of(FREQ, data.glitch_frequency))

  local dur_items = {}
  for _, id in pairs(DUR) do
    dur_items[#dur_items + 1] = { "rvc.dur-" .. id }
  end
  add_drop(body, "rvc_glitch_duration", { "rvc.glitch-duration" }, dur_items, index_of(DUR, data.glitch_duration))

  add_check(body, "rvc_timestamp", { "rvc.timestamp" }, data.timestamp)
  local ts_items = {}
  for _, id in pairs(TS) do
    ts_items[#ts_items + 1] = { "rvc.ts-" .. id }
  end
  add_drop(body, "rvc_timestamp_mode", { "rvc.timestamp-mode" }, ts_items, index_of(TS, data.timestamp_mode))

  add_check(body, "rvc_hud", { "rvc.hud" }, data.hud)
  add_check(body, "rvc_remote_view_only", { "rvc.remote-view-only" }, data.remote_view_only ~= false)
  add_check(body, "rvc_global_overlay", { "rvc.global-overlay" }, data.global_overlay)
  add_slider_row(body, "rvc_master_intensity", { "rvc.master-intensity" }, data.master_intensity or 1, 0, 1.5)
  add_check(body, "rvc_debug", { "rvc.debug" }, data.debug)

  body.add({
    type = "button",
    name = "rvc_reset_preset",
    caption = { "rvc.reset-preset" },
    tags = { rvc = true, action = "reset" },
  })

  data.settings_open = true
  player.opened = frame
end

--- Read GUI into player data and re-apply effects.
--- @param player LuaPlayer
function M.read_and_apply(player)
  local root = player.gui.screen[ROOT]
  if not root or not root.valid then
    return
  end
  local body = root.body
  local data = player_data.get(player)

  local preset_dd = body.rvc_preset_row and body.rvc_preset_row.rvc_preset or body.rvc_preset
  -- drop-downs live inside *_row flows
  local function dd(name)
    local row = body[name .. "_row"]
    if row and row[name] then
      return row[name]
    end
    return body[name]
  end
  local function chk(name)
    return body[name]
  end
  local function sld(name)
    local row = body[name .. "_row"]
    if row and row[name] then
      return row[name]
    end
    return body[name]
  end

  local preset_el = dd("rvc_preset")
  if preset_el and preset_el.selected_index then
    local id = PRESET_IDS[preset_el.selected_index]
    if id and id ~= data.preset then
      player_data.set_preset(player, id)
      -- refresh whole window to show new defaults
      M.open(player)
      effect_manager.sync(player)
      return
    end
  end

  local c
  c = chk("rvc_crt")
  if c then
    data.crt = c.state
  end
  c = chk("rvc_scanlines")
  if c then
    data.scanlines = c.state
  end
  c = chk("rvc_vignette")
  if c then
    data.vignette_enabled = c.state
  end
  c = chk("rvc_noise")
  if c then
    data.noise_enabled = c.state
  end
  c = chk("rvc_flicker")
  if c then
    data.flicker_enabled = c.state
  end
  c = chk("rvc_timestamp")
  if c then
    data.timestamp = c.state
  end
  c = chk("rvc_hud")
  if c then
    data.hud = c.state
  end
  c = chk("rvc_remote_view_only")
  if c then
    data.remote_view_only = c.state
    if c.state then
      data.global_overlay = false
      local g = chk("rvc_global_overlay")
      if g then
        g.state = false
      end
    end
  end
  c = chk("rvc_global_overlay")
  if c then
    data.global_overlay = c.state
    if c.state then
      data.remote_view_only = false
      local r = chk("rvc_remote_view_only")
      if r then
        r.state = false
      end
    end
  end
  c = chk("rvc_debug")
  if c then
    data.debug = c.state
  end

  local s = sld("rvc_scanline_strength")
  if s then
    data.scanline_strength = s.slider_value
    local lab = body.rvc_scanline_strength_row and body.rvc_scanline_strength_row.rvc_scanline_strength_val
    if lab then
      lab.caption = string.format("%.0f%%", s.slider_value * 100)
    end
  end
  s = sld("rvc_master_intensity")
  if s then
    data.master_intensity = s.slider_value
    local lab = body.rvc_master_intensity_row and body.rvc_master_intensity_row.rvc_master_intensity_val
    if lab then
      lab.caption = string.format("%.0f%%", s.slider_value * 100)
    end
  end

  local d = dd("rvc_tearing")
  if d then
    data.tearing = TEARING[d.selected_index] or data.tearing
  end
  d = dd("rvc_glitch_frequency")
  if d then
    data.glitch_frequency = FREQ[d.selected_index] or data.glitch_frequency
  end
  d = dd("rvc_glitch_duration")
  if d then
    data.glitch_duration = DUR[d.selected_index] or data.glitch_duration
  end
  d = dd("rvc_timestamp_mode")
  if d then
    data.timestamp_mode = TS[d.selected_index] or data.timestamp_mode
  end

  effect_manager.apply_settings(player)
end

--- @param event EventData.on_gui_click|EventData.on_gui_checked_state_changed|EventData.on_gui_value_changed|EventData.on_gui_selection_state_changed
function M.on_gui_event(event)
  local element = event.element
  if not element or not element.valid then
    return
  end
  local tags = element.tags
  if not tags or not tags.rvc then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if tags.action == "close" then
    M.destroy(player)
    return
  end
  if tags.action == "reset" then
    player_data.reset_to_preset(player)
    M.open(player)
    effect_manager.sync(player)
    return
  end

  M.read_and_apply(player)
end

--- @param event EventData.on_gui_closed
function M.on_gui_closed(event)
  if event.element and event.element.valid and event.element.name == ROOT then
    local player = game.get_player(event.player_index)
    if player then
      M.destroy(player)
    end
  end
end

return M
