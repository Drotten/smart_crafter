--[[--
   All code present, except those within the comments <SC START> and <SC END>, are made by Team Radiant and the respective copyrights resides with them.

   The point in this to have the crafter skip recipes if there aren't enough ingredients.
   Probably need a marker for each recipe, saying which have been skipped or not,
   and then, maybe, listen to a trigger for when an item is added to the inventory.
   If the right kind of resource is added for this recipe, AND it's the last required ingredient,
   start crafting the item. (prehaps add a different way of detecting when new items arrive...)
--]]--

local IngredientList = require('components.workshop.ingredient_list')
local CraftOrder = class()

function CraftOrder:initialize(id, recipe, condition, player_id, order_list)
   assert(self._sv)
   self._sv.id = id
   self._sv.recipe = recipe
   self._sv.portrait = recipe.portrait
   self._sv.condition = condition
   self._sv.enabled = true
   self._sv.is_crafting = false
   self._sv.order_list = order_list
   self._sv.player_id = player_id
   local condition = self._sv.condition

   if condition.type == "make" then
      condition.amount = tonumber(condition.amount)
      condition.remaining = condition.amount
   elseif condition.type == "maintain" then
      condition.at_least = tonumber(condition.at_least)
   end
   self:_on_changed()
end

function CraftOrder:_on_changed()
   self.__saved_variables:mark_changed()
   self._sv.order_list:_on_order_list_changed()
end

function CraftOrder:destroy()
   self:_on_changed()
end

function CraftOrder:get_id()
   return self._sv.id
end

function CraftOrder:get_recipe()
   return self._sv.recipe
end

function CraftOrder:get_enabled()
   return self._sv.enabled
end

function CraftOrder:toggle_enabled()
   self._sv.enabled = not self._sv.enabled
   self:_on_changed()
end

function CraftOrder:get_condition()
   return self._sv.condition
end

function CraftOrder:set_crafting_status(status)
   if status ~= self._sv.is_crafting then
      self._sv.is_crafting = status
      self:_on_changed()
   end
end

function CraftOrder:should_execute_order()
   local condition = self._sv.condition
   if condition.type == "make" then
      ------------------------------------------------------------------------
      --<SC START>
      ------------------------------------------------------------------------
      return condition.remaining > 0 and self:_have_resources()
      ------------------------------------------------------------------------
      --<SC END>
      ------------------------------------------------------------------------

   elseif condition.type == "maintain" then
      if condition.at_least == 0 then
         return false
      end
      local crafter = self._sv.order_list:get_workshop():get_component('stonehearth:workshop'):get_crafter()
      if not crafter:get_component('stonehearth:crafter'):should_maintain() then
         return false
      end

      local we_have = 0
      local uri = self._sv.recipe.produces[1].item
      local data = radiant.entities.get_component_data(uri, 'stonehearth:entity_forms')
      if data and data.iconic_form then
         uri = data.iconic_form
      end

      local inventory = stonehearth.inventory:get_inventory(self._sv.player_id)
      local data = inventory:get_items_of_type(uri)

      if data and data.items then
         for _,item in pairs(data.items) do
            if radiant.entities.get_world_grid_location(item) then
               we_have = we_have + 1
               if we_have >= condition.at_least then
                  return false
               end
            end
         end
      end

      ------------------------------------------------------------------------
      --<SC START>
      ------------------------------------------------------------------------
      return self:_have_resources()
      ------------------------------------------------------------------------
      --<SC END>
      ------------------------------------------------------------------------
   end
end

------------------------------------------------------------------------
--<SC START>
------------------------------------------------------------------------
function CraftOrder:_have_resources()
   --[[
      TODO:
      check if there are enough resources available to craft this
   --]]

   return true
end
------------------------------------------------------------------------
--<SC END>
------------------------------------------------------------------------

function CraftOrder:on_item_created()
   local condition = self._sv.condition
   if condition.type == "make" then
      condition.remaining = condition.remaining - 1
      self:_on_changed()
   end
end

function CraftOrder:is_complete()
   local condition = self._sv.condition
   if condition.type == "make" then
      return condition.remaining == 0
   elseif condition.type == "maintain" then
      return false
   end
end

return CraftOrder