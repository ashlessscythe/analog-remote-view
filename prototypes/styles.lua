local styles = data.raw["gui-style"].default

styles["rvc_overlay_root"] = {
  type = "empty_widget_style",
  parent = "empty_widget",
}

styles["rvc_fullscreen_sprite"] = {
  type = "image_style",
  parent = "image",
  stretch_image_to_widget_size = true,
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
}

styles["rvc_settings_frame"] = {
  type = "frame_style",
  parent = "inside_shallow_frame_with_padding",
  minimal_width = 360,
  maximal_width = 420,
}

styles["rvc_hud_label"] = {
  type = "label_style",
  parent = "label",
  font = "default-semibold",
  font_color = { r = 0.75, g = 0.95, b = 0.75 },
}

styles["rvc_hud_label_green"] = {
  type = "label_style",
  parent = "rvc_hud_label",
  font_color = { r = 0.25, g = 0.95, b = 0.35 },
}

styles["rvc_hud_label_amber"] = {
  type = "label_style",
  parent = "rvc_hud_label",
  font_color = { r = 0.95, g = 0.7, b = 0.2 },
}

styles["rvc_hud_label_cyan"] = {
  type = "label_style",
  parent = "rvc_hud_label",
  font_color = { r = 0.35, g = 0.9, b = 1.0 },
}

styles["rvc_hud_label_vhs"] = {
  type = "label_style",
  parent = "rvc_hud_label",
  font = "default-bold",
  font_color = { r = 0.95, g = 0.2, b = 0.2 },
}

styles["rvc_hud_label_military"] = {
  type = "label_style",
  parent = "rvc_hud_label",
  font = "default-small-semibold",
  font_color = { r = 0.4, g = 0.9, b = 0.4 },
}

styles["rvc_debug_label"] = {
  type = "label_style",
  parent = "label",
  font = "default-small",
  font_color = { r = 1, g = 1, b = 0.4 },
}

styles["rvc_titlebar_flow"] = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  horizontal_spacing = 8,
  vertically_stretchable = "on",
}

styles["rvc_draggable_space"] = {
  type = "empty_widget_style",
  parent = "draggable_space_header",
  horizontally_stretchable = "on",
  vertically_stretchable = "on",
  height = 24,
}
