--[[
This overrides craft_order_list by Team Radiant.
All code present, except those within the comments <SC START> and <SC END>, are made by Team Radiant and the rights to that code resides with them.
--]]

local CraftOrder = require('components.workshop.craft_order')
local CraftOrderList = class()

function CraftOrderList:initialize(workshop_entity)
   self._sv.orders = {n = 0,}
   self._sv.next_order_id = 0
   self._sv.is_paused = false
   self._sv.workshop_entity = workshop_entity
   self.__saved_variables:mark_changed()
end

function CraftOrderList:is_paused()
   return self._sv.is_paused
end

function CraftOrderList:toggle_pause()
   self._sv.is_paused = not self._sv.is_paused
   self:_on_order_list_changed()
end

function CraftOrderList:get_workshop()
   return self._sv.workshop_entity
end

function CraftOrderList:add_order(recipe, condition, player_id)

   ------------------------------------------------------------------------
   --<SC START>------------------------------------------------------------
   ------------------------------------------------------------------------

   local inv = stonehearth.inventory:get_inventory(player_id)
   local crafters
   -- Go through every ingredient that's needed
   for _,ingredient in pairs(recipe.ingredients) do

      local uri = ingredient.uri
      local missing = 0

      -- Get a fitting uri from ingredient.material, also how much of that material is missing from the inventory
      if not uri then
         uri, missing, crafters = self:_get_uri_and_amount_missing(ingredient.material, ingredient.count*(condition.amount or 1), inv)
      else
         local items = inv:get_items_of_type(uri)
         missing = (condition.amount or 1) * ingredient.count - ((items and items.count) or 0)
      end

      -- If there's a recipe for that uri, get it and add it to the list to be crafted
      local new_recipe = self:_get_recipe(uri)
      if new_recipe then
         self:_add_new_order(new_recipe, condition, player_id, ingredient, missing)

      -- Go through all the other craftsmen and see if they have a recipe of the ingredient
      else--if missing > 0 then
         crafters = crafters or self:_get_other_crafters(stonehearth.population:get_population(player_id))
         for _,crafter in pairs(crafters) do
            local new_recipe = self:_get_recipe(uri, crafter)
            if new_recipe then
               self:_add_new_order(new_recipe, condition, player_id, ingredient, missing, crafter)
               break
            end
         end
      end
   end

   ------------------------------------------------------------------------
   --<SC END>--------------------------------------------------------------
   ------------------------------------------------------------------------

   local order = radiant.create_controller('stonehearth:craft_order', self._sv.next_order_id, recipe, condition, player_id, self)
   self._sv.next_order_id = self._sv.next_order_id + 1
   table.insert(self._sv.orders, order)
   self:_on_order_list_changed()
end

------------------------------------------------------------------------
--<SC START>------------------------------------------------------------
------------------------------------------------------------------------

--! Checks to see if we're missing some ingredients from the inventory, from count.
--! Also returns the uri for the last found required ingredient.
function CraftOrderList:_get_uri_and_amount_missing(material, needed, inv)

   local material_tags = radiant.util.split_string(material)
   local uri
   local missing = needed
   local crafters

   local function find_mats(crafter, uri, missing)
      for cat,cat_data in pairs(crafter._sv.recipe_list) do

         for name,recipe in pairs(cat_data.recipes) do

            for _,prod in pairs(recipe.recipe.produces) do

               local material_comp = radiant.resources.load_json(prod.item).components['stonehearth:material']
               if material_comp then

                  local mat_comp_tags = radiant.util.split_string(material_comp.tags)
                  -- need to check if the material is a resource AND has one of the required tags
                  local is_resource, found_tag = false
                  for _,mat_comp_tag in pairs(mat_comp_tags) do

                     for _,material_tag in pairs(material_tags) do
                        if material_tag == mat_comp_tag then
                           if material_tag == 'resource' then
                              is_resource = true
                           else
                              found_tag = true
                           end
                        end
                        if is_resource and found_tag then
                           uri = prod.item
                           local items = inv:get_items_of_type(uri)
                           missing = missing - ((items and items.count) or 0)
                        end
                     end
                     if is_resource and found_tag then
                        break
                     end
                  end
               end
            end
         end
      end
      return uri, missing
   end

   uri, missing = find_mats(self:get_workshop():get_component('stonehearth:workshop'):get_crafter():get_component('stonehearth:crafter'), uri, missing)

   if missing > 0 then
      crafters = self:_get_other_crafters(stonehearth.population:get_population('player_1'))
      for _,crafter in pairs(crafters) do
         uri, missing = find_mats(crafter, uri, missing)
      end
   end

   return uri, missing, crafters
