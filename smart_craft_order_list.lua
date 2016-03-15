local CraftOrderList = radiant.mods.require('stonehearth.components.workshop.craft_order_list')
local SmartCraftOrderList = class()

local log = radiant.log.create_logger('craft_order_list')

SmartCraftOrderList._sc_old_add_order = CraftOrderList.add_order
-- In addition to the original add_order function (from craft_order_list.lua),
-- here it's also checking if the order has enough of the required ingredients and,
-- if it can be crafted, adds those ingredients as orders as well.
--
-- Furthermore, when maintaining orders, it makes sure that there are no more than
-- one instance of each recipe that's maintained.
--
function SmartCraftOrderList:add_order(player_id, recipe, condition, is_recursive_call)
   local inv = stonehearth.inventory:get_inventory(player_id)
   local crafter_info = smart_crafter.crafter_info:get_crafter_info(player_id)

   -- Process the recipe's ingredients to see if the crafter has all she needs for it.
   for _,ingredient in pairs(recipe.ingredients) do
      local ingredient_type = ingredient.uri or ingredient.material

      log:debug('processing ingredient "%s"', ingredient_type)

      -- Step 1: `make`:
      --         See if there are enough of the asked ingredient in the inventory:
      --            if there is, continue to the next ingredient;
      --            if missing, go to step 2.
      --
      --         `maintain`:
      --         Simply get how much the ingredient asks for and set it as missing,
      --         go to step 2.

      local missing
      if condition.type == 'make' then
         local needed = condition.amount * ingredient.count
         local in_storage = self:_sc_get_ingredient_amount_in_storage(ingredient, inv)
         local in_order_list = self:sc_get_ingredient_amount_in_order_list(ingredient)
         missing = math.max(needed - math.max(in_storage + in_order_list.total - crafter_info:get_reserved_ingredients(ingredient_type), 0), 0)

         log:debug('we need %d, have %d in storage, have %d in order list (%d of which are maintained), and %d reserved which means we are missing %d (math is hard, right?)',
            needed, in_storage, in_order_list.total, in_order_list.maintain, crafter_info:get_reserved_ingredients(ingredient_type), missing)

         crafter_info:add_to_reserved_ingredients(ingredient_type, math.max(needed - in_order_list.maintain, 0))
      else -- condition.type == 'maintain'
         missing = ingredient.count

         log:debug('maintaining the recipe requires %d of this ingredient, searching if it can be crafted itself', missing)
      end

      if missing > 0 then

         -- Step 2: Check if the ingredient can be produced through a different recipe:
         --            if it does, proceed to step 3;
         --            if not, continue on to the next ingredient.

         local recipe_info = self:_sc_get_recipe_info_from_ingredient(ingredient, crafter_info)
         if recipe_info then
            log:debug('a "%s" can be made via the recipe "%s"', ingredient_type, recipe_info.recipe.recipe_name)

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
            recipe_info.order_list:add_order(player_id, recipe_info.recipe, new_condition, true)
         end
      end
   end

   local old_order_index
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
            -- The order is to be replaced, so remove the current one so when the new one is added;
            -- there are no duplicates of the same recipe.

            log:debug('replacing the order with %d as its new amount', condition.at_least)

            -- Note: It would be preferable to change the order's `at_least` value directly instead, but
            --       I haven't found a way to accomplish that *and* have the ui update itself instantly.

            old_order_index = self:find_index_of(order:get_id())
            self:remove_order(order)
         else
            log:debug('an order already exists that fulfills what is asked of')
            return true
         end
      end
   end

   local result = self:_sc_old_add_order(player_id, recipe, condition)

   if old_order_index then
      -- Change the order of the recipe to what its predecessor had.

      -- Note: We could call the function `change_order_position` for this one,
      --       but it uses an order's id to find its index in the table. And since
      --       we know that the newly created order is in the last index; it seems
      --       like a waste of resources to just do that sort of operation. So
      --       we just copy that function's body here with that change in mind.

      local new_order_index = radiant.size(self._sv.orders) - 1
      local order = self._sv.orders[new_order_index]
      table.remove(self._sv.orders, new_order_index)
      table.insert(self._sv.orders, old_order_index, order)

      self:_on_order_list_changed()
   end

   return result
end

