local CrafterInfoController = class()

local log = radiant.log.create_logger('crafter_info')


function CrafterInfoController:initialize()
   self._sv.crafters = {}
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
      log:debug('formatting recipe %s', radiant.util.table_tostring(recipe))
      local formatted_recipe = radiant.shallow_copy(recipe)

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

      --TODO: add extra information to each ingredient in the recipe
      local formatted_ingredients = {}
      for _,ingredient in pairs(recipe.ingredients) do
         local formatted_ingredient = {}

         if ingredient.material then
            formatted_ingredient.kind = 'material'
            formatted_ingredient.material = ingredient.material
            formatted_ingredient.identifier = ingredient.material
         else
            formatted_ingredient.kind = 'uri'
            formatted_ingredient.uri = ingredient.uri
            formatted_ingredient.identifier = ''
         end

         formatted_ingredient.count = ingredient.count
         formatted_ingredient.name = ''
         formatted_ingredient.icon = ''

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

function CrafterInfoController:get_crafters()
   return self._sv.crafters
end

function CrafterInfoController:get_order_list(crafter_uri)
   return self._sv.crafters[crafter_uri].order_list
end

function CrafterInfoController:get_recipe_list(crafter_uri)
   return self._sv.crafters[crafter_uri].recipe_list
end


return CrafterInfoController
