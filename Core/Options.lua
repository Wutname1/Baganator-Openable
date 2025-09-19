local addonName, root = ... --[[@type string, table]]
local addon = root.Core
local Log = root.Log

-- AceOptions Configuration
local function GetOptions()
	return {
		name = "Lib's - Item Highlighter",
		type = 'group',
		args = {
			bagSystemHeader = {
				type = 'header',
				name = 'General Settings',
				order = 5
			},
			bagSystemSelect = {
				type = 'select',
				name = 'Bag System',
				desc = 'Choose which bag addon to integrate with',
				values = {
					auto = 'Auto-detect',
					baganator = 'Baganator',
					bagnon = 'Bagnon',
					betterbags = 'BetterBags',
					elvui = 'ElvUI',
					blizzard = 'Blizzard Default',
					adibags = 'AdiBags'
				},
				get = function()
					return addon.DB.BagSystem
				end,
				set = function(_, value)
					addon.DB.BagSystem = value
					-- Refresh the bag system
					addon:OnDisable()
					addon:OnEnable()
				end,
				order = 6
			},
			showGlow = {
				type = 'toggle',
				name = 'Show Glow Animation',
				desc = 'Display animated blue-to-green glow effect on openable items',
				get = function()
					return addon.DB.ShowGlow
				end,
				set = function(_, value)
					addon.DB.ShowGlow = value
					-- Refresh all widgets when glow is toggled
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 10
			},
			showIndicator = {
				type = 'toggle',
				name = 'Show Indicator Icon',
				desc = 'Display static treasure map icon on openable items',
				get = function()
					return addon.DB.ShowIndicator
				end,
				set = function(_, value)
					addon.DB.ShowIndicator = value
					-- Refresh all widgets when indicator is toggled
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 11
			},
			filterHeader = {
				type = 'header',
				name = 'Item Type Filters',
				order = 20
			},
			filterDesc = {
				type = 'description',
				name = 'Choose which types of openable items to highlight:',
				order = 21
			},
			filterToys = {
				type = 'toggle',
				name = 'Toys',
				desc = 'Highlight toy items that can be learned',
				get = function()
					return addon.DB.FilterToys
				end,
				set = function(_, value)
					addon.DB.FilterToys = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 30
			},
			filterAppearance = {
				type = 'toggle',
				name = 'Appearances',
				desc = 'Highlight items that teach appearances/transmog',
				get = function()
					return addon.DB.FilterAppearance
				end,
				set = function(_, value)
					addon.DB.FilterAppearance = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 31
			},
			filterMounts = {
				type = 'toggle',
				name = 'Mounts',
				desc = 'Highlight mount teaching items',
				get = function()
					return addon.DB.FilterMounts
				end,
				set = function(_, value)
					addon.DB.FilterMounts = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 32
			},
			filterCompanion = {
				type = 'toggle',
				name = 'Companions/Pets',
				desc = 'Highlight companion and pet items',
				get = function()
					return addon.DB.FilterCompanion
				end,
				set = function(_, value)
					addon.DB.FilterCompanion = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 33
			},
			filterRepGain = {
				type = 'toggle',
				name = 'Reputation Items',
				desc = 'Highlight items that give reputation',
				get = function()
					return addon.DB.FilterRepGain
				end,
				set = function(_, value)
					addon.DB.FilterRepGain = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 34
			},
			filterCurios = {
				type = 'toggle',
				name = 'Curios',
				desc = 'Highlight curio items',
				get = function()
					return addon.DB.FilterCurios
				end,
				set = function(_, value)
					addon.DB.FilterCurios = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 35
			},
			filterContainers = {
				type = 'toggle',
				name = 'Containers',
				desc = "Highlight containers with 'Right click to open' text (caches, chests, etc.)",
				get = function()
					return addon.DB.FilterContainers
				end,
				set = function(_, value)
					addon.DB.FilterContainers = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 36
			},
			filterKnowledge = {
				type = 'toggle',
				name = 'Knowledge Items',
				desc = 'Highlight knowledge/profession learning items',
				get = function()
					return addon.DB.FilterKnowledge
				end,
				set = function(_, value)
					addon.DB.FilterKnowledge = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 37
			},
			filterCreatable = {
				type = 'toggle',
				name = 'Creatable Items',
				desc = 'Highlight items that create class-specific gear',
				get = function()
					return addon.DB.CreatableItem
				end,
				set = function(_, value)
					addon.DB.CreatableItem = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 38
			},
			filterGeneric = {
				type = 'toggle',
				name = 'Generic Use Items',
				desc = "Highlight generic 'Use:' items (may be noisy)",
				get = function()
					return addon.DB.FilterGenericUse
				end,
				set = function(_, value)
					addon.DB.FilterGenericUse = value
					-- Reset cache since filter criteria changed
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 39
			},
			cacheHeader = {
				type = 'header',
				name = 'Cache Management',
				order = 40
			},
			resetCache = {
				type = 'execute',
				name = 'Reset Item Cache',
				desc = 'Clear all cached item openability data. Use this if items are incorrectly cached.',
				func = function()
					local openableCount = 0
					local notOpenableCount = 0

					-- Count items before clearing
					for _ in pairs(addon.GlobalDB.itemCache.openable) do
						openableCount = openableCount + 1
					end
					for _ in pairs(addon.GlobalDB.itemCache.notOpenable) do
						notOpenableCount = notOpenableCount + 1
					end

					-- Clear cache
					addon.GlobalDB.itemCache.openable = {}
					addon.GlobalDB.itemCache.notOpenable = {}

					Log('Cache reset: cleared ' .. openableCount .. ' openable items and ' .. notOpenableCount .. ' not openable items')
					print("Lib's - Item Highlighter: Cache reset - cleared " .. (openableCount + notOpenableCount) .. ' cached items')

					-- Refresh widgets to re-evaluate items
					local bagSystem = addon:GetActiveBagSystem()
					if bagSystem and bagSystem.RefreshAllCornerWidgets then
						bagSystem.RefreshAllCornerWidgets()
					end
				end,
				order = 41
			},
			animationHeader = {
				type = 'header',
				name = 'Animation Settings',
				order = 50
			},
			animationGroup = {
				type = 'group',
				name = 'Animation Timing',
				inline = true,
				order = 51,
				args = {
					cycleTime = {
						type = 'range',
						name = 'Cycle Time',
						desc = 'Time to fade from one color to another (seconds)',
						min = 0.1,
						max = 6.0,
						step = 0.05,
						get = function()
							return addon.DB.AnimationCycleTime
						end,
						set = function(_, value)
							addon.DB.AnimationCycleTime = value
						end,
						order = 1
					},
					betweenCycles = {
						type = 'range',
						name = 'Pause Between Cycles',
						desc = 'Time to pause at each color (seconds)',
						min = 0.1,
						max = 6.0,
						step = 0.05,
						get = function()
							return addon.DB.TimeBetweenCycles
						end,
						set = function(_, value)
							addon.DB.TimeBetweenCycles = value
						end,
						order = 2
					},
					updateInterval = {
						type = 'range',
						name = 'Update Interval',
						desc = 'How often to update the animation (seconds) - lower = smoother',
						min = 0.1,
						max = 6.0,
						step = 0.05,
						get = function()
							return addon.DB.AnimationUpdateInterval
						end,
						set = function(_, value)
							addon.DB.AnimationUpdateInterval = value
						end,
						order = 3
					}
				}
			}
		}
	}
end

function addon:SetupOptions()
	LibStub('AceConfig-3.0'):RegisterOptionsTable('LibsItemHighlighter', GetOptions)
	LibStub('AceConfigDialog-3.0'):AddToBlizOptions('LibsItemHighlighter', "Lib's - Item Highlighter")
	Log('Options panel registered with Blizzard Interface')
end
