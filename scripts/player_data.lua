--- Per-player persistent settings in `storage`.
local presets = require("scripts.presets")
local util = require("scripts.utilities")

local M = {}

local function ensure_storage()
  storage.players = storage.players or {}
  storage.active_overlays = storage.active_overlays or {}
end

--- @param player LuaPlayer
--- @return table
function M.get(player)
  ensure_storage()
  local data = storage.players[player.index]
  if not data then
    data = M.create_defaults(player)
    storage.players[player.index] = data
  end
  return data
end

--- @param player LuaPlayer
--- @return table
function M.create_defaults(player)
  local preset_id = util.setting_value(player, "rvc-default-preset", "classic_crt")
  if not presets.exists(preset_id) then
    preset_id = "classic_crt"
  end
  local cfg = presets.apply_defaults(preset_id)
  cfg.enabled = util.setting_value(player, "rvc-enable", true)
  cfg.remote_view_only = util.setting_value(player, "rvc-remote-view-only", true)
  cfg.global_overlay = false
  cfg.master_intensity = util.setting_value(player, "rvc-master-intensity", 1.0)
  cfg.debug = util.setting_value(player, "rvc-debug", false)
  cfg.settings_open = false
  cfg.last_glitch = "none"
  cfg.glitch_until = 0
  cfg.signal_loss_until = 0
  cfg.camera_seed = math.random(1, 99)
  return cfg
end

--- Reset effect fields from the selected preset, keep enable flags.
--- @param player LuaPlayer
function M.reset_to_preset(player)
  local data = M.get(player)
  local preset_id = data.preset or "classic_crt"
  local fresh = presets.apply_defaults(preset_id)
  for k, v in pairs(fresh) do
    data[k] = v
  end
end

--- Apply a new preset id and its defaults.
--- @param player LuaPlayer
--- @param preset_id string
function M.set_preset(player, preset_id)
  if not presets.exists(preset_id) then
    return
  end
  local data = M.get(player)
  local enabled = data.enabled
  local remote_view_only = data.remote_view_only
  local global_overlay = data.global_overlay
  local master_intensity = data.master_intensity
  local debug = data.debug
  local settings_open = data.settings_open
  local camera_seed = data.camera_seed
  local fresh = presets.apply_defaults(preset_id)
  for k, v in pairs(fresh) do
    data[k] = v
  end
  data.enabled = enabled
  data.remote_view_only = remote_view_only
  data.global_overlay = global_overlay
  data.master_intensity = master_intensity
  data.debug = debug
  data.settings_open = settings_open
  data.camera_seed = camera_seed
end

--- @param player_index uint
function M.clear(player_index)
  ensure_storage()
  storage.players[player_index] = nil
  storage.active_overlays[player_index] = nil
end

function M.init()
  ensure_storage()
end

return M
