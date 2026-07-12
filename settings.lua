data:extend{
  {
    type = "string-setting",
    name = "gw-enable-warnings",
    setting_type = "runtime-per-user",
    default_value = "on",
    allowed_values = {"on", "remote-only", "off"},
    order = "a",
  },
  {
    type = "double-setting",
    name = "gw-warning-cooldown",
    setting_type = "runtime-per-user",
    default_value = 5,
    minimum_value = 0,
    order = "b",
  },
  {
    type = "bool-setting",
    name = "gw-play-warning-sound",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "c",
  },

}
