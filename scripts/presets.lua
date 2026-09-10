--- Data-driven visual presets for Remote View CRT.
--- Adding a preset: append to `presets` and locale keys.

--- @class RvcPreset
--- @field id string
--- @field tint Color
--- @field opacity number
--- @field scanlines boolean
--- @field scanline_strength number
--- @field phosphor boolean
--- @field vignette number
--- @field noise number
--- @field flicker number
--- @field tearing string
--- @field glitch_frequency string
--- @field glitch_duration string
--- @field border boolean
--- @field brackets boolean
--- @field hud_theme string
--- @field show_hud boolean
--- @field timestamp_mode string
--- @field label_style string

--- @type table<string, RvcPreset>
local presets = {
  classic_crt = {
    id = "classic_crt",
    tint = { r = 0.55, g = 0.75, b = 0.55 },
    opacity = 0.12,
    scanlines = true,
    scanline_strength = 0.5,
    phosphor = true,
    vignette = 0.25,
    noise = 0.1,
    flicker = 0.05,
    tearing = "low",
    glitch_frequency = "rare",
    glitch_duration = "short",
    border = true,
    brackets = false,
    hud_theme = "crt",
    show_hud = true,
    timestamp_mode = "ingame",
    label_style = "rvc_hud_label_green",
  },
  pipboy = {
    id = "pipboy",
    tint = { r = 0.15, g = 0.85, b = 0.25 },
    opacity = 0.18,
    scanlines = true,
    scanline_strength = 0.5,
    phosphor = true,
    vignette = 0.3,
    noise = 0.1,
    flicker = 0.05,
    tearing = "low",
    glitch_frequency = "rare",
    glitch_duration = "short",
    border = true,
    brackets = false,
    hud_theme = "pipboy",
    show_hud = true,
    timestamp_mode = "ingame",
    label_style = "rvc_hud_label_green",
  },
  vhs = {
    id = "vhs",
    tint = { r = 0.7, g = 0.65, b = 0.55 },
    opacity = 0.1,
    scanlines = true,
    scanline_strength = 0.65,
    phosphor = false,
    vignette = 0.2,
    noise = 0.3,
    flicker = 0.15,
    tearing = "high",
    glitch_frequency = "occasional",
    glitch_duration = "medium",
    border = true,
    brackets = false,
    hud_theme = "vhs",
    show_hud = true,
    timestamp_mode = "fixed",
    label_style = "rvc_hud_label_vhs",
  },
  military = {
    id = "military",
    tint = { r = 0.25, g = 0.7, b = 0.3 },
    opacity = 0.14,
    scanlines = true,
    scanline_strength = 0.4,
    phosphor = true,
    vignette = 0.2,
    noise = 0.05,
    flicker = 0.02,
    tearing = "off",
    glitch_frequency = "rare",
    glitch_duration = "short",
    border = true,
    brackets = true,
    hud_theme = "military",
    show_hud = true,
    timestamp_mode = "ingame",
    label_style = "rvc_hud_label_military",
  },
  scifi = {
    id = "scifi",
    tint = { r = 0.2, g = 0.55, b = 0.95 },
    opacity = 0.12,
    scanlines = true,
    scanline_strength = 0.35,
    phosphor = false,
    vignette = 0.15,
    noise = 0.08,
    flicker = 0.04,
    tearing = "low",
    glitch_frequency = "occasional",
    glitch_duration = "short",
    border = false,
    brackets = true,
    hud_theme = "scifi",
    show_hud = true,
    timestamp_mode = "real",
    label_style = "rvc_hud_label_cyan",
  },
  mono_green = {
    id = "mono_green",
    tint = { r = 0.1, g = 0.9, b = 0.2 },
    opacity = 0.22,
    scanlines = true,
    scanline_strength = 0.55,
    phosphor = true,
    vignette = 0.35,
    noise = 0.08,
    flicker = 0.06,
    tearing = "low",
    glitch_frequency = "rare",
    glitch_duration = "short",
    border = true,
    brackets = false,
    hud_theme = "mono",
    show_hud = true,
    timestamp_mode = "ingame",
    label_style = "rvc_hud_label_green",
  },
  mono_amber = {
    id = "mono_amber",
    tint = { r = 0.95, g = 0.65, b = 0.15 },
    opacity = 0.2,
    scanlines = true,
    scanline_strength = 0.55,
    phosphor = true,
    vignette = 0.35,
    noise = 0.08,
    flicker = 0.06,
    tearing = "low",
    glitch_frequency = "rare",
    glitch_duration = "short",
    border = true,
    brackets = false,
    hud_theme = "mono",
    show_hud = true,
    timestamp_mode = "ingame",
    label_style = "rvc_hud_label_amber",
  },
  clean = {
    id = "clean",
    tint = { r = 1, g = 1, b = 1 },
    opacity = 0,
    scanlines = false,
    scanline_strength = 0,
    phosphor = false,
    vignette = 0,
    noise = 0,
    flicker = 0,
    tearing = "off",
    glitch_frequency = "rare",
    glitch_duration = "short",
    border = true,
    brackets = false,
    hud_theme = "none",
    show_hud = false,
    timestamp_mode = "off",
    label_style = "rvc_hud_label",
  },
}

local order = {
  "classic_crt",
  "pipboy",
  "vhs",
  "military",
  "scifi",
  "mono_green",
  "mono_amber",
  "clean",
}

local M = {}

--- @return string[]
function M.order()
  return order
end

--- @param id string
--- @return RvcPreset
function M.get(id)
  return presets[id] or presets.classic_crt
end

--- @param id string
--- @return boolean
function M.exists(id)
  return presets[id] ~= nil
end

--- Shallow-copy preset defaults into a settings table.
--- @param id string
--- @return table
function M.apply_defaults(id)
  local p = M.get(id)
  return {
    preset = p.id,
    crt = p.opacity > 0,
    scanlines = p.scanlines,
    scanline_strength = p.scanline_strength,
    vignette_enabled = p.vignette > 0,
    vignette = p.vignette,
    noise_enabled = p.noise > 0,
    noise = p.noise,
    flicker_enabled = p.flicker > 0,
    flicker = p.flicker,
    phosphor = p.phosphor,
    border = p.border,
    brackets = p.brackets,
    tearing = p.tearing,
    glitch_frequency = p.glitch_frequency,
    glitch_duration = p.glitch_duration,
    timestamp = p.timestamp_mode ~= "off",
    timestamp_mode = p.timestamp_mode,
    hud = p.show_hud,
    tint = { r = p.tint.r, g = p.tint.g, b = p.tint.b },
    opacity = p.opacity,
    hud_theme = p.hud_theme,
    label_style = p.label_style,
    fixed_date = "08/17/1994",
  }
end

return M
