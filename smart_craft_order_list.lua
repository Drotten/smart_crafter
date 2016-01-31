local CraftOrderList = radiant.mods.require('stonehearth.components.workshop.craft_order_list')
local SmartCraftOrderList = class()

local log = radiant.log.create_logger('craft_order_list')

SmartCraftOrderList._sc_old_add_order = CraftOrderList.add_order
function SmartCraftOrderList:add_order(session, response, recipe, condition, is_recursive_call)
   local player_id = session.player_id
   local inv = stonehearth.inventory:get_inventory(player_id)
   local crafters
   -- Process the recipe's ingredients to see if the crafter has all she needs for it.
   for _,ingredient in pairs(recipe.ingredients) do
      log:debug('processing ingredient "%s"', ingredient.material or ingredient.uri)

      -- Step 1: `Make`:
      --         See if there are enough of the asked ingredient in the inventory:
      --            if there is, continue to the next ingredient;
      --            if missing, go to step 2.
      --
      --         `Maintain`:
      --         Simply get how much the ingredient asks for and set it as missing,
      --         go to step 2.

      local missing
      if condition.type == 'make' then
         local needed = condition.amount * ingredient.count
         local amount = self:_sc_get_ingredient_amount(ingredient, inv)
         missing = needed - amount
         log:debug('need %d, has %d in inventory which leaves %d missing units to make (if able)', needed, amount, missing)
      else -- condition.type == 'maintain'
         missing = ingredient.count
         log:debug('maintaining the recipe requires %d of this ingredient, searching if it can be crafted itself', missing)
      end

      if missing > 0 then

         -- Step 2: Check if the ingredient can be produced through a different recipe:
         --            if it does, proceed to step 3;
         --            if not, continue on to the next ingredient.

         local recipe_info = self:_sc_get_recipe_info_from_ingredient(ingredient, player_id)
         if recipe_info then
            log:debug('a "%s" can be made via the recipe "%s"', ingredient.uri or ingredient.material, recipe_info.recipe.recipe_name)

            -- Step 3: Recursively check on the ingredient's recipe.

            local new_condition = { type = condition.type }
            if condition.type == 'make' then
               new_condition.amount = missing
            else -- condition.type == 'maintain'
               new_condition.at_least = missing
            end

            log:debug('adding the recipe "%s" for a %s to %s %d of those',
               recipe_info.recipe.recipe_name, recipe_info.crafter, new_condition.type, missing)

            -- Add the new order to the appropiate order list
            recipe_info.order_list:add_order(session, response, recipe_info.recipe, new_condition, true)
         end
      end
   end

   if condition.type == 'maintain' then
      -- See if the order_list already contains a maintain order for the recipe:
      --    if it does, remake the order if its amount is lower than `missing`, otherwise ignore it;
      --    if it doesn't, simply add it as usual.
      local order = self:_sc_find_craft_order(recipe.recipe_name, 'maintain')
      if order then
         log:debug('checking if maintain order "%s" is to be replaced', order:get_recipe().recipe_name)
         log:detail('this is %sa recursive call, the order\'s value is %d and the new one is %d',
            is_recursive_call and 'NOT ' or '',
            order:get_condition().at_least,
            condition.at_least)

         if not is_recursive_call or order:get_condition().at_least < tonumber(condition.at_least) then
            self:remove_order(order)
         else
            return true
         end
      end
   end

   return self:_sc_old_add_order(session, response, recipe, condition)
end

function SmartCraftOrderList:_sc_get_recipe_info_from_ingredient(ingredient, player_id)
   local crafter_info = smart_crafter.crafter_info:get_crafter_info(player_id)
   local item = ingredient.uri or ingredient.material

   for crafter_uri, crafter in pairs(crafter_info:get_crafters()) do
      for _,recipe in pairs(crafter.recipe_list) do
         if ingredient.material then
            local recipe_material_comp = recipe.product_info.components["stonehearth:material"]

            log:detail('Checking on a match between material "%s" and product "%s" with its material tags "%s"',
               item,
               recipe.product_info.components.unit_info.display_name,
               recipe_material_comp and recipe_material_comp.tags or '-no materials-')

            -- Look within the recipe's material tags for a match against `item`
            if recipe_material_comp and self:_sc_tags_match(item, recipe_material_comp.tags) then
               return
                  {
                     crafter    = crafter_uri,
                     order_list = crafter.order_list,
                     recipe     = recipe,
                  }
            end
         else
            for _,product in pairs(recipe.produces) do

               log:detail('Checking on a match between item "%s" and product "%s"', item, product.item)
               -- `item` is a uri, so we can simply search for a direct match against their aliases.
               if product.item == item then
                  return
                     {
                        crafter    = crafter_uri,
                        order_list = crafter.order_list,
                        recipe     = recipe,
                     }
               end
            end
         end
      end
   end

   return nil
end

function SmartCraftOrderList:_sc_get_ingredient_amount(ingredient, inv)
   local usable_item_tracker = inv:get_item_tracker('stonehearth:usable_item_tracker')
   local tracking_data = usable_item_tracker:get_tracking_data()
   local ingredient_count = 0

   if ingredient.uri then
      local data = radiant.entities.get_component_data(ingredient.uri , 'stonehearth:entity_forms')
      local lookup_key = ingredient.uri
      if data and data.iconic_form then
         lookup_key = data.iconic_form
      end

      local tracking_data_for_key = tracking_data:get(lookup_key)
      if tracking_data_for_key then
         ingredient_count = tracking_data_for_key.count
      end
   elseif ingredient.material then
      for _,data in tracking_data:each() do
         if radiant.entities.is_material(data.first_item, ingredient.material) then
            ingredient_count = ingredient_count + data.count
         end
      end
   end

   return ingredient_count
end

function SmartCraftOrderList:_sc_tags_match(tags_string1, tags_string2)
   for tag in tags_string1:gmatch("([^ ]*)") do
      -- gmatch will return either 1 tag or the empty string.
      -- make sure we skip over the empty strings!
      if tag ~= '' and not string.find(tags_string2, tag) then
         return false
      end
   end
   return true
end

-- Gets the craft order which matches `recipe_name`, optionally
-- also matches it to `order_type`.
-- Returns nil if none was found.
--
function SmartCraftOrderList:_sc_find_craft_order(recipe_name, order_type)
   log:debug('finding a recipe for "%s"', recipe_name)
   log:debug('There are %d orders', radiant.size(self._sv.orders)-1)

   for _,order in pairs(self._sv.orders) do
      if type(order) ~= 'number' then
         local order_recipe_name = order:get_recipe().recipe_name
         log:debug('evaluating order with recipe "%s"', order_recipe_name)

         if order_recipe_name == recipe_name and (not order_type or order:get_condition().type == order_type) then
            return order
         end
      end
   end

   return nil
end

return SmartCraftOrderList
