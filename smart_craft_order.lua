local CraftOrder = radiant.mods.require('stonehearth.components.workshop.craft_order')
local SmartCraftOrder = class()

SmartCraftOrder._sc_old_on_item_created = CraftOrder.on_item_created
-- In addition to the original on_item_created function (from craft_order.lua),
-- here it's also removing the ingredients tied to the order made from
-- the reserved ingredients.
--
function SmartCraftOrder:on_item_created()
   if self._sv.condition.type == 'make' then
      local crafter_info = smart_crafter.crafter_info:get_crafter_info(self._sv.player_id)
      for _,ingredient in pairs(self._recipe.ingredients) do
         local in_order_list = self._sv.order_list:sc_get_ingredient_amount_in_order_list(ingredient)
         local ingredient_type = ingredient.uri or ingredient.material
         local amount = ingredient.count - in_order_list.maintain

         crafter_info:remove_from_reserved_ingredients(ingredient_type, amount)
      end
   end

   self:_sc_old_on_item_created()
end

return SmartCraftOrder
