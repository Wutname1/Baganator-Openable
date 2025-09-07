local addonName, root = ... --[[@type string, table]]

-- Immediate startup logging
print('BaganatorOpenable: Addon file loaded, addonName=' .. tostring(addonName))

---@class BaganatorOpenable: AceAddon, AceTimer-3.0
local addon = LibStub('AceAddon-3.0'):NewAddon(addonName, 'AceEvent-3.0', 'AceTimer-3.0')

print('BaganatorOpenable: AceAddon created successfully')

-- Animation Constants
local ANIMATION_CYCLE_TIME = 2.5 -- Time to fade from one color to another
local TIME_BETWEEN_CYCLES = 1.0 -- Time to pause at each color
local ANIMATION_UPDATE_INTERVAL = 0.1 -- How often to update the animation (10 FPS)

---@class Profile
local profile = {
	CategoryColor = {r = 0.17, g = 0.93, b = 0.93, a = 1},
	FilterGenericUse = false,
	FilterToys = true,
	FilterAppearance = true,
	FilterMounts = true,
	FilterRepGain = true,
	FilterCompanion = true,
	FilterCurios = true,
	FilterKnowledge = true,
	FilterContainers = true,
	CreatableItem = true,
	ShowOpenableIndicator = true
}

--Get Locale
local Localized = {
	deDE = {
		['Use: Teaches you how to summon this mount'] = 'Benutzen: Lehrt Euch, dieses Reittier herbeizurufen',
		['Use: Collect the appearance'] = 'Benutzen: Sammelt das Aussehen',
		['reputation with'] = 'Ruf bei',
		['reputation towards'] = 'Ruf bei'
	},
	esES = {
		['Use: Teaches you how to summon this mount'] = 'Uso: Te enseña a invocar esta montura',
		['Use: Collect the appearance'] = 'Uso: Recoge la apariencia',
		['reputation with'] = 'reputación con',
		['reputation towards'] = 'reputación hacia'
	},
	frFR = {
		['Use: Teaches you how to summon this mount'] = 'Utilisation: Vous apprend à invoquer cette monture',
		['Use: Collect the appearance'] = "Utilisation: Collectionnez l'apparence",
		['reputation with'] = 'réputation auprès',
		['reputation towards'] = 'réputation envers'
	}
}

local Locale = GetLocale()
function GetLocaleString(key)
	if Localized[Locale] then
		return Localized[Locale][key]
	end
	return key
end

local REP_USE_TEXT = QUEST_REPUTATION_REWARD_TOOLTIP:match('%%d%s*(.-)%s*%%s') or GetLocaleString('reputation with')

-- Logging function
local function Log(msg, level)
	if SUI and SUI.Log then
		SUI.Log(tostring(msg), 'BaganatorOpenable', level or 'info')
	else
		print('BaganatorOpenable: ' .. tostring(msg))
	end
end

function RGBToHex(rgbTable)
	local r = math.floor(rgbTable.r * 255 + 0.5)
	local g = math.floor(rgbTable.g * 255 + 0.5)
	local b = math.floor(rgbTable.b * 255 + 0.5)
	return string.format('|cFF%02X%02X%02X', r, g, b)
end

local Tooltip = CreateFrame('GameTooltip', 'BaganatorOpenable', nil, 'GameTooltipTemplate')

local SearchItems = {
	'Open the container',
	'Use: Open',
	'Right Click to Open',
	'Right click to open',
	'<Right Click to Open>',
	'<Right click to open>',
	ITEM_OPENABLE
}

