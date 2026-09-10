--- Remote View enter/exit lifecycle and related player events.
local util = require("scripts.utilities")
local player_data = require("scripts.player_data")
local effect_manager = require("scripts.effect_manager")
local settings_gui = require("scripts.settings_gui")
local hud = require("scripts.hud")
local overlay = require("scripts.overlay")

local M = {}

--- @param player LuaPlayer
function M.sync_player(player)
  if not player or not player.valid then
    return
  end
  effect_manager.sync(player)
end

--- @param event EventData.on_player_controller_changed
function M.on_player_controller_changed(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  M.sync_player(player)
end

--- @param event EventData.on_player_changed_surface
function M.on_player_changed_surface(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  -- HUD coords/surface update; overlay stays if still remote
  if effect_manager.should_show(player) then
    hud.refresh(player)
  end
end

--- @param event EventData.on_player_display_resolution_changed|EventData.on_player_display_scale_changed|EventData.on_player_display_density_scale_changed
function M.on_display_changed(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  if overlay.is_active(player) then
    overlay.resize(player)
    hud.destroy(player)
    hud.build(player)
  end
end

--- @param event EventData.on_player_died|EventData.on_pre_player_died
function M.on_player_died(event)
  local player = game.get_player(event.player_index)
  if player then
    -- Ghost/respawn may leave remote; sync handles it on controller change too
    effect_manager.sync(player)
  end
end

--- @param event EventData.on_player_left_game
function M.on_player_left_game(event)
  local player = game.get_player(event.player_index)
  if player then
    settings_gui.destroy(player)
    effect_manager.disable(player)
  end
  player_data.clear(event.player_index)
end

--- @param event EventData.on_player_joined_game|EventData.on_player_created
function M.on_player_joined(event)
  local player = game.get_player(event.player_index)
  if player then
    player_data.get(player)
    M.sync_player(player)
  end
end

function M.on_init()
  player_data.init()
  for _, player in pairs(game.players) do
    player_data.get(player)
    M.sync_player(player)
  end
end

function M.on_load()
  effect_manager.on_load()
end

function M.on_configuration_changed()
  player_data.init()
  for _, player in pairs(game.players) do
    local data = player_data.get(player)
    if not data.preset then
      storage.players[player.index] = player_data.create_defaults(player)
    end
    settings_gui.destroy(player)
    M.sync_player(player)
  end
end

return M
