smart_crafter = {}

local function monkey_crafter()
   local smart_craft_order_list = require('smart_craft_order_list')
   local craft_order_list = radiant.mods.require('stonehearth.components.workshop.craft_order_list')
   radiant.mixin(craft_order_list, smart_craft_order_list)


   local smart_craft_order = require('smart_craft_order')
   local craft_order = radiant.mods.require('stonehearth.components.workshop.craft_order')
   radiant.mixin(craft_order, smart_craft_order)


   local job_info_controller = radiant.mods.require('stonehearth.services.server.job.job_info_controller')
   job_info_controller.get_recipe_list = function(self)
      return self._sv.recipe_list
   end
end

local function create_service(name)
   local path = string.format('services.server.%s.%s_service', name, name)
   local service = require(path)()

   local saved_variables = smart_crafter._sv[name]
   if not saved_variables then
      saved_variables = radiant.create_datastore()
      smart_crafter._sv[name] = saved_variables
   end

   service.__saved_variables = saved_variables
   service._sv = saved_variables:get_data()
   saved_variables:set_controller(service)
   service:initialize()
   smart_crafter[name] = service
end

function smart_crafter:_on_required_loaded()
   smart_crafter._sv = smart_crafter.__saved_variables:get_data()

   monkey_crafter()

   create_service('crafter_info')
end

radiant.events.listen_once(radiant, 'radiant:required_loaded', smart_crafter, smart_crafter._on_required_loaded)

return smart_crafter