---Check if an item is openable/usable based on tooltip scanning
---@param itemDetails table Baganator item details
---@return boolean|nil isOpenable True if item is openable, false if not, nil if can't determine
local function CheckItem(itemDetails)
	if not itemDetails or not itemDetails.itemLink then
		return nil
	end

	local itemLink = itemDetails.itemLink
	local bagID, slotID = itemDetails.bagID, itemDetails.slotID

	-- Quick check for common openable item types
	local _, _, _, _, _, itemType, itemSubType = C_Item.GetItemInfo(itemLink)
	local Consumable = itemType == 'Consumable' or itemSubType == 'Consumables'

	if Consumable and itemSubType and string.find(itemSubType, 'Curio') and addon.DB.FilterCurios then
		return true
	end

	-- Use tooltip scanning for detailed analysis
	Tooltip:ClearLines()
	Tooltip:SetOwner(UIParent, 'ANCHOR_NONE')
	if bagID and slotID then
		Tooltip:SetBagItem(bagID, slotID)
	else
		Tooltip:SetHyperlink(itemLink)
	end

	for i = 1, Tooltip:NumLines() do
		local line = _G['BaganatorOpenableTextLeft' .. i]
		if line then
			local LineText = line:GetText()
			if LineText then
				-- Debug logging for cache items
				if string.find(itemLink, "Cache") then
					Log('Cache item tooltip line ' .. i .. ': "' .. LineText .. '"')
				end
				
				-- Search for basic openable items
				for _, v in pairs(SearchItems) do
					if string.find(LineText, v) then
						return true
					end
				end

				-- Check for containers (caches, chests, etc.)
				if addon.DB.FilterContainers and (string.find(LineText, 'Right [Cc]lick to open') or string.find(LineText, '<Right [Cc]lick to [Oo]pen>')) then
					Log('Found container with right click text: ' .. LineText)
					return true
				end

				if addon.DB.FilterAppearance and (string.find(LineText, ITEM_COSMETIC_LEARN) or string.find(LineText, GetLocaleString('Use: Collect the appearance'))) then
					return true
				end

				-- Remove (%s). from ITEM_CREATE_LOOT_SPEC_ITEM
				local CreateItemString = ITEM_CREATE_LOOT_SPEC_ITEM:gsub(' %(%%s%)%.', '')
				if addon.DB.CreatableItem and (string.find(LineText, CreateItemString) or string.find(LineText, 'Create a soulbound item for your class')) then
					return true
				end

				if LineText == LOCKED then
					return true
				end

				if addon.DB.FilterToys and string.find(LineText, ITEM_TOY_ONUSE) then
					return true
				end

				if addon.DB.FilterCompanion and string.find(LineText, 'companion') then
					return true
				end

				if addon.DB.FilterKnowledge and (string.find(LineText, 'Knowledge') and string.find(LineText, 'Study to increase')) then
					return true
				end

				if
					addon.DB.FilterRepGain and (string.find(LineText, REP_USE_TEXT) or string.find(LineText, GetLocaleString('reputation towards')) or string.find(LineText, GetLocaleString('reputation with'))) and
						string.find(LineText, ITEM_SPELL_TRIGGER_ONUSE)
				 then
					return true
				end

				if addon.DB.FilterMounts and (string.find(LineText, GetLocaleString('Use: Teaches you how to summon this mount')) or string.find(LineText, 'Drakewatcher Manuscript')) then
					return true
				end

				if addon.DB.FilterGenericUse and string.find(LineText, ITEM_SPELL_TRIGGER_ONUSE) then
					return true
				end
			end
		end
	end

	return false
end

-- Animation function for corner widget with pause states
local function AnimateTextures(frame)
	local elapsedTime = 0
	local animationTimer
	-- Store state on frame so it persists across timer restarts
	if not frame.animationState then
		frame.animationState = 1 -- 1 = blue visible, 2 = fading to green, 3 = green visible, 4 = fading to blue
	end
	local currentState = frame.animationState

	local function SetTextureState(alpha1, alpha2)
		if frame.texture1 then
			frame.texture1:SetAlpha(alpha1)
		end
		if frame.texture2 then
			frame.texture2:SetAlpha(alpha2)
		end
	end

	local function StartPause(nextState, alpha1, alpha2)
		-- Cancel current animation timer
		if frame.animationTimer then
			addon:CancelTimer(frame.animationTimer)
		end

		-- Set final alpha values and update persistent state
		SetTextureState(alpha1, alpha2)
		frame.animationState = nextState

		-- Start pause timer
		frame.animationTimer = addon:ScheduleTimer(function()
			AnimateTextures(frame) -- Restart animation for next phase
		end, TIME_BETWEEN_CYCLES)

		Log('Started pause timer for ' .. TIME_BETWEEN_CYCLES .. ' seconds, next state: ' .. nextState)
	end

	local function UpdateAnimation()
		elapsedTime = elapsedTime + ANIMATION_UPDATE_INTERVAL
		local progress = elapsedTime / ANIMATION_CYCLE_TIME

		if currentState == 1 then -- Blue visible, start fading to green
			currentState = 2
			frame.animationState = 2
			elapsedTime = 0
			Log('Starting fade: blue to green')
		elseif currentState == 2 then -- Fading blue to green
			if progress >= 1 then
				StartPause(3, 0, 1) -- Pause at green
				return
			end
			SetTextureState(1 - progress, progress)
		elseif currentState == 3 then -- Green visible, start fading to blue
			currentState = 4
			frame.animationState = 4
			elapsedTime = 0
			Log('Starting fade: green to blue')
		elseif currentState == 4 then -- Fading green to blue
			if progress >= 1 then
				StartPause(1, 1, 0) -- Pause at blue
				return
			end
			SetTextureState(progress, 1 - progress)
		end
	end

	-- Start the animation timer
	animationTimer = addon:ScheduleRepeatingTimer(UpdateAnimation, ANIMATION_UPDATE_INTERVAL)
	frame.animationTimer = animationTimer

	-- Set initial state based on current animation state
	if currentState == 1 or currentState == 2 then
		SetTextureState(1, 0) -- Start with blue visible
		Log('Started animation cycle at blue')
	elseif currentState == 3 or currentState == 4 then
		SetTextureState(0, 1) -- Start with green visible
		Log('Started animation cycle at green')
	end