SmartCraftOrderList._sc_old_delete_order_command = CraftOrderList.delete_order_command
-- In addition to the original delete_order_command function (from craft_order_list.lua),
-- here it's also making sure that the ingredients needed for the order is removed
-- from the reserved ingredients table.
--
function SmartCraftOrderList:delete_order_command(session, response, order_id)
   local order = self._sv.orders[ self:find_index_of(order_id) ]
   local condition = order:get_condition()

   if condition.type == 'make' and condition.remaining > 0 then
      self:remove_from_reserved_ingredients(order:get_recipe().ingredients, order_id, session.player_id, condition.remaining)
   end

   return self:_sc_old_delete_order_command(session, response, order_id)
end

-- All within `ingredients` are removed from the reserved ingredients table.
-- `order_id` is the id of the order that we are to remove of.
-- `player_id` says which player id the order belongs to.
-- `multiple` says by how much the ingredients' count will be multiplied by,
-- if it's not specified it will get the value of 1.
--
function SmartCraftOrderList:remove_from_reserved_ingredients(ingredients, order_id, player_id, multiple)
   multiple = multiple or 1
   local crafter_info = smart_crafter.crafter_info:get_crafter_info(player_id)
   for _,ingredient in pairs(ingredients) do
      local in_order_list = self:sc_get_ingredient_amount_in_order_list(ingredient, order_id)
      local ingredient_type = ingredient.uri or ingredient.material
      local amount = math.max(ingredient.count * multiple - in_order_list.maintain, 0)

      crafter_info:remove_from_reserved_ingredients(ingredient_type, amount)
   end
end

-- Used to get a recipe if it can be used to craft `ingredient`.
-- Information such as what kind of crafter is needed and its order list,
-- and, of course, the recipe itself.
--
function SmartCraftOrderList:_sc_get_recipe_info_from_ingredient(ingredient, crafter_info)
   local item = ingredient.uri or ingredient.material

   for crafter_uri, crafter in pairs(crafter_info:get_crafters()) do
      for _,recipe in pairs(crafter.recipe_list) do
         if ingredient.material then
            local recipe_material_comp = recipe.product_info.components["stonehearth:material"]

            log:spam('matching material "%s" and product "%s" with its material "%s"',
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

               log:spam('matching item "%s" and product "%s"', item, product.item)
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

-- Checks `inventory` to see how much of `ingredient` it contains.
--
function SmartCraftOrderList:_sc_get_ingredient_amount_in_storage(ingredient, inventory)
   local usable_item_tracker = inventory:get_item_tracker('stonehearth:usable_item_tracker')
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

-- Checks this order list to see how much of `ingredient` it contains.
-- The optional `to_order_id` says that any orders with their id,
-- that are at least of that number, will be ignored.
--
function SmartCraftOrderList:sc_get_ingredient_amount_in_order_list(ingredient, to_order_id)
   local ingredient_count =
      {
         total    = 0,
         make     = 0,
         maintain = 0,
      }

   for _,order in pairs(self._sv.orders) do
      if type(order) ~= 'number' then
         local recipe = order:get_recipe()
         local condition = order:get_condition()

         if (ingredient.material
         and recipe.product_info.components
         and recipe.product_info.components['stonehearth:material']
         and self:_sc_tags_match(ingredient.material, recipe.product_info.components['stonehearth:material'].tags))
         or (ingredient.uri
         and recipe.produces.item == ingredient.uri) then

            local amount = condition.remaining
            if condition.type == 'maintain' then
               amount = condition.at_least
            end
            if not to_order_id or order:get_id() < to_order_id then
               ingredient_count[condition.type] = ingredient_count[condition.type] + amount
            end

         end
      end
   end

   ingredient_count.total = ingredient_count.make + ingredient_count.maintain
   return ingredient_count
end

-- Checks to see if `tags_string1` is a sub-set of `tags_string2`.
-- Returns a boolean depending on the result.
--
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

-- Gets the craft order which matches `recipe_name`, if an `order_type`
-- is defined, then it will also check for a match against it.
-- Returns nil if no match was found.
--
function SmartCraftOrderList:_sc_find_craft_order(recipe_name, order_type)
   log:debug('finding a recipe for "%s"', recipe_name)
   log:debug('There are %d orders', radiant.size(self._sv.orders) - 1)

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
