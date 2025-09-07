local addonName, root = ... --[[@type string, table]]

-- Immediate startup logging
print('BaganatorOpenable: Addon file loaded, addonName=' .. tostring(addonName))

---@class BaganatorOpenable: AceAddon, AceTimer-3.0
local addon = LibStub('AceAddon-3.0'):NewAddon(addonName, 'AceEvent-3.0', 'AceTimer-3.0')

print('BaganatorOpenable: AceAddon created successfully')

-- Animation Constants
local ANIMATION_CYCLE_TIME = 4.0 -- Total animation cycle time in seconds
local ANIMATION_FADE_TIME = 2.0  -- Time to fade from one texture to the other
local ANIMATION_UPDATE_INTERVAL = 0.05 -- How often to update the animation (20 FPS)

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
				-- Search for basic openable items
				for _, v in pairs(SearchItems) do
					if string.find(LineText, v) then
						return true
					end
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

				if addon.DB.FilterGenericUse and (string.find(LineText, ITEM_SPELL_TRIGGER_ONUSE) or string.find(LineText, GetLocaleString('Right Click to Open'))) then
					return true
				end
			end
		end
	end

	return false
end

-- Animation function for corner widget
local function AnimateTextures(frame)
	local elapsedTime = 0
	local animationTimer
	
	local function UpdateAnimation()
		elapsedTime = elapsedTime + ANIMATION_UPDATE_INTERVAL
		
		-- Calculate position in animation cycle (0 to 1)
		local cyclePosition = (elapsedTime % ANIMATION_CYCLE_TIME) / ANIMATION_CYCLE_TIME
		
		-- Calculate alpha values for crossfading
		local alpha1, alpha2
		if cyclePosition <= 0.5 then
			-- First half: fade from texture1 to texture2
			local fadeProgress = cyclePosition * 2 -- 0 to 1
			alpha1 = 1 - fadeProgress
			alpha2 = fadeProgress
		else
			-- Second half: fade from texture2 back to texture1
			local fadeProgress = (cyclePosition - 0.5) * 2 -- 0 to 1
			alpha1 = fadeProgress
			alpha2 = 1 - fadeProgress
		end
		
		if frame.texture1 then
			frame.texture1:SetAlpha(alpha1)
		end
		if frame.texture2 then
			frame.texture2:SetAlpha(alpha2)
		end
	end
	
	-- Start the animation timer
	animationTimer = addon:ScheduleRepeatingTimer(UpdateAnimation, ANIMATION_UPDATE_INTERVAL)
	frame.animationTimer = animationTimer
	
	Log('Started animation timer for corner widget')
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
	texture2:SetAtlas('bags-glow-heirloom')
	texture2:SetAlpha(0) -- Start invisible

	-- Third static texture for debugging
	local texture3 = frame:CreateTexture(nil, 'OVERLAY')
	texture3:SetAllPoints(frame)
	texture3:SetAtlas('ShipMissionIcon-Treasure-Map')
	texture3:SetAlpha(1) -- Always visible

	-- Store all textures
	frame.texture1 = texture1
	frame.texture2 = texture2
	frame.texture3 = texture3
	frame.texture = texture3 -- For compatibility, use static texture
	
	Log('Corner widget frame created with dual textures')
	return frame
end

local function OnCornerWidgetUpdate(cornerFrame, itemDetails)
	if not addon.DB.ShowOpenableIndicator then
		Log('ShowOpenableIndicator is disabled, hiding widget')
		return false
	end

	if not itemDetails or not itemDetails.itemLink then
		Log('No itemDetails or itemLink provided')
		return false
	end

	Log('Checking item: ' .. (itemDetails.itemLink or 'unknown'))
	local isOpenable = CheckItem(itemDetails)
	if isOpenable then
		Log('Item is openable, showing animated textures')
		-- Start animation if not already running
		if not cornerFrame.animationTimer then
			AnimateTextures(cornerFrame)
		end
		return true
	else
		-- Stop animation timer when hiding
		if cornerFrame.animationTimer then
			addon:CancelTimer(cornerFrame.animationTimer)
			cornerFrame.animationTimer = nil
		end
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
