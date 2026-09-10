local remote_view = require("scripts.remote_view")
local settings_gui = require("scripts.settings_gui")
local player_data = require("scripts.player_data")
local effect_manager = require("scripts.effect_manager")

script.on_init(remote_view.on_init)
script.on_load(remote_view.on_load)
script.on_configuration_changed(remote_view.on_configuration_changed)

script.on_event(defines.events.on_player_controller_changed, remote_view.on_player_controller_changed)
script.on_event(defines.events.on_player_changed_surface, remote_view.on_player_changed_surface)
script.on_event(defines.events.on_player_display_resolution_changed, remote_view.on_display_changed)
script.on_event(defines.events.on_player_display_scale_changed, remote_view.on_display_changed)
script.on_event(defines.events.on_player_display_density_scale_changed, remote_view.on_display_changed)
script.on_event(defines.events.on_player_died, remote_view.on_player_died)
script.on_event(defines.events.on_pre_player_died, remote_view.on_player_died)
script.on_event(defines.events.on_player_left_game, remote_view.on_player_left_game)
script.on_event(defines.events.on_player_joined_game, remote_view.on_player_joined)
script.on_event(defines.events.on_player_created, remote_view.on_player_joined)

script.on_event("rvc-toggle-settings", function(event)
  local player = game.get_player(event.player_index)
  if player then
    settings_gui.toggle(player)
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= "rvc-toggle-settings" then
    return
  end
  local player = game.get_player(event.player_index)
  if player then
    settings_gui.toggle(player)
  end
end)

script.on_event(defines.events.on_gui_click, settings_gui.on_gui_event)
script.on_event(defines.events.on_gui_checked_state_changed, settings_gui.on_gui_event)
script.on_event(defines.events.on_gui_value_changed, settings_gui.on_gui_event)
script.on_event(defines.events.on_gui_selection_state_changed, settings_gui.on_gui_event)

script.on_event(defines.events.on_gui_opened, function(event)
  local player = game.get_player(event.player_index)
  if player then
    effect_manager.sync(player)
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  settings_gui.on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if player then
    effect_manager.sync(player)
  end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if not event.setting or string.sub(event.setting, 1, 4) ~= "rvc-" then
    return
  end
  if not event.player_index then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local data = player_data.get(player)
  if event.setting == "rvc-enable" then
    data.enabled = player.mod_settings["rvc-enable"].value
    effect_manager.sync(player)
  elseif event.setting == "rvc-master-intensity" then
    data.master_intensity = player.mod_settings["rvc-master-intensity"].value
    effect_manager.sync(player)
  elseif event.setting == "rvc-debug" then
    data.debug = player.mod_settings["rvc-debug"].value
    effect_manager.sync(player)
  elseif event.setting == "rvc-remote-view-only" then
    data.remote_view_only = player.mod_settings["rvc-remote-view-only"].value
    if data.remote_view_only then
      data.global_overlay = false
    end
    effect_manager.sync(player)
  elseif event.setting == "rvc-default-preset" then
    local preset_id = player.mod_settings["rvc-default-preset"].value
    effect_manager.set_preset(player, preset_id)
  end
end)
