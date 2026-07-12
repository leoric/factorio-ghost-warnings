local function get_warning_history(player_index)
  local warning_history = storage.warning_history
  local player_history = warning_history[player_index] or {}
  warning_history[player_index] = player_history
  return player_history
end


local function check_update_history(current_tick, item_name, player, surface_name)
  local player_index = player.index
  local player_history = get_warning_history(player_index)


  if surface_name ~= player_history.surface or (player_history.last_tick and current_tick - player_history.last_tick > 7200) then
    -- Player has changed surface or the last event was a long time ago: reset history
    storage.warning_history[player_index] = {
      surface = surface_name,
      last_tick = current_tick,
      items = {
        [item_name] = current_tick
      },
      since_last_click = {},
    }
    return true
  end
  if not player_history.since_last_click[item_name] then
    player_history.since_last_click[item_name] = true

    local last_item_tick = player_history.items[item_name]
    local cooldown = player.mod_settings["gw-warning-cooldown"].value * 60

    if not last_item_tick or (current_tick - last_item_tick > cooldown) then
      player_history.items[item_name] = current_tick
      return true
    end
  end
end

local function at_least_one_item_in_network(items, quality, networks)
  local all_hidden = true  -- LTN stations etc (composite entities)
  local item_prototypes
  for _, item in pairs(items) do
    for _, network in pairs(networks) do
      if network.get_item_count({name = item.name, quality = quality}) >= item.count then
        return true
      end
    end
    item_prototypes = item_prototypes or prototypes.item
    if not item_prototypes[item.name].hidden then
      all_hidden = false
    end
  end
  if all_hidden then
    return true
  end
  return false
end

local function all_items_in_network(items, networks)
  for _, item_request_data in pairs(items) do
    local found_count = 0
    for _, network in pairs(networks) do
      found_count = found_count + network.get_item_count({name = item_request_data.name, quality = item_request_data.quality})
    end
    if found_count < item_request_data.count then
      return false, item_request_data.name, item_request_data.quality
    end
  end
  return true
end

local function on_built_entity(entity, player, player_index, override_requests)
  -- override_requests used when dealing with custom event from Module Inserter Simplified
  local setting = player.mod_settings["gw-enable-warnings"].value
  if setting == "off" then return end
  if setting == "remote-only" then
    if player.controller_type ~= defines.controllers.remote then
      return
    end
  end
  local success = false
  local message = {"ghost-warnings.not-in-construction-network"}

  local force = entity.force
  local surface = entity.surface
  local position = entity.position
  local logistic_networks = surface.find_logistic_networks_by_construction_area(position, force)

  local missing_name
  -- entity.type is either entity-ghost, tile-ghost, or item-request-proxy
  -- (or any other entity if override_requests is set)
  if next(logistic_networks) then
    if entity.type ~= "item-request-proxy" and not override_requests then
      local prototype = entity.ghost_prototype
      local items_to_place_this = prototype.items_to_place_this
      local quality = entity.quality.name
      success = at_least_one_item_in_network(items_to_place_this, quality, logistic_networks)
      missing_name = prototype.name
      local localised_name_with_quality = prototype.localised_name
      if quality ~= "normal" then
        localised_name_with_quality = {"", "[quality=", quality, "] ", localised_name_with_quality}
      end
      message = {"missing-item", localised_name_with_quality}
    end
    if entity.type ~= "tile-ghost" then
      local item_requests = override_requests or entity.item_requests
      if (entity.type == "item-request-proxy" or success or override_requests) and next(item_requests) then
        success, missing_name, missing_quality = all_items_in_network(item_requests, logistic_networks)
        if missing_name then
          local localised_name_with_quality = prototypes.item[missing_name].localised_name
          if missing_quality ~= "normal" then
            localised_name_with_quality = {"", "[quality=", missing_quality, "] ", localised_name_with_quality}
          end
          message = {"missing-item", localised_name_with_quality}
        end
      end
    end
  end

  local tick = game.tick
  if not success and check_update_history(tick, missing_name or "gw-not-in-construction-network", player, surface.name) then
    player.create_local_flying_text{
      text = message,
      position = position,
    }
    local sound_history = storage.sound_history
    if player.mod_settings["gw-play-warning-sound"].value and (not sound_history[player_index] or sound_history[player_index] ~= tick) then
      player.play_sound{ path = "gw-warning-sound" }
      sound_history[player_index] = tick
    end
  end
end

script.on_event(defines.events.on_built_entity,
  function(event)
    local entity = event.entity
    local player_index = event.player_index
    local player = game.get_player(player_index)
    on_built_entity(entity, player, player_index)
  end,
  {{ filter = "ghost" }}
)
script.on_event(defines.events.script_raised_built,
  function(event)
    -- TODO 2.0 currently not used
    -- script_raised_built doesn't give a player, so raise for all players on force
    local entity = event.entity
    local force = entity.force

    -- Check each player to see if any of them have used a module inserter this tick. If so assume that it was them.
    for _, player in pairs(force.connected_players) do
      if storage.script_raised_built_history[player.index] == event.tick then
        return
      end
    end

    for _, player in pairs(force.connected_players) do
      if player.surface == entity.surface then
        on_built_entity(entity, player, player.index)
      end
    end
  end,
  {{ filter = "type", type = "item-request-proxy" }}
)

-- Item request proxies don't get populated until after the trigger effect is raised, so deal with them in on_tick
script.on_event(defines.events.on_script_trigger_effect, function(event)
  if event.effect_id == "gw-irp-created" then
    local entity = event.target_entity
    local player = event.source_entity.proxy_target.last_user
    if not player then return end
    local player_index = player.index
    table.insert(storage.irp_to_process, {entity = entity, player = player, player_index = player_index})
  end
end)

script.on_event(defines.events.on_tick, function(event)
  for _, irp_data in pairs(storage.irp_to_process) do
    if irp_data.entity.valid then
      -- If IRP is created by manual placing of ghost item in container from remote view, then IRP will be invalid here,
      -- even though there is _a_ IRP that is requesting the items. TODO report bug?
      on_built_entity(irp_data.entity, irp_data.player, irp_data.player_index)
    end
  end
  storage.irp_to_process = {}
end)

script.on_event({"gw-build", "gw-build-ghost", "gw-build-with-obstacle-avoidance", "gw-select-for-blueprint", "gw-reverse-select", "gw-select-for-cancel-deconstruct"},
  function(event)
    local player_history = get_warning_history(event.player_index)
    player_history.since_last_click = {}
  end
)

--[[
-- TODO 2.0 not used
local function setup_mis_event()
  if remote.interfaces["ModuleInserterSimplified"] then
    local on_module_inserted = remote.call("ModuleInserterSimplified", "get_events").on_module_inserted
    script.on_event(on_module_inserted,
      function(event)
        -- {modules = {[module] = count}, player = player, entity = entity}
        local player_index = event.player.index
        storage.script_raised_built_history[player_index] = event.tick
        on_built_entity(event.entity, event.player, player_index, event.modules)
      end
    )
  end
end
]]

local function init_storage()
  -- Reset all history in on_configuration_changed
  storage.warning_history = {}
  storage.sound_history = {}
  storage.script_raised_built_history = {}
  storage.irp_to_process = {}
end
script.on_init(
  function()
    init_storage()
    --setup_mis_event()
  end
)
script.on_configuration_changed(init_storage)
--script.on_load(setup_mis_event)