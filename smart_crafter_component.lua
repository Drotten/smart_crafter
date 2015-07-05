local SmartCrafterComponent = class()

function SmartCrafterComponent:initialize()
end

function SmartCrafterComponent:add_order(recipe, condition, player_id)
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
end

--! Checks to see if we're missing some ingredients from the inventory, from _needed_.
--! Also returns the uri for the last found required ingredient.
function SmartCrafterComponent:_get_uri_and_amount_missing(material, needed, inv)

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
function SmartCrafterComponent:_get_recipe(ingredient_uri, crafter)
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
function SmartCrafterComponent:_get_other_crafters(pop)
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
function SmartCrafterComponent:_add_new_order(new_recipe, condition, player_id, ingredient, missing, crafter)
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

return SmartCrafterComponent