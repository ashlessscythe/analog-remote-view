--- Shared helpers for Remote View CRT.
local util = {}

--- @param player LuaPlayer
--- @return boolean
function util.is_remote(player)
  return player.valid and player.controller_type == defines.controllers.remote
end

--- @param player LuaPlayer
--- @return integer, integer  GUI width/height in GUI pixels
function util.gui_size(player)
  local res = player.display_resolution
  local scale = player.display_scale
  if scale <= 0 then
    scale = 1
  end
  return math.floor(res.width / scale), math.floor(res.height / scale)
end

--- Clamp number into [lo, hi].
--- @param v number
--- @param lo number
--- @param hi number
--- @return number
function util.clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

--- @param ticks uint
--- @return string  HH:MM:SS
function util.format_hms(ticks)
  local total = math.floor(ticks / 60)
  local s = total % 60
  local m = math.floor(total / 60) % 60
  local h = math.floor(total / 3600) % 100
  return string.format("%02d:%02d:%02d", h, m, s)
end

--- Format surface daytime [0,1) as HH:MM:SS-ish clock.
--- @param daytime number
--- @return string
function util.format_daytime(daytime)
  local minutes = math.floor(daytime * 24 * 60) % (24 * 60)
  local h = math.floor(minutes / 60)
  local m = minutes % 60
  return string.format("%02d:%02d", h, m)
end

--- Map day index from ticks.
--- @param ticks uint
--- @param ticks_per_day uint
--- @return integer
function util.day_index(ticks, ticks_per_day)
  if not ticks_per_day or ticks_per_day == 0 then
    ticks_per_day = 25000
  end
  return math.floor(ticks / ticks_per_day) + 1
end

--- Stable pseudo camera id from surface + coords.
--- @param surface LuaSurface
--- @param position MapPosition
--- @return string
function util.camera_id(surface, position)
  local n = (surface.index * 17 + math.floor(position.x / 32) * 3 + math.floor(position.y / 32) * 7) % 99
  return string.format("%02d", n + 1)
end

--- Signal strength aesthetic from zoom / jitter.
--- @param player LuaPlayer
--- @param jitter number|nil
--- @return integer
function util.signal_percent(player, jitter)
  local z = player.zoom or 1
  local base = util.clamp(100 - math.abs(z - 1) * 15, 55, 99)
  return math.floor(util.clamp(base + (jitter or 0), 1, 99))
end

--- @param player LuaPlayer
--- @param name string
--- @return ModSetting|nil
function util.mod_setting(player, name)
  local settings_table = player.mod_settings
  return settings_table and settings_table[name]
end

--- @param player LuaPlayer
--- @param name string
--- @param default any
--- @return any
function util.setting_value(player, name, default)
  local s = util.mod_setting(player, name)
  if s == nil then
    return default
  end
  return s.value
end

return util