end

-- Baganator Corner Widget Functions
local function OnCornerWidgetInit(itemButton)
	Log('OnCornerWidgetInit called for itemButton')
	local frame = CreateFrame('Frame', nil, itemButton)
	frame:SetSize(35, 35)

	-- Create two textures for crossfading animation
	local texture1 = frame:CreateTexture(nil, 'OVERLAY')
	texture1:SetAllPoints(frame)
	texture1:SetAtlas('bags-glow-blue')
	texture1:SetAlpha(1) -- Start fully visible

	local texture2 = frame:CreateTexture(nil, 'OVERLAY')
	texture2:SetAllPoints(frame)
	texture2:SetAtlas('bags-glow-green')
	texture2:SetAlpha(0) -- Start invisible

	-- Third static texture for debugging
	local texture3 = frame:CreateTexture(nil, 'OVERLAY')
	texture3:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
	texture3:SetAtlas('ShipMissionIcon-Treasure-Map')
	texture3:SetSize(20, 20)
	texture3:SetAlpha(1) -- Always visible

	-- Store all textures
	frame.texture1 = texture1
	frame.texture2 = texture2
	frame.texture3 = texture3
	frame.texture = texture3 -- For compatibility, use static texture

	Log('Corner widget frame created with dual textures')
	return frame
end

-- Cleanup function to stop animation timers
local function CleanupAnimation(cornerFrame)
	if cornerFrame.animationTimer then
		addon:CancelTimer(cornerFrame.animationTimer)
		cornerFrame.animationTimer = nil
		cornerFrame.animationState = nil -- Reset state
		Log('Canceled animation timer and reset state')
	end
end

local function OnCornerWidgetUpdate(cornerFrame, itemDetails)
	if not addon.DB.ShowOpenableIndicator then
		Log('ShowOpenableIndicator is disabled, hiding widget')
		CleanupAnimation(cornerFrame)
		return false
	end

	if not itemDetails or not itemDetails.itemLink then
		Log('No itemDetails or itemLink provided')
		CleanupAnimation(cornerFrame)
		return false
	end

	Log('Checking item: ' .. (itemDetails.itemLink or 'unknown'))
	local isOpenable = CheckItem(itemDetails)
	if isOpenable then
		Log('Item is openable, showing animated textures')
		-- Start animation if not already running
		if not cornerFrame.animationTimer then
			local success, errorMsg = pcall(AnimateTextures, cornerFrame)
			if not success then
				Log('ERROR starting animation: ' .. tostring(errorMsg))
			end
		end
		return true
	else
		-- Stop animation timer when hiding
		CleanupAnimation(cornerFrame)
		Log('Item is not openable, hiding widget')
	end

	return false
end

