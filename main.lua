local addonName, root = ... --[[@type string, table]]

---@class BaganatorOpenable: AceAddon, AceTimer-3.0
local addon = LibStub('AceAddon-3.0'):NewAddon(addonName, 'AceEvent-3.0', 'AceTimer-3.0')

-- Simple global animation system - just replace individual timers with one master timer
local globalAnimationTimer = nil
local animatingFrames = {}

---@class Profile
local profile = {
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
	ShowOpenableIndicator = true,
	-- Animation Settings
	AnimationCycleTime = 0.5,
	TimeBetweenCycles = 0.10,
	AnimationUpdateInterval = 0.1
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
		-- print('BaganatorOpenable: ' .. tostring(msg))
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

	if string.find(itemLink, 'Cache') then
		local consume = C_Item.IsConsumableItem(itemLink)
		Log('Cache item detected: ' .. itemLink .. ', IsConsumable=' .. tostring(consume))
		local usable, noMana = C_Item.IsUsableItem(itemLink)
		Log('Cache item usable: ' .. tostring(usable) .. ', noMana: ' .. tostring(noMana))
	end
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

	-- Give tooltip time to fully populate
	if string.find(itemLink, 'Cache') then
		Log('Cache item detected, waiting for tooltip to populate...')
	end

	local numLines = Tooltip:NumLines()
	Log('Tooltip has ' .. numLines .. ' lines for item: ' .. itemLink)
	for i = 1, numLines do
		local leftLine = _G['BaganatorOpenableTextLeft' .. i]
		local rightLine = _G['BaganatorOpenableTextRight' .. i]
		if leftLine then
			local LineText = leftLine:GetText()
			if LineText then
				-- Debug logging for cache items - show ALL lines
				if string.find(itemLink, 'Cache') then
					Log('Cache item tooltip line ' .. i .. ' (LEFT): "' .. LineText .. '"')
				end

				-- Search for basic openable items
				for _, v in pairs(SearchItems) do
					if string.find(LineText, v) then
						return true
					end
				end

				-- Check for containers (caches, chests, etc.)
				if
					addon.DB.FilterContainers and
						(string.find(LineText, 'Weekly cache') or string.find(LineText, 'Right [Cc]lick to open') or string.find(LineText, '<Right [Cc]lick to [Oo]pen>') or string.find(LineText, 'Contains'))
				 then
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

		if rightLine then
			local RightLineText = rightLine:GetText()
			if RightLineText then
				-- Debug logging for cache items - show RIGHT lines too
				if string.find(itemLink, 'Cache') then
					Log('Cache item tooltip line ' .. i .. ' (RIGHT): "' .. RightLineText .. '"')
				end

				-- Search right side text too
				for _, v in pairs(SearchItems) do
					if string.find(RightLineText, v) then
						return true
					end
				end

				-- Check right side for containers
				if addon.DB.FilterContainers and (string.find(RightLineText, 'Right [Cc]lick to open') or string.find(RightLineText, '<Right [Cc]lick to [Oo]pen>')) then
					Log('Found container with right click text: ' .. RightLineText)
					return true
				end
			end
		end
	end

	-- Final debug for cache items
	if string.find(itemLink, 'Cache') then
		Log('Cache item tooltip scan complete: ' .. numLines .. ' total lines, no "Right click to open" found')
	end

	return false
end

-- Helper function to check if Baganator bags are visible
local function AreBagsVisible()
	if not Baganator then
		return false
	end
	
	-- Check modern Baganator API first
	if Baganator.Core and Baganator.Core.ViewManagement and Baganator.Core.ViewManagement.GetAllViews then
		local views = Baganator.Core.ViewManagement.GetAllViews()
		for _, view in pairs(views) do
			if view:IsShown() then
				return true
			end
		end
	end
	
	-- Fallback checks for legacy frame names
	if BaganatorBagView and BaganatorBagView:IsShown() then
		return true
	end
	
	if BaganatorBankView and BaganatorBankView:IsShown() then
		return true
	end
	
	-- Additional fallback - check for any visible Baganator frames
	if Baganator.API and Baganator.API.IsViewVisible then
		return Baganator.API.IsViewVisible()
	end
	
	return false
end

-- Global animation update function - runs all frame animations
local function GlobalAnimationUpdate()
	-- Check if Baganator bags are visible before updating animations
	if not AreBagsVisible() then
		Log('Bags not visible, stopping animation timer to save resources', 'debug')
		StopGlobalTimer()
		return
	end
	
	for frame in pairs(animatingFrames) do
		if frame.updateFunction then
			frame.updateFunction()
		end
	end
end

-- Start global timer if not running
local function StartGlobalTimer()
	if not globalAnimationTimer then
		-- Only start timer if bags are visible
		if not AreBagsVisible() then
			Log('Bags not visible, skipping animation timer start', 'debug')
			return
		end
		
		globalAnimationTimer = addon:ScheduleRepeatingTimer(GlobalAnimationUpdate, addon.DB.AnimationUpdateInterval)
		local count = 0
		for _ in pairs(animatingFrames) do
			count = count + 1
		end
		Log('Started global animation timer for ' .. count .. ' frames (bags visible)')
	end
end

-- Stop global timer if no frames
local function StopGlobalTimer()
	if globalAnimationTimer then
		addon:CancelTimer(globalAnimationTimer)
		globalAnimationTimer = nil
		Log('Stopped global animation timer')
	end
end

-- Animation function for corner widget with pause states
local function AnimateTextures(frame)
	-- Store state on frame so it persists across timer restarts
	if not frame.animationState then
		frame.animationState = 1 -- 1 = blue visible, 2 = fading to green, 3 = green visible, 4 = fading to blue
	end
	local currentState = frame.animationState
	local elapsedTime = 0

	local function SetTextureState(alpha1, alpha2)
		if frame.texture1 then
			frame.texture1:SetAlpha(alpha1)
		end
		if frame.texture2 then
			frame.texture2:SetAlpha(alpha2)
		end
	end

	local function StartPause(nextState, alpha1, alpha2)
		-- Set final alpha values and update persistent state
		SetTextureState(alpha1, alpha2)
		frame.animationState = nextState

		-- Start pause timer (individual timer for pauses)
		frame.pauseTimer =
			addon:ScheduleTimer(
			function()
				AnimateTextures(frame) -- Restart animation for next phase
			end,
			addon.DB.TimeBetweenCycles
		)

		Log('Started pause timer for ' .. addon.DB.TimeBetweenCycles .. ' seconds, next state: ' .. nextState, 'debug')
	end

	local function UpdateAnimation()
		elapsedTime = elapsedTime + addon.DB.AnimationUpdateInterval
		local progress = elapsedTime / addon.DB.AnimationCycleTime

		if currentState == 1 then -- Blue visible, start fading to green
			currentState = 2
			frame.animationState = 2
			elapsedTime = 0
			Log('Starting fade: blue to green', 'debug')
		elseif currentState == 2 then -- Fading blue to green
			if progress >= 1 then
				-- Remove from global animation during pause
				animatingFrames[frame] = nil
				local count = 0
				for _ in pairs(animatingFrames) do
					count = count + 1
				end
				if count == 0 then
					StopGlobalTimer()
				end

				StartPause(3, 0, 1) -- Pause at green
				return
			end
			SetTextureState(1 - progress, progress)
		elseif currentState == 3 then -- Green visible, start fading to blue
			currentState = 4
			frame.animationState = 4
			elapsedTime = 0
			Log('Starting fade: green to blue', 'debug')
		elseif currentState == 4 then -- Fading green to blue
			if progress >= 1 then
				-- Remove from global animation during pause
				animatingFrames[frame] = nil
				local count = 0
				for _ in pairs(animatingFrames) do
					count = count + 1
				end
				if count == 0 then
					StopGlobalTimer()
				end

				StartPause(1, 1, 0) -- Pause at blue
				return
			end
			SetTextureState(progress, 1 - progress)
		end
	end

	-- Add this frame to global animation
	frame.updateFunction = UpdateAnimation
	animatingFrames[frame] = true
	StartGlobalTimer()

	-- Set initial state based on current animation state
	if currentState == 1 or currentState == 2 then
		SetTextureState(1, 0) -- Start with blue visible
		Log('Started animation cycle at blue', 'debug')
	elseif currentState == 3 or currentState == 4 then
		SetTextureState(0, 1) -- Start with green visible
		Log('Started animation cycle at green', 'debug')
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
	-- Remove from global animation
	if animatingFrames[cornerFrame] then
		animatingFrames[cornerFrame] = nil
		local count = 0
		for _ in pairs(animatingFrames) do
			count = count + 1
		end
		if count == 0 then
			StopGlobalTimer()
		end
		Log('Removed frame from global animation, ' .. count .. ' frames remaining', 'debug')
	end

	-- Cancel pause timer if running
	if cornerFrame.pauseTimer then
		addon:CancelTimer(cornerFrame.pauseTimer)
		cornerFrame.pauseTimer = nil
		Log('Canceled pause timer')
	end

	-- Reset state
	cornerFrame.animationState = nil
	cornerFrame.updateFunction = nil
end

-- Function to refresh all corner widgets after settings changes
local function RefreshAllCornerWidgets()
	if not Baganator or not AreBagsVisible() then
		Log('Baganator not available or bags not visible, skipping refresh')
		return
	end
	
	Log('Refreshing all corner widgets due to settings change')
	
	-- Try to trigger Baganator's corner widget refresh
	if Baganator.API and Baganator.API.RequestItemButtonsRefresh then
		-- Modern API method
		Baganator.API.RequestItemButtonsRefresh()
		Log('Requested item buttons refresh via API')
	elseif Baganator.Core and Baganator.Core.ViewManagement then
		-- Try to refresh all views
		if Baganator.Core.ViewManagement.GetAllViews then
			local views = Baganator.Core.ViewManagement.GetAllViews()
			for _, view in pairs(views) do
				if view:IsShown() and view.RefreshItems then
					view:RefreshItems()
				elseif view:IsShown() and view.UpdateView then
					view:UpdateView()
				end
			end
			Log('Refreshed views via ViewManagement')
		end
	else
		-- Fallback: Force corner widget updates by clearing and re-evaluating animations
		-- Stop all current animations first
		for frame in pairs(animatingFrames) do
			CleanupAnimation(frame)
		end
		
		Log('Cleared all animations, widgets will re-evaluate on next update cycle')
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
		if not animatingFrames[cornerFrame] then
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
if Baganator and Baganator.API and Baganator.API.RegisterCornerWidget then
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

	if not success then
		print('BaganatorOpenable: Direct registration ERROR: ' .. tostring(err))
	end
end

function addon:OnInitialize()
	Log('BaganatorOpenable addon initializing...')
	-- Setup DB
	self.DataBase = LibStub('AceDB-3.0'):New('BaganatorOpenableDB', {profile = profile}, true)
	self.DB = self.DataBase.profile ---@type Profile
	Log('Database initialized with ShowOpenableIndicator: ' .. tostring(self.DB.ShowOpenableIndicator))

	-- Setup options panel
	self:SetupOptions()
	
	-- Register events to restart animation when bags are opened
	self:RegisterEvent('ADDON_LOADED')
end

function addon:ADDON_LOADED(event, addonName)
	if addonName == 'Baganator' then
		-- Hook into Baganator events if available
		if Baganator and Baganator.CallbackRegistry then
			Baganator.CallbackRegistry:RegisterCallback('BagShow', function()
				-- Restart animation for any frames that should be animating when bags open
				if next(animatingFrames) then
					Log('Bags shown, restarting animation timer')
					StartGlobalTimer()
				end
			end)
		end
		self:UnregisterEvent('ADDON_LOADED')
	end
end

function addon:OnDisable()
	Log('BaganatorOpenable addon disabling - stopping global animation and canceling all timers')
	-- Stop global animation
	StopGlobalTimer()
	animatingFrames = {}
	-- Cancel any running timers when addon is disabled
	self:CancelAllTimers()
end

-- AceOptions Configuration
local function GetOptions()
	return {
		name = 'Baganator Openable',
		type = 'group',
		args = {
			header = {
				type = 'description',
				name = 'Baganator Openable Settings\n',
				fontSize = 'large',
				order = 1
			},
			showIndicator = {
				type = 'toggle',
				name = 'Show Openable Indicator',
				desc = 'Display animated corner widget on openable items',
				get = function()
					return addon.DB.ShowOpenableIndicator
				end,
				set = function(_, value)
					addon.DB.ShowOpenableIndicator = value
					-- Refresh all widgets when indicator is toggled
					RefreshAllCornerWidgets()
				end,
				order = 10
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
				end,
				order = 39
			},
			animationHeader = {
				type = 'header',
				name = 'Animation Settings',
				order = 40
			},
			animationGroup = {
				type = 'group',
				name = 'Animation Timing',
				inline = true,
				order = 41,
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
	LibStub('AceConfig-3.0'):RegisterOptionsTable('BaganatorOpenable', GetOptions)
	LibStub('AceConfigDialog-3.0'):AddToBlizOptions('BaganatorOpenable', 'Baganator Openable')
	Log('Options panel registered with Blizzard Interface')
end