end

--! Checks whether or not the ingredient is an item crafted by a craftsman.
--! If there's a match then return the recipe.
function CraftOrderList:_get_recipe(ingredient_uri, crafter)
   if crafter and not crafter:get_workshop() then
      return nil
   end

   crafter = crafter or self:get_workshop():get_component('stonehearth:workshop'):get_crafter():get_component('stonehearth:crafter')
   -- get list of recipes for craftsmen
   for cat,cat_data in pairs(crafter._sv.recipe_list) do
      -- go through the list and compare each one to ingredient, return if there's a match
      for name,recipe in pairs(cat_data.recipes) do

         for index,prod in pairs(recipe.recipe.produces) do
            if prod.item == ingredient_uri then
               return recipe.recipe
            end
         end
      end
   end

   -- this ingredient can't be crafted (at least not by this craftsman)
   return nil
end

--! Gets a table of all the crafters except for the one that this craft_order_list is connected to.
function CraftOrderList:_get_other_crafters(pop)
   local crafters = {}
   local this_crafter = self:get_workshop():get_component('stonehearth:workshop'):get_crafter():get_component('stonehearth:crafter')

   for i,hearthling in pairs(pop:get_citizens()) do
      local crafter = hearthling:get_component('stonehearth:crafter')
      if crafter and crafter ~= this_crafter then
         table.insert(crafters, crafter)
      end
   end

   return crafters
end

--! Adds a new order to the list.
function CraftOrderList:_add_new_order(new_recipe, condition, player_id, ingredient, missing, crafter)
   local new_condition = {type = condition.type}
   local order_list = (crafter and crafter:get_workshop()._sv.order_list) or self

   if condition.type == 'make' then -- and missing > 0 then
      new_condition['amount'] = ingredient.count * condition.amount
      order_list:add_order(new_recipe, new_condition, player_id)

   elseif condition.type == 'maintain' then
      new_condition['at_least'] = ingredient.count
      order_list:add_order(new_recipe, new_condition, player_id)
   end
end

------------------------------------------------------------------------
--<SC END>--------------------------------------------------------------
------------------------------------------------------------------------

function CraftOrderList:get_next_order()
   for i,order in ipairs(self._sv.orders) do
      if order:should_execute_order() then
         return order
      end
   end
end

function CraftOrderList:change_order_position(new, id)
   local i = self:find_index_of(id)
   local order = self._sv.orders[i]
   table.remove(self._sv.orders, i)
   table.insert(self._sv.orders, new, order)
   self:_on_order_list_changed()
end

function CraftOrderList:remove_order(order)
   return self:remove_order_id(order:get_id())
end

function CraftOrderList:remove_order_id(order_id)
   local i = self:find_index_of(order_id)
   if i then
      local order = self._sv.orders[i]
      table.remove(self._sv.orders, i)
      order:destroy()
      self:_on_order_list_changed()
   end
end

function CraftOrderList:find_index_of(order_id)
   for i,order in ipairs(self._sv.orders) do
      if order:get_id() == order_id then
         return i
      end
   end
   return nil
end

function CraftOrderList:_on_order_list_changed()
   radiant.events.trigger(self, 'stonehearth:order_list_changed')
   self.__saved_variables:mark_changed()
end

return CraftOrderList