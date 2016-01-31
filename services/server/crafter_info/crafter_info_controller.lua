local CrafterInfoController = class()

local log = radiant.log.create_logger('crafter_info')

function CrafterInfoController:initialize()
   self._sv.crafters = {}
   self._sv.reserved_ingredients = {}
end

function CrafterInfoController:create(player_id)
   local pop = stonehearth.population:get_population(player_id)
   local job_index = radiant.resources.load_json( pop:get_job_index() )

   for _,job in pairs(job_index.jobs) do
      local job_info = stonehearth.job:get_job_info(player_id, job.description)
      -- If `job_info` contains a recipe list, then `job` is a crafter.
      local recipe_list = job_info:get_recipe_list()
      if recipe_list then
         self._sv.crafters[job.description] =
            {
               order_list  = job_info:get_order_list(),
               recipe_list = self:_format_recipe_list(recipe_list),
            }
      end
   end
end

function CrafterInfoController:_format_recipe_list(recipe_list)
   local function format_recipe(recipe)
      -- Format recipe to match show_team_workshop.js:_buildRecipeArray().
      local formatted_recipe = radiant.shallow_copy(recipe)

      -- Add information pertaining the workshop.
      local workshop_uri = recipe.workshop
      formatted_recipe.hasWorkshop = workshop_uri ~= nil
      if formatted_recipe.hasWorkshop then
         local workshop_data = radiant.resources.load_json(workshop_uri)
         formatted_recipe.workshop =
            {
               name = workshop_data.components.unit_info.display_name,
               icon = workshop_data.components.unit_info.icon,
               uri  = workshop_uri,
            }
      end

      -- Add extra information to each ingredient in the recipe.
      local formatted_ingredients = {}
      for _,ingredient in pairs(recipe.ingredients) do
         local formatted_ingredient = {}

         if ingredient.material then
            local constants = radiant.resources.load_json('/stonehearth/ui/data/constants.json')

            formatted_ingredient.kind       = 'material'
            formatted_ingredient.material   = ingredient.material
            formatted_ingredient.identifier = self:_sort_material(ingredient.material)
            local resource = constants.formatting.resources[ingredient.material]
            if resource then
               formatted_ingredient.name = resource.name
               formatted_ingredient.icon = resource.icon
            end
         else
            local ingredient_data = radiant.resources.load_json(ingredient.uri)

            formatted_ingredient.kind       = 'uri'
            formatted_ingredient.identifier = ingredient.uri

            if ingredient_data.components then
               formatted_ingredient.name = ingredient_data.components.unit_info.display_name
               formatted_ingredient.icon = ingredient_data.components.unit_info.icon
               formatted_ingredient.uri  = ingredient.uri

               if ingredient_data.components['stonehearth:entity_forms'] and ingredient_data.components['stonehearth:entity_forms'].iconic_form then
                  formatted_ingredient.identifier = ingredient_data.components['stonehearth:entity_forms'].iconic_form
               end
            end
         end

         formatted_ingredient.count = ingredient.count

         table.insert(formatted_ingredients, formatted_ingredient)
      end
      formatted_recipe.ingredients = formatted_ingredients

      return formatted_recipe
   end

   local formatted_recipe_list = {}
   for category_name, category_data in pairs(recipe_list) do
      for recipe_name, recipe_data in pairs(category_data.recipes) do
         table.insert(formatted_recipe_list, format_recipe(recipe_data.recipe))
      end
   end

   return formatted_recipe_list
end

function CrafterInfoController:_sort_material(material)
   local tags = radiant.util.split_string(material, ' ')
   table.sort(tags)

   return table.concat(tags, ' ')
end

function CrafterInfoController:get_crafters()
   return self._sv.crafters
end

function CrafterInfoController:get_order_list(crafter_uri)
   return self._sv.crafters[crafter_uri].order_list
end

function CrafterInfoController:get_recipe_list(crafter_uri)
   return self._sv.crafters[crafter_uri].recipe_list
end

function CrafterInfoController:get_reserved_ingredients(ingredient_type)
   if not self._sv.reserved_ingredients[ingredient_type] then
      return 0
   end

   return self._sv.reserved_ingredients[ingredient_type]
end

function CrafterInfoController:add_to_reserved_ingredients(ingredient_type, amount)
   if not self._sv.reserved_ingredients[ingredient_type] then
      self._sv.reserved_ingredients[ingredient_type] = amount
      return
   end

   log:detail('adding %d of "%s" to the reserved list', amount, ingredient_type)

   self._sv.reserved_ingredients[ingredient_type] = self._sv.reserved_ingredients[ingredient_type] + amount
end

function CrafterInfoController:remove_from_reserved_ingredients(ingredient_type, amount)
   if not self._sv.reserved_ingredients[ingredient_type] then
      return
   end

   log:detail('removing %d of "%s" from the reserved list', amount, ingredient_type)

   self._sv.reserved_ingredients[ingredient_type] = self._sv.reserved_ingredients[ingredient_type] - amount
   if self._sv.reserved_ingredients[ingredient_type] == 0 then
      self._sv.reserved_ingredients[ingredient_type] = nil
   end
end

return CrafterInfoController
