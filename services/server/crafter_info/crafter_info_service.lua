local CrafterInfoService = class()

function CrafterInfoService:initialize()
   self._sv.crafter_infos = {}
end

function CrafterInfoService:get_crafter_info(player_id)
   local crafter_info = self._sv.crafter_infos[player_id]
   if not crafter_info then
      crafter_info = radiant.create_controller('smart_crafter:crafter_info_controller', player_id)
      self._sv.crafter_infos[player_id] = crafter_info
   end
   return crafter_info
end

return CrafterInfoService
