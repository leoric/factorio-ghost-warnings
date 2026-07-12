data:extend{
  {
    type = "custom-input",
    name = "gw-build",
    key_sequence = "",
    linked_game_control = "build"
  },
  {
    type = "custom-input",
    name = "gw-build-ghost",
    key_sequence = "",
    linked_game_control = "build-ghost"
  },
  {
    type = "custom-input",
    name = "gw-build-with-obstacle-avoidance",
    key_sequence = "",
    linked_game_control = "build-with-obstacle-avoidance"
  },
  {
    type = "custom-input",
    name = "gw-select-for-blueprint",
    key_sequence = "",
    linked_game_control = "select-for-blueprint"
  },
  {
    type = "custom-input",
    name = "gw-reverse-select",
    key_sequence = "",
    linked_game_control = "reverse-select"
  },
  {
    type = "custom-input",
    name = "gw-select-for-cancel-deconstruct",
    key_sequence = "",
    linked_game_control = "select-for-cancel-deconstruct"
  },
  {
    type = "sound",
    name = "gw-warning-sound",
    filename = "__GhostWarnings__/sounds/gw-alert.wav",
    category = "game-effect",
    volume = 0.4,
  }
}

local created_effect_trigger = {
  type = "direct",
  action_delivery = {
    type = "instant",
    source_effects = {
      {
        type = "script",
        effect_id = "gw-irp-created",
      },
    }
  }
}
-- Add created_effect trigger if there is already one or more triggers defined
if data.raw["item-request-proxy"]["item-request-proxy"].created_effect then
  if data.raw["item-request-proxy"]["item-request-proxy"].created_effect.type then
    data.raw["item-request-proxy"]["item-request-proxy"].created_effect = {
      data.raw["item-request-proxy"]["item-request-proxy"].created_effect,
      created_effect_trigger
    }
  else
    table.insert(data.raw["item-request-proxy"]["item-request-proxy"].created_effect, created_effect_trigger)
  end
else
  data.raw["item-request-proxy"]["item-request-proxy"].created_effect = created_effect_trigger
end