-- Register corner widget at top level like Baganator's own widgets
print('BaganatorOpenable: Attempting direct registration at top level')
if Baganator and Baganator.API and Baganator.API.RegisterCornerWidget then
	print('BaganatorOpenable: Baganator API found, registering corner widget')
	local success, err =
		pcall(
		function()
			Baganator.API.RegisterCornerWidget(
				'Openable Items', -- label
				'baganator_openable_items', -- id
				OnCornerWidgetUpdate, -- onUpdate
				OnCornerWidgetInit, -- onInit
				{corner = 'top_right', priority = 1}, -- defaultPosition
				false -- isFast
			)
		end
	)

	if success then
		print('BaganatorOpenable: Direct registration SUCCESS!')
	else
		print('BaganatorOpenable: Direct registration ERROR: ' .. tostring(err))
	end
else
	print('BaganatorOpenable: Baganator API not available at top level')
end

function addon:OnInitialize()
	-- Debug SUI logging setup
	if SUI then
		print('BaganatorOpenable: SUI detected - checking logging config')
		if SUI.DBMod then
			print('BaganatorOpenable: SUI.DBMod found')
			if SUI.DBMod.LoggingFlags then
				print('BaganatorOpenable: Using SUI.DBMod.LoggingFlags')
			end
		end
		if SUI.DB then
			print('BaganatorOpenable: SUI.DB found')
			if SUI.DB.EnabledLogModules then
				print('BaganatorOpenable: Using SUI.DB.EnabledLogModules')
			elseif SUI.DB.LogModules then
				print('BaganatorOpenable: Using SUI.DB.LogModules')
			end
		end
	else
		print('BaganatorOpenable: SUI not detected - using print fallback')
	end

	Log('BaganatorOpenable addon initializing...')
	print('BaganatorOpenable: OnInitialize called')
	-- Setup DB
	self.DataBase = LibStub('AceDB-3.0'):New('BaganatorOpenableDB', {profile = profile}, true)
	self.DB = self.DataBase.profile ---@type Profile
	Log('Database initialized with ShowOpenableIndicator: ' .. tostring(self.DB.ShowOpenableIndicator))
	
	-- Setup options panel
	self:SetupOptions()
end

function addon:OnDisable()
	Log('BaganatorOpenable addon disabling - canceling all timers')
	-- Cancel any running timers when addon is disabled
	self:CancelAllTimers()
end

function addon:RegisterWithBaganator()
	print('BaganatorOpenable: RegisterWithBaganator function called')
	Log('Attempting to register with Baganator...')
	print('BaganatorOpenable: Attempting to register with Baganator...')

	-- Check what's available
	print('BaganatorOpenable: IsAddOnLoaded(Baganator)=' .. tostring(IsAddOnLoaded('Baganator')))
	print('BaganatorOpenable: Baganator global=' .. tostring(Baganator))

	if not Baganator then
		Log('ERROR: Baganator global not found')
		print('BaganatorOpenable: ERROR - Baganator global not found')
		print('BaganatorOpenable: Will try to register when Baganator loads')
		self:RegisterEvent('ADDON_LOADED')
		return
	end
	if not Baganator.API then
		Log('ERROR: Baganator.API not found')
		print('BaganatorOpenable: ERROR - Baganator.API not found')
		return
	end
	if not Baganator.API.RegisterCornerWidget then
		Log('ERROR: Baganator.API.RegisterCornerWidget not found')
		print('BaganatorOpenable: ERROR - Baganator.API.RegisterCornerWidget not found')
		return
	end

	Log('Registering corner widget with Baganator API...')
	print('BaganatorOpenable: Registering corner widget with Baganator API...')

	local success, err =
		pcall(
		function()
			Baganator.API.RegisterCornerWidget(
				'Openable Items', -- label
				'baganator_openable_items', -- id
				OnCornerWidgetUpdate, -- onUpdate
				OnCornerWidgetInit, -- onInit
				{corner = 'bottom_right', priority = 1}, -- defaultPosition
				false -- isFast
			)
		end
	)

	if not success then
		Log('ERROR during registration: ' .. tostring(err))
		print('BaganatorOpenable: ERROR during registration - ' .. tostring(err))
		return
	end

	Log('Corner widget registration completed!')
	print('BaganatorOpenable: Corner widget registration completed!')

	-- Check if it was registered successfully
	if Baganator.API.IsCornerWidgetActive and Baganator.API.IsCornerWidgetActive('baganator_openable_items') then
		Log('Corner widget is ACTIVE in Baganator')
		print('BaganatorOpenable: Corner widget is ACTIVE in Baganator')
	else
		Log('Corner widget is NOT ACTIVE in Baganator - may need to be enabled in options')
		print('BaganatorOpenable: Corner widget is NOT ACTIVE - check Baganator options')
	end
