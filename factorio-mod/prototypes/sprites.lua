local PREFIX = "__analog-remote-view__/graphics/"

local function sprite(name, filename, size, flags)
  return {
    type = "sprite",
    name = name,
    filename = PREFIX .. filename,
    size = size,
    flags = flags or { "gui" },
  }
end

data:extend({
  sprite("rvc-white", "white.png", 1),
  sprite("rvc-black", "black.png", 1),
  sprite("rvc-wash-green", "wash-green.png", 1),
  sprite("rvc-wash-amber", "wash-amber.png", 1),
  sprite("rvc-wash-cyan", "wash-cyan.png", 1),
  sprite("rvc-wash-vhs", "wash-vhs.png", 1),
  sprite("rvc-wash-neutral", "wash-neutral.png", 1),
  sprite("rvc-scanlines", "scanlines.png", { 8, 4 }),
  sprite("rvc-scanlines-strong", "scanlines-strong.png", { 8, 4 }),
  sprite("rvc-phosphor", "phosphor-grid.png", 12),
  sprite("rvc-vignette", "vignette.png", 128),
  sprite("rvc-noise", "noise.png", 64),
  sprite("rvc-tear", "tear-band.png", { 256, 12 }),
  sprite("rvc-tracking", "tracking-bar.png", { 256, 10 }),
  sprite("rvc-bezel", "bezel.png", 64),
  sprite("rvc-brackets", "target-brackets.png", 64),
  {
    type = "sprite",
    name = "rvc-shortcut-icon",
    filename = PREFIX .. "shortcut-icon.png",
    size = 64,
    flags = { "gui-icon" },
  },
})
