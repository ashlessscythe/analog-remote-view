--- Orchestrates overlay, HUD, and glitch effects per player.
local util = require("scripts.utilities")
local player_data = require("scripts.player_data")
local overlay = require("scripts.overlay")
local hud = require("scripts.hud")
local glitch = require("scripts.glitch")

local M = {}

local NTH = 15 -- 4 Hz for glitch/HUD cadence (HUD also gates to ~1s)
local ANIM_NTH = 2 -- must match glitch.lua ANIM_DT; only while bands roll
--- Runtime-only; never persisted. Re-bound in on_load.
local nth_tick_registered = false
local anim_tick_registered = false

--- @return boolean
local function any_active()
  if not storage.active_overlays then
    return false
  end
  for _, v in pairs(storage.active_overlays) do
    if v then
      return true
    end
  end
  return false
end

--- @return boolean
local function any_rolling()
  if not storage.active_overlays then
    return false
  end
  -- Prefer LuaPlayer when `game` exists (runtime). on_load cannot use `game`.
  if game then
    for player_index, active in pairs(storage.active_overlays) do
      if active then
        local player = game.get_player(player_index)
        if player and player.valid and glitch.is_rolling(player) then
          return true
        end
      end
    end
    return false
  end
  local players = storage.players
  if not players then
    return false
  end
  for player_index, active in pairs(storage.active_overlays) do
    if active then
      local data = players[player_index]
      local bands = data and data.tear_bands
      if bands then
        for i = 1, #bands do
          local band = bands[i]
          if band and not band.done and band.mode ~= "static" then
            return true
          end
        end
      end
    end
  end
  return false
end

local function ensure_nth_tick()
  if any_active() then
    if not nth_tick_registered then
      script.on_nth_tick(NTH, M.on_nth_tick)
      nth_tick_registered = true
    end
  else
    if nth_tick_registered then
      script.on_nth_tick(NTH, nil)
      nth_tick_registered = false
    end
  end
end

local function ensure_anim_tick()
  if any_rolling() then
    if not anim_tick_registered then
      script.on_nth_tick(ANIM_NTH, M.on_anim_tick)
      anim_tick_registered = true
    end
  else
    if anim_tick_registered then
      script.on_nth_tick(ANIM_NTH, nil)
      anim_tick_registered = false
    end
  end
end

--- Should this player show the overlay right now?
--- @param player LuaPlayer
--- @return boolean
function M.should_show(player)
  if not player or not player.valid then
    return false
  end
  local data = player_data.get(player)
  if not data.enabled then
    return false
  end
  if util.setting_value(player, "rvc-enable", true) == false then
    return false
  end
  -- gui.screen always draws above entity/inventory GUIs; hide while those are open
  -- so E / Esc menus stay readable. Keep overlay while our settings window is open
  -- so preset tweaks can be previewed live.
  local opened = player.opened
  if opened ~= nil then
    local keep_for_settings = opened.object_name == "LuaGuiElement"
      and opened.valid
      and opened.name == "rvc_settings"
    if not keep_for_settings then
      return false
    end
  end
  if data.global_overlay then
    return true
  end
  return util.is_remote(player)
end

--- @param player LuaPlayer
function M.disable(player)
  glitch.clear(player)
  hud.destroy(player)
  overlay.destroy(player)
  ensure_nth_tick()
  ensure_anim_tick()
end

--- @param player LuaPlayer
function M.enable(player)
  if not M.should_show(player) then
    M.disable(player)
    return
  end
  overlay.build(player)
  hud.build(player)
  glitch.reschedule(player)
  ensure_nth_tick()
  ensure_anim_tick()
end

--- Rebuild or tear down based on current state.
--- @param player LuaPlayer
function M.sync(player)
  if M.should_show(player) then
    if overlay.is_active(player) then
      overlay.apply_visibility(player)
      overlay.resize(player)
      hud.destroy(player)
      hud.build(player)
    else
      M.enable(player)
    end
  else
    M.disable(player)
  end
end

--- @param player LuaPlayer
--- @param preset_id string
function M.set_preset(player, preset_id)
  player_data.set_preset(player, preset_id)
  -- Full rebuild so tint/HUD theme swap immediately
  if M.should_show(player) then
    M.enable(player)
  else
    M.disable(player)
  end
end

--- @param player LuaPlayer
function M.apply_settings(player)
  glitch.reschedule(player)
  M.sync(player)
end

--- @param event NthTickEventData
function M.on_nth_tick(event)
  if not storage.active_overlays then
    return
  end
  for player_index, active in pairs(storage.active_overlays) do
    if active then
      local player = game.get_player(player_index)
      if player and player.valid then
        if not M.should_show(player) then
          M.disable(player)
        else
          glitch.update(player)
          -- HUD timestamp ~1/sec
          if event.tick % 60 < NTH then
            hud.refresh(player)
          end
        end
      end
    end
  end
  ensure_nth_tick()
  ensure_anim_tick()
end

--- Fast path: scroll tear/tracking sprites while a burst is visible.
--- @param event NthTickEventData
function M.on_anim_tick(event)
  if not storage.active_overlays then
    return
  end
  for player_index, active in pairs(storage.active_overlays) do
    if active then
      local player = game.get_player(player_index)
      if player and player.valid then
        glitch.animate(player)
      end
    end
  end
  ensure_anim_tick()
end

--- Re-bind nth tick after load (do not write `storage` here).
function M.on_load()
  nth_tick_registered = false
  anim_tick_registered = false
  if any_active() then
    script.on_nth_tick(NTH, M.on_nth_tick)
    nth_tick_registered = true
  end
  if any_rolling() then
    script.on_nth_tick(ANIM_NTH, M.on_anim_tick)
    anim_tick_registered = true
  end
end

return M
