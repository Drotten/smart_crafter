local CrafterInfoService = class()

function CrafterInfoService:initialize()
   if not self._sv.crafter_infos then
      self._sv.crafter_infos = {}
   end
end

function CrafterInfoService:activate()
   self._kingdom_changed_listener = radiant.events.listen(_radiant, 'radiant:player_kingdom_changed',
                                                          self, self._on_player_kingdom_changed)
end

function CrafterInfoService:destroy()
   if self._kingdom_changed_listener then
      self._kingdom_changed_listener:destroy()
      self._kingdom_changed_listener = nil
   end
end

function CrafterInfoService:_on_player_kingdom_changed(args)
   return self:add_crafter_info(args.player_id)
end

function CrafterInfoService:add_crafter_info(player_id)
   local crafter_info = radiant.create_controller('smart_crafter:crafter_info_controller', player_id)
   self._sv.crafter_infos[player_id] = crafter_info
   self.__saved_variables:mark_changed()
   return crafter_info
end

function CrafterInfoService:get_crafter_info(player_id)
   local crafter_info = self._sv.crafter_infos[player_id]
   if not crafter_info then
      crafter_info = self:add_crafter_info(player_id)
   end
   return crafter_info
end

return CrafterInfoService
