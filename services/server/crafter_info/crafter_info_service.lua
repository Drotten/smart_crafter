local CrafterInfoService = class()

function CrafterInfoService:initialize()
   self._crafter_infos = {}
   radiant.events.listen(_radiant, 'radiant:player_kingdom_changed', self, self._on_player_kingdom_changed)
end

function CrafterInfoService:_on_player_kingdom_changed(args)
   return self:add_crafter_info(args.player_id)
end

function CrafterInfoService:add_crafter_info(player_id)
   local crafter_info = radiant.create_controller('smart_crafter:crafter_info_controller', player_id)
   self._crafter_infos[player_id] = crafter_info
   return crafter_info
end

function CrafterInfoService:get_crafter_info(player_id)
   local crafter_info = self._crafter_infos[player_id]
   if not crafter_info then
      crafter_info = self:add_crafter_info(player_id)
   end
   return crafter_info
end

return CrafterInfoService