end

function addon:ADDON_LOADED(event, loadedAddon)
	print('BaganatorOpenable: ADDON_LOADED event - ' .. tostring(loadedAddon))
	if loadedAddon == 'Baganator' then
		Log('Baganator addon loaded event received, registering...')
		print('BaganatorOpenable: Baganator loaded event received')
		self:RegisterWithBaganator()
		self:UnregisterEvent('ADDON_LOADED')
	end
end

-- AceOptions Configuration
local function GetOptions()
	return {
		name = "Baganator Openable",
		type = "group",
		args = {
			header = {
				type = "description",
				name = "Baganator Openable Settings\n",
				fontSize = "large",
				order = 1,
			},
			showIndicator = {
				type = "toggle",
				name = "Show Openable Indicator",
				desc = "Display animated corner widget on openable items",
				get = function() return addon.DB.ShowOpenableIndicator end,
				set = function(_, value) addon.DB.ShowOpenableIndicator = value end,
				order = 10,
			},
			filterHeader = {
				type = "header",
				name = "Item Type Filters",
				order = 20,
			},
			filterDesc = {
				type = "description",
				name = "Choose which types of openable items to highlight:",
				order = 21,
			},
			filterToys = {
				type = "toggle",
				name = "Toys",
				desc = "Highlight toy items that can be learned",
				get = function() return addon.DB.FilterToys end,
				set = function(_, value) addon.DB.FilterToys = value end,
				order = 30,
			},
			filterAppearance = {
				type = "toggle",
				name = "Appearances",
				desc = "Highlight items that teach appearances/transmog",
				get = function() return addon.DB.FilterAppearance end,
				set = function(_, value) addon.DB.FilterAppearance = value end,
				order = 31,
			},
			filterMounts = {
				type = "toggle",
				name = "Mounts",
				desc = "Highlight mount teaching items",
				get = function() return addon.DB.FilterMounts end,
				set = function(_, value) addon.DB.FilterMounts = value end,
				order = 32,
			},
			filterCompanion = {
				type = "toggle",
				name = "Companions/Pets",
				desc = "Highlight companion and pet items",
				get = function() return addon.DB.FilterCompanion end,
				set = function(_, value) addon.DB.FilterCompanion = value end,
				order = 33,
			},
			filterRepGain = {
				type = "toggle",
				name = "Reputation Items",
				desc = "Highlight items that give reputation",
				get = function() return addon.DB.FilterRepGain end,
				set = function(_, value) addon.DB.FilterRepGain = value end,
				order = 34,
			},
			filterCurios = {
				type = "toggle",
				name = "Curios",
				desc = "Highlight curio items",
				get = function() return addon.DB.FilterCurios end,
				set = function(_, value) addon.DB.FilterCurios = value end,
				order = 35,
			},
			filterContainers = {
				type = "toggle",
				name = "Containers",
				desc = "Highlight containers with 'Right click to open' text (caches, chests, etc.)",
				get = function() return addon.DB.FilterContainers end,
				set = function(_, value) addon.DB.FilterContainers = value end,
				order = 36,
			},
			filterKnowledge = {
				type = "toggle",
				name = "Knowledge Items",
				desc = "Highlight knowledge/profession learning items",
				get = function() return addon.DB.FilterKnowledge end,
				set = function(_, value) addon.DB.FilterKnowledge = value end,
				order = 37,
			},
			filterCreatable = {
				type = "toggle",
				name = "Creatable Items",
				desc = "Highlight items that create class-specific gear",
				get = function() return addon.DB.CreatableItem end,
				set = function(_, value) addon.DB.CreatableItem = value end,
				order = 38,
			},
			filterGeneric = {
				type = "toggle",
				name = "Generic Use Items",
				desc = "Highlight generic 'Use:' items (may be noisy)",
				get = function() return addon.DB.FilterGenericUse end,
				set = function(_, value) addon.DB.FilterGenericUse = value end,
				order = 39,
			},
		}
	}
end

function addon:SetupOptions()
	LibStub("AceConfig-3.0"):RegisterOptionsTable("BaganatorOpenable", GetOptions)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("BaganatorOpenable", "Baganator Openable")
	Log('Options panel registered with Blizzard Interface')
end
