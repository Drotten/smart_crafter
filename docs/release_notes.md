### Version 1.1.7

- **Stability** - Added more error handling for recipe categories that contain no recipes.


### Version 1.1.6

- **Stability** - Added error handling so that invalid recipes won't break the mod outright.
- **Improvement** - If an ingredient has to be crafted, then crafters craft the cheapest one (instead of the first one they see).


### Version 1.1.5

- **Compatibility** - Updated to Stonehearth's Alpha 20 API.
- **Bug fix** - The mod now works without having to save and reload for each game.


### Version 1.1.4

- **Bug fix** - Now works properly for other factions that provide their own crafter jobs.


### Version 1.1.3a

- **Compatibility** - Updated to Stonehearth Alpha 18.
- **Bug fix** - Properly looks at other craft order lists when determining if an ingredient has to be crafted.


### Version 1.1.3

- **Performance** - It's now faster when finding recipes that produces an item needed for another recipe.
- **Performance** - The crafting recipes are now checked when game is launched instead of when the first order is placed.
- **Improvement** - Now works better for saved games.


### Version 1.1.2

- **Bug fix** - Material tags are now word-border matched.


### Version 1.1.1

- **Compatibility** - Updated mod to have it work for Stonehearth Alpha 15.


### Version 1.1

- **Compatibility** - Update mod to work for Stonehearth Alpha 14.
- **Feature** - Makes sure that any one recipe can't have more than one maintain order.
- **Feature** - Take into account what's available for the crafter, or if any resources are reserved for other purposes.


### Version 1.0.3.1

- **Compatibility** - Hotfix to make it work for release 240.


### Version 1.0.3

- **Bug fix** - The crafters now makes all the stuff even if you have everything in the inventory.


### Version 1.0.2

- **Bug fix** - Removed using of the mat_to_uri.json, replaced with a better way of finding stuff.
- **Feature remove** - Doesn't take account for what's already in inventory, since that caused confusion of its own.


### Version 1.0 (initial release)

- **Mechanic** - The crafter will begin on crafting necessary ingredients if missing.
- **Mechanic** - Crafters communicate to make sure everyone has what they need.
