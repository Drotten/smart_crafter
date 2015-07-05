--[[
-- Tried to make a component that every crafter gets in addition.
-- Problems:
-- * Need to find a way to check whenever an item is getting crafted.
-- * Has to find a way to make this component be a part of every crafter, even those that are modded into the game.

local SCComponent = class()
local CraftOrderList = require('components.workshop.craft_order_list')

function SCComponent:initialize(entity, json)
   self._entity = entity
   self._sv = self.__saved_variables:get_data()
   radiant.events.listen_once(radiant, 'radiant:game_loaded', function()
      if self._sv.crafter then
         --derp...
      end
   end)
end

return SCComponent
--]]




--[[
-- go through the entire inventory to try and find an ingredient from material
-- replaced by trying to find with tags from recipes, just keep this just in case...

local Rand = _radiant.csg.get_default_rng()
local mat_to_uri = radiant.resources.load_json('smart_crafter:mat_to_uri')


local tracker = inv:get_item_tracker('stonehearth:basic_inventory_tracker')
for track_uri,data in pairs(tracker._sv.tracking_data) do
   for i,entity in pairs(data.items) do

      --if radiant.entities.is_material(entity, material) then
      local mat_comp = entity:get_component('stonehearth:material')
      if mat_comp then
         for _,tag in pairs(material_tags) do
            if tag ~= 'resource' and mat_comp:has_tag(tag) then
               uri = track_uri
               missing = missing - 1
               if missing <= 0 then
                  break
               end
            end
         end
      end
   end

   if missing <= 0 then
      break
   end
end

-- If we still haven't got a uri, grab one form a premade list (this is just in case)
if uri == nil then
   if not mat_to_uri[ingredient.material] then
      assert(nil, tostring(ingredient.material))
   end
   uri = mat_to_uri[ingredient.material][Rand:get_int(1,#mat_to_uri[ingredient.material])]
   missing = ingredient.count
end
--]]