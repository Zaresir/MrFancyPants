-----------------------------------------------------------------------------------------------
-- Client Lua Script for MrFancyPants
-- Copyright (c) NCsoft. All rights reserved
-- Addon Author Kyle Staves, Sortasoft LLC
-- Contact: Rivance on Curse
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- Healpers
-----------------------------------------------------------------------------------------------
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function dump (tbl, indent)
	if not indent then indent = 0 end
	for k, v in pairs(tbl) do
		formatting = string.rep(" ", indent) .. k .. ": "
		if type(v) == "table" then
			Print(formatting)
			dump(v, indent+1)
		else
			Print(formatting .. tostring(v))
		end
	end
end

-----------------------------------------------------------------------------------------------
-- MrFancyPants Module Definition
-----------------------------------------------------------------------------------------------
local MrFancyPants = {} 

local defaults = {}
defaults.compatibility = "2.0.0"
defaults.sets = {}
defaults.las = {}

local setPrototype = {}
setPrototype.name = "New Set"
setPrototype.items = {}
setPrototype.usedSlots = {}
setPrototype.usedSlots[0] = true -- Chest
setPrototype.usedSlots[1] = true -- Legs
setPrototype.usedSlots[2] = true -- Head
setPrototype.usedSlots[3] = true -- Shoulder
setPrototype.usedSlots[4] = true -- Feet
setPrototype.usedSlots[5] = true -- Hand
setPrototype.usedSlots[6] = false -- Tool Slot
setPrototype.usedSlots[7] = true -- Weapon Attachment
setPrototype.usedSlots[8] = true -- Support System
setPrototype.usedSlots[9] = true -- Augment Slot
setPrototype.usedSlots[10] = true -- Implant Slot
setPrototype.usedSlots[11] = true -- Gadget
setPrototype.usedSlots[12] = false
setPrototype.usedSlots[13] = false
setPrototype.usedSlots[14] = false
setPrototype.usedSlots[15] = true -- Shield
setPrototype.usedSlots[16] = true -- Weapon
setPrototype.usedSlots[17] = false -- Bags
setPrototype.usedSlots[18] = false
setPrototype.usedSlots[19] = false
setPrototype.usedSlots[20] = false
setPrototype.usedSlots[21] = false
setPrototype.usedSlots[22] = false
setPrototype.usedSlots[23] = false
setPrototype.usedSlots[24] = false
setPrototype.usedSlots[25] = false

local itemPrototype = {}
itemPrototype.name = "ITEM NAME"
itemPrototype.slot = "itemObject:GetSlot()"
itemPrototype.cmpStr = "eCategory-eFamily-eQuality-arBudgetBasedProperties-arInnateProperties-arRandomProperties-arSigils-arImbuments-arSpells"

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function MrFancyPants:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 	

    -- initialize variables here
	-- Thanks to Wafflestick from the official game forums for this method
	o.optionalDependencies = {
		["ToolTips"] = true,
		["VikingTooltips"] = true
	}

    return o
end

function MrFancyPants:Init()
	local bHasConfigureFunction = true
	local strConfigureButtonText = "MrFancyPants"
	local tDependencies = {
		-- "UnitOrPackageName",
		"ToolTips",
		"VikingTooltips"
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function MrFancyPants:OnDependencyError(strDep, strErr)
    -- If we get a dependency error, remove it from the table
    -- of valid dependencies.  We need to be left with at least
    -- the base dependency (the Carbine provided addon) though!
    if strDep == "ToolTips" or strDep == "VikingTooltips" then
        self.optionalDependencies [strDep] = nil
        return true
    end

    return false
end

-----------------------------------------------------------------------------------------------
-- MrFancyPants OnLoad
-----------------------------------------------------------------------------------------------
function MrFancyPants:OnLoad()
	self.textMainWindow = "Main Window"
	self.textConfig = "Configuration"
	self.neededBag = nil
	
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("MrFancyPants.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	self:DefaultSettings(false)
	
	if self.optionalDependencies["VikingTooltips"] == true then
		self.carbineTips = Apollo.GetAddon("VikingTooltips")
	else
		self.carbineTips = Apollo.GetAddon("ToolTips")
	end
	
	self.carbineCallNames = self.carbineTips.CreateCallNames
	self.carbineTips.CreateCallNames = function(luaCaller)
		self.carbineCallNames(luaCaller)
		self.carbineItemForm = Tooltip.GetItemTooltipForm
		Tooltip.GetItemTooltipForm = function(luaCaller, wndControl, item, bStuff, nCount)
			return self.ItemToolTip(luaCaller, wndControl, item, bStuff, nCount)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- MrFancyPants OnDocLoaded
-----------------------------------------------------------------------------------------------
function MrFancyPants:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MrFancyPantsForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		self.wndConfirmSave = Apollo.LoadForm(self.xmlDoc, "ConfirmSaveWindow", nil, self)
		
		if self.wndConfirmSave == nil then
			Apollo.AddAddonErrorText(self, "Could not load the confirm save window for some reason.")
			return
		end
		
		self.wndConfirmDelete = Apollo.LoadForm(self.xmlDoc, "ConfirmDeleteWindow", nil, self)
		
		if self.wndConfirmDelete == nil then
			Apollo.AddAddonErrorText(self, "Could not load the confirm delete window for some reason.")
			return
		end
		
		self.wndRename = Apollo.LoadForm(self.xmlDoc, "RenameWindow", nil, self)
		
		if self.wndRename == nil then
			Apollo.AddAddonErrorText(self, "Could not load the rename window for some reason.")
			return
		end
		
		self.quickSwap = Apollo.LoadForm(self.xmlDoc, "QuickSwapForm", nil, self)
		
		if self.quickSwap == nil then
			Apollo.AddAddonErrorText(self, "Could not load the quick swap for some reason.")
			return
		end
		
		self.quickList = Apollo.LoadForm(self.xmlDoc, "QuickSwapSetList", nil, self)
		
		if self.quickList == nil then
			Apollo.AddAddonErrorText(self, "Could not load the quickList for some reason.")
			return
		end
		
		self.config = Apollo.LoadForm(self.xmlDoc, "MrFancyPantsConfigForm", nil, self)
		
		if self.config == nil then
			Apollo.AddAddonErrorText(self, "Could not load the config window for some reason.")
			return
		end
		
		self.wndSlots = Apollo.LoadForm(self.xmlDoc, "EquipmentSlotForm", nil, self)
		
		if self.wndSlots == nil then
			Apollo.AddAddonErrorText(self, "Could not load the slot config window for some reason.")
			return
		end
		
		self.wndWelcome = Apollo.LoadForm(self.xmlDoc, "WelcomeScreen", nil, self)
		if self.wndWelcome == nil then
			Apollo.AddAddonErrorText(self, "Could not load the welcome screen for some reason.")
			return
		end
		
		self.quickSwap:Show(true, false)
	    self.wndMain:Show(false, true)
		self.wndConfirmSave:Show(false, true)
		self.wndConfirmDelete:Show(false, true)
		self.wndRename:Show(false, true)
		self.config:Show(false,true)
		self.quickList:Show(false,true)
		self.wndSlots:Show(false, true)
		self.wndWelcome:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("fancy", "OnSlashFancy", self)

		self.timer = ApolloTimer.Create(1.0, true, "OnTimer", self)
		
		Apollo.RegisterEventHandler("PlayerEquippedItemChanged", 	"SetInventorySorting", self)
		Apollo.RegisterEventHandler("PlayerPathMissionUpdate", 		"SetInventorySorting", self)
		Apollo.RegisterEventHandler("QuestObjectiveUpdated", 		"SetInventorySorting", self)
		Apollo.RegisterEventHandler("PlayerPathRefresh", 			"SetInventorySorting", self)
		Apollo.RegisterEventHandler("QuestStateChanged", 			"SetInventorySorting", self)
		Apollo.RegisterEventHandler("ChallengeUpdated", 			"SetInventorySorting", self)
		Apollo.RegisterEventHandler("LootedItem",					"SetInventorySorting", self)
		Apollo.RegisterEventHandler("UpdateInventory", 				"SetInventorySorting", self)
		Apollo.RegisterEventHandler("CloseVendorWindow", 			"SetInventorySorting", self)
		Apollo.RegisterEventHandler("InvokeVendorWindow", 			"SetInventorySorting", self)
		Apollo.RegisterEventHandler("UnitEnteredCombat", 			"SetInventorySorting", self)
		
		Apollo.RegisterEventHandler("SpecChanged", 									"OnSpecChanged", self)
		-- Apollo.RegisterEventHandler("PlayerChanged", 								"OnSpecChanged", self)
		-- Apollo.RegisterEventHandler("CharacterCreated", 							"OnSpecChanged", self)
		
		-- Do additional Addon initialization here
		
		self.quickBag = self.quickSwap:FindChild("ToEquipBag");
		self.quickBagContainer = self.quickSwap:FindChild("BagContainer");
		self.bag = self.wndMain:FindChild("ToEquipBag")
		self.bagContainer = self.wndMain:FindChild("BagContainer")
		
		self.setList = self.wndMain:FindChild("AvailableSetList")
		self.currentDisplay = self.wndMain:FindChild("EquippedSetControls") 
		
		self.currentDisplay:Show(false, true)
		
		--self.wndMain:Invoke();
		--self.wndConfirmSave:Invoke();
		
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("ToggleMrFancyPants",				"OnToggleMrFancyPants", self)
		
		if self.db.compatibility == defaults.compatibility then
			self:UpdateAvailableSets()
		end
		
		if self.db.quickPosition ~= nil then
			self.quickSwap:SetAnchorOffsets(self.db.quickPosition.left, self.db.quickPosition.top, self.db.quickPosition.right, self.db.quickPosition.bottom)
		end
		
		if self.db.mainPosition ~= nil then
			self.wndMain:SetAnchorOffsets(self.db.mainPosition.left, self.db.mainPosition.top, self.db.mainPosition.right, self.db.mainPosition.bottom)
		end
		
		self:OnSpecChanged(AbilityBook.GetCurrentSpec())
		
		self:RedrawQuickSwap()
	end
end

function MrFancyPants:OnSlashFancy(sCmd, sArgs)
	if sArgs == "show" then
		self.wndMain:Invoke()
	elseif sArgs == "quickSwap" then
		self.quickSwap:Invoke()
	elseif sArgs == "test" then
		self:OnTestDump()
	elseif sArgs == "resetPositions" then
		-- TODO: RESET SAVE DATA ON POSITIONS
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, "MrFancyPants Help:", "")
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, "/fancy show -- Forces the main window open.", "")
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, "/fancy quickSwap -- Forces the quickSwap window open.", "")
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, "/fancy resetPositions -- Resets the main window and quickSwap bar to the default positions.", "")
	end
end

function MrFancyPants:OnTestDump()
	local player = GameLib.GetPlayerUnit()
	if player == nil then
		return false
	end
	
	local inv = player:GetInventoryItems()
	local equipped = player:GetEquippedItems()
	
	local item = self:GetEquippedItemForSlot(0)
	if item then Print(item:GetName()) end
	
	if true then return end
	
	for key,item in pairs(inv) do
		if item ~= null then
			local inbag = item.itemInBag
			
			if type(inbag) == "userdata" and inbag:GetName() == "Psychedelic Paddles"  then
				local details = inbag:GetDetailedInfo()
				--dump(details)
				--Print("SLOT: "..inbag:GetSlot())
				
				local fancyItem = self:GetFancyItem(inbag) 
			end
		end

	end
end

function MrFancyPants:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "MrFancyPants", {"ToggleMrFancyPants", "", ""})
	--self:UpdateInterfaceMenuAlerts()
end

function MrFancyPants:OnToggleMrFancyPants()
	if self.wndMain:IsVisible() then
		self.wndMain:Close()
	else
		self.wndMain:Invoke()
	end
end

function MrFancyPants:OnConfigure()
	self.wndMain:Invoke()
end

function MrFancyPants:DefaultSettings(forced)
	if forced or self.db == nil then
		self.db = deepcopy(defaults)
	end
	--self.db.sets[setPrototype.name] = deepcopy(setPrototype)
	--self.currentSet = self.db.sets[setPrototype.name]
	
	--self:SetInventorySorting();
end

function MrFancyPants:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	--Print("OnSave")
	
	-- return {} -- Temporarily disabled saving
	
	return deepcopy(self.db)
end

function MrFancyPants:OnRestore(eType, t)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	
	self.db = deepcopy(t)
	
	local didDisplay = self.db.seenWelcome
	
	if self.db.compatibility ~= defaults.compatibility then
		self:DefaultSettings(true)
	end
	
	self.db.seenWelcome = didDisplay
	
	for i,k in pairs(self.db.sets) do
		if k.las ~= nil then
			for i=1,4 do
				if k.las[i] == true then
					self:EquipSetWithLAS(k, i, true)
				end
				--Print("Checking LAS: "..i)
			end
		end
	end
	
	--self:SetInventorySorting();
end

-----------------------------------------------------------------------------------------------
-- MrFancyPants Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on timer
function MrFancyPants:OnTimer()
	if not self.didInitialUpdate then
		self:OnSpecChanged(AbilityBook.GetCurrentSpec())
		self.didInitialUpdate = true
		
		if not self.db.seenWelcome then
			self.wndWelcome:Invoke()
			self.db.seenWelcome = true
		end
	end	
	
	if self.wndMain:IsVisible() or self.quickSwap:IsVisible() then
		self:SetInventorySorting()
	end
end

-------------------------------------------------------------------------
-- Item Functions
-------------------------------------------------------------------------

function MrFancyPants:GetFancyItem(item)
	if type(item) ~= "userdata" then return nil end
	
	local newItem = {}
	local detailedInfo = item:GetDetailedInfo()
	
	newItem.slot = item:GetSlot()
	newItem.name = detailedInfo.tPrimary.strName
	newItem.soulbound = detailedInfo.tPrimary.bSoulbound
	newItem.nId = detailedInfo.tPrimary.nId
	
	newItem.cmpStr = detailedInfo.tPrimary.eCategory
	newItem.cmpStr = newItem.cmpStr .. detailedInfo.tPrimary.eFamily
	newItem.cmpStr = newItem.cmpStr .. detailedInfo.tPrimary.eQuality
	
	if detailedInfo.tPrimary.arBudgetBasedProperties then
		for i=1,15 do
			if detailedInfo.tPrimary.arBudgetBasedProperties[i] == nil then break end
			
			newItem.cmpStr = newItem.cmpStr .. detailedInfo.tPrimary.arBudgetBasedProperties[i].eProperty .. detailedInfo.tPrimary.arBudgetBasedProperties[i].nValue
		end
	end
	
	if detailedInfo.tPrimary.arInnateProperties then
		for i=1,15 do
			if detailedInfo.tPrimary.arInnateProperties[i] == nil then break end
			
			newItem.cmpStr = newItem.cmpStr .. detailedInfo.tPrimary.arInnateProperties[i].eProperty .. detailedInfo.tPrimary.arInnateProperties[i].nValue
		end
	end
	
	if detailedInfo.tPrimary.arRandomProperties then
		for i=1,15 do
			if detailedInfo.tPrimary.arRandomProperties[i] == nil then break end
			
			newItem.cmpStr = newItem.cmpStr .. detailedInfo.tPrimary.arRandomProperties[i].strName
		end
	end
	
	if detailedInfo.tPrimary.tSigils and detailedInfo.tPrimary.tSigils.arSigils then
		for i=1,15 do
			if detailedInfo.tPrimary.tSigils.arSigils[i] == nil then break end
			
			newItem.cmpStr = newItem.cmpStr .. detailedInfo.tPrimary.tSigils.arSigils[i].eElement
		end
	end
	
	if detailedInfo.tPrimary.arImbuments then
		for i=1,15 do
			if detailedInfo.tPrimary.arImbuments[i] == nil then break end
			
			newItem.cmpStr = newItem.cmpStr .. detailedInfo.tPrimary.arImbuments[i].eProperty .. detailedInfo.tPrimary.arImbuments[i].nValue
		end
	end
	
	if detailedInfo.tPrimary.arSpells then
		for i=1,15 do
			if detailedInfo.tPrimary.arSpells[i] == nil then break end
			
			if detailedInfo.tPrimary.arSpells[i].strName then
				newItem.cmpStr = newItem.cmpStr .. detailedInfo.tPrimary.arSpells[i].strName
			end
			
			if detailedInfo.tPrimary.arSpells[i].strFlavor then
				newItem.cmpStr = newItem.cmpStr .. detailedInfo.tPrimary.arSpells[i].strFlavor
			end
		end
	end
	
	return newItem
end

function MrFancyPants:GetItemIsFancyItem(carbineItem, fancyItem)
	if carbineItem == nil then return fancyItem == nil end
	
	if fancyItem == nil then return false end
	
	if not carbineItem:IsSoulbound() then return false end
	if carbineItem:GetSlot() ~= fancyItem.slot then return false end
	if carbineItem:GetName() ~= fancyItem.name then return false end
	
	local otherFancy = self:GetFancyItem(carbineItem)
	
	return otherFancy.cmpStr == fancyItem.cmpStr
end

function MrFancyPants:GetFancyItemMatch(fancyItem, otherFancy)
	return fancyItem.slot == otherFancy.slot and fancyItem.name == otherFancy.name and otherFancy.cmpStr == fancyItem.cmpStr
end

function MrFancyPants:GetEquippedItemForSlot(slot)
	local player = GameLib.GetPlayerUnit()
	if player == nil then return nil end
	
	local equipped = player:GetEquippedItems()
	if equipped == nil then return nil end
	
	for key,item in pairs(equipped) do
		--Print(type(item))
		if type(item) == "userdata" then
			if slot == item:GetSlot() then return item end
		end
	end
end

function MrFancyPants:GetItemIsInSet(item, set)
	if set == nil or item == nil then return false end
	
	if type(item) ~= "userdata" then return false end
	
	local slot = item:GetSlot()
	
	if not set.usedSlots[slot] then return false end
	
	if not set.items[slot] then return false end
	
	return self:GetItemIsFancyItem(item, set.items[slot])
end

function MrFancyPants:GetIsSlotSatisfied(slot)
	if self.currentSet == nil then return true end
	
	if not self.currentSet.usedSlots[slot] then return true end
	
	if not self.currentSet.items[slot] then return true end
	
	local slotItem = self:GetEquippedItemForSlot(slot)
	if slotItem == nil then return false end
	
	return self:GetItemIsFancyItem(slotItem, self.currentSet.items[slot])
end

function MrFancyPants:GetHasUnequippedItems()
	if self.currentSet == nil then return false end
	
	local player = GameLib.GetPlayerUnit()
	if player == nil then
		return false
	end
	
	local inv = player:GetInventoryItems()
	if inv == nil then
		return false
	end
	
	for i=0,25 do
		if self:GetIsSlotSatisfied(i) == false then
			for key,item in pairs(inv) do
				if item ~= null then
					local inbag = item.itemInBag
					
					if type(inbag) == "userdata" and inbag:CanEquip() and inbag:GetSlot() == i then
						if self:GetItemIsFancyItem(inbag, self.currentSet.items[i]) then return true end 
					end
				end
			end
		end
	end
	
	return false
end

function MrFancyPants:CheckShouldEquipItem(item)
	if self.currentSet == nil or item == nil then return false end	
	if item:CanEquip() == false then return false end
	
	local slot = item:GetSlot()

	if self:GetIsSlotSatisfied(slot) then return false end
	
	return self:GetItemIsFancyItem(item, self.currentSet.items[slot])
end

-------------------------------------------------------------------------
-- Set Functions
-------------------------------------------------------------------------

function MrFancyPants:GetSetFromLAS(lasIndex)
	if self.db == nil or self.db.las == nil then return nil end
	
	return self.db.sets[self.db.las[lasIndex]];
end

function MrFancyPants:SetCurrentSet(set)
	self.neededBag = nil

	if set ~= nil and type(set) == "string" then
		set = self.db.sets[set]
	end
	
	self.currentSet = set
	self:SetInventorySorting()
	self:UpdateCurrentDisplay();
	
	self.neededBag = nil
	
	if self.currentSet ~= nil and self.currentSet.costumeSlot ~= nil then
		CostumesLib.SetCostumeIndex(self.currentSet.costumeSlot)
	end
end

function MrFancyPants:GenerateUniqueSetName(desiredSetName)
	if self.db.sets[desiredSetName] == nil then return desiredSetName end
	
	for i=1,100 do
		if self.db.sets[desiredSetName..i] == nil then return desiredSetName..i end
	end
	
	return nil
end

function MrFancyPants:EquipSetWithLAS(slot, setName)
	if self.db == nil or self.db.las == nil then return end

	self.db.las[slot] = setName
end

-------------------------------------------------------------------------
-- Sorting Functions
-------------------------------------------------------------------------

function MrFancyPants:SetInventorySorting()
	local vendor = Apollo.GetAddon("Vendor")
	local player = GameLib.GetPlayerUnit()

	local needsBag = (player and not player:IsInCombat()) and
					(not vendor or not vendor.wndVendor or not vendor.wndVendor:IsShown()) and
						self:GetHasUnequippedItems()
	
	if self.neededBag ~= nil and needsBag == self.neededBag then return end
	
	self.neededBag = needsBag
	
	if needsBag then
		--Print("Needs the bag, baby!")
		self.bag:SetAnchorOffsets(2, 2, -2, -2)
		self.bag:SetSort(true)
		self.bag:SetItemSortComparer(self.SortItemBySet)
		
		self.quickBagContainer:Show(true, false);
		self.quickBag:SetSort(true)
		self.quickBag:SetItemSortComparer(self.SortItemBySet)
		
		self:SetQuickSwapHeight(130)
		
	else
		self.bag:SetAnchorOffsets(999999, 9999999, 9999999, 999999)
		
		self.bag:SetSort(false)
	end
	
	if needsBag and not self.quickList:IsVisible() then
		self.quickBagContainer:Show(true, false);
		self.quickBag:SetSort(true)
		self.quickBag:SetItemSortComparer(self.SortItemBySet)
		
		self:SetQuickSwapHeight(130)
	else
		self.quickBag:SetSort(false)
		self:SetQuickSwapHeight(24)
		
		self.quickBagContainer:Show(false, false);
	end
	
	self:RedrawQuickSwap()
end

function MrFancyPants.SortItemBySet(itemLeft, itemRight)
	local fancy = Apollo.GetAddon("MrFancyPants")
	if fancy == nil then
		-- return 0
	end
	
	if itemLeft == itemRight then 
		return 0 
	end
	
	local leftInSet = fancy:CheckShouldEquipItem(itemLeft)
	local rightInSet = fancy:CheckShouldEquipItem(itemRight)
	
	if leftInSet and not rightInSet then
		return -1
	end
	
	if rightInSet and not leftInSet then
		return 1
	end
	
	if itemLeft == nil then
		return -1
	end
	
	if itemRight == nil then
		return 1
	end
	
  	local strLeftName = itemLeft:GetName()
  	local strRightName = itemRight:GetName()
 	if strLeftName < strRightName then
    	return -1
  	end
  	if strLeftName > strRightName then
    	return 1
  	end
  	
  	return 0
end

-----------------------------------------------------------------------------------------------
-- MrFancyPantsForm Set Control Functions
-----------------------------------------------------------------------------------------------

function MrFancyPants:GetSetDisplay(setName, list)
	if list == nil then return end
	
	local currentSets = list:GetChildren()
	
	for i,k in pairs(currentSets) do
		local btn = k:FindChild("EquipmentSetButton")
		if btn:GetText() == setName then
			return k
		end
	end
	
	return self:AddSetDisplay(setName, list)
end

function MrFancyPants:GetSetFromDisplay(setDisplay)
	if setDisplay == nil then return nil end
	if self.db == nil or self.db.sets == nil then return end
	
	local setName = setDisplay:FindChild("EquipmentSetButton"):GetText()
	
	if setName == nil then return nil end
	
	for i,k in pairs(self.db.sets) do
		if k.name == setName then
			return k
		end
	end
	
	return nil
end

function MrFancyPants:AddSetDisplay(setName, list)
	local setDisplay
	if list == self.setList then
		setDisplay = Apollo.LoadForm(self.xmlDoc, "EquipmentSetForm", list, self)
	else
		setDisplay = Apollo.LoadForm(self.xmlDoc, "QuickSwapSetForm", list, self)
	end

	local button = setDisplay:FindChild("EquipmentSetButton")
	button:SetText(setName)
	
	return setDisplay
end

function MrFancyPants:UpdateAvailableSets()
	if self.db == nil or self.db.sets == nil then return end
	
	-- Easier to just rebuild from scratch when needed
	self.setList:DestroyChildren()
	
	for i,k in pairs(self.db.sets) do
		if k ~= nil then
			self:GetSetDisplay(k.name, self.setList)
		end
	end
	
	self.setList:ArrangeChildrenVert()
	
end

function MrFancyPants:RenameCurrentSet(newName)
	if self.currentSet == nil then return end
	
	if self.db.sets.newName ~= nil then
		Apollo.AddAddonErrorText("Could not rename current set, set named "..newName.." already exists!")
	end
	
	self.db.sets[self.currentSet.name] = nil
	
	for i=1,5 do
		if self.db.las[i] == self.currentSet.name then
			self.db.las[i] = newName
		end
	end
	
	self.currentSet.name = newName
	self.db.sets[newName]= self.currentSet
	self:UpdateCurrentDisplay()
	self:UpdateAvailableSets()
end

function MrFancyPants:ReplaceCurrentSet()
	if self.currentSet == nil then return end
	
	local player = GameLib.GetPlayerUnit()
	if player == nil then return end
	
	local equipped = player:GetEquippedItems()
	if equipped == nil then return end
	
	if self.currentSet.costumeSlot ~= nil then
		self.currentSet.costumeSlot = CostumesLib.GetCostumeIndex()
	end
	
	self.currentSet.items = {}
	
	for key,item in pairs(equipped) do
		if type(item) == "userdata" and item:GetDetailedInfo().tPrimary.nBagSlots == nil then
			self.currentSet.items[item:GetSlot()] = self:GetFancyItem(item)
		end
	end
	
	--dump(self.currentSet.items)
end

function MrFancyPants:DeleteCurrentSet()
	if self.currentSet == nil then return end
	
	self.db.sets[self.currentSet.name] = nil
	self:SetCurrentSet(nil)
	self:UpdateAvailableSets();
end

-----------------------------------------------------------------------
-- UI Functions
-----------------------------------------------------------------------
function MrFancyPants:SetQuickSwapHeight(nHeight)
	local oLeft, oTop, oRight, oBottom = self.quickSwap:GetAnchorOffsets()
	
	local nTop = oBottom - nHeight;
	
	self.quickSwap:SetAnchorOffsets(oLeft, nTop, oRight, oBottom)
end

function MrFancyPants:UpdateCurrentDisplay()
	if self.currentSet == nil then 
		self.currentDisplay:Show(false,true)
		return 
	end
	self.currentDisplay:Show(true,false)
	
	self.currentDisplay:FindChild("EquippedSetName"):SetText(self.currentSet.name)
	
	local lasOne = self.currentDisplay:FindChild("LASOneCheckbox")
	
	self.currentDisplay:FindChild("LASOneCheckbox"):SetCheck(self.db.las[1] == self.currentSet.name)
	self.currentDisplay:FindChild("LASTwoCheckbox"):SetCheck(self.db.las[2] == self.currentSet.name)
	self.currentDisplay:FindChild("LASThreeCheckbox"):SetCheck(self.db.las[3] == self.currentSet.name)
	self.currentDisplay:FindChild("LASFourCheckbox"):SetCheck(self.db.las[4] == self.currentSet.name)
	self.currentDisplay:FindChild("CostumeCheckbox"):SetCheck(self.currentSet.costumeSlot ~= nil)
	
	self:SetInventorySorting()
end

function MrFancyPants:GetCurrentSetName()
	if self.currentSet == nil then return nil end
	return self.currentSet.name
end

function MrFancyPants:OnCheckLASOne( wndHandler, wndControl, eMouseButton )
	self:EquipSetWithLAS(1, self:GetCurrentSetName())
end

function MrFancyPants:OnCheckLASTwo( wndHandler, wndControl, eMouseButton )
	self:EquipSetWithLAS(2, self:GetCurrentSetName())
end


function MrFancyPants:OnCheckLASThree( wndHandler, wndControl, eMouseButton )
	self:EquipSetWithLAS(3, self:GetCurrentSetName())
end

function MrFancyPants:OnCheckLASFour( wndHandler, wndControl, eMouseButton )
	self:EquipSetWithLAS(4, self:GetCurrentSetName())
end

function MrFancyPants:OnUncheckLASOne( wndHandler, wndControl, eMouseButton )
	self:EquipSetWithLAS(1, nil)
end

function MrFancyPants:OnUncheckLASTwo( wndHandler, wndControl, eMouseButton )
	self:EquipSetWithLAS(2, nil)
end

function MrFancyPants:OnUncheckLASThree( wndHandler, wndControl, eMouseButton )
	self:EquipSetWithLAS(3, nil)
end

function MrFancyPants:OnUncheckLASFour( wndHandler, wndControl, eMouseButton )
	self:EquipSetWithLAS(4, nil)
end

function MrFancyPants:OnCostumeChecked( wndHandler, wndControl, eMouseButton )
	if self.currentSet == nil then return end
	self.currentSet.costumeSlot = CostumesLib.GetCostumeIndex()
end

function MrFancyPants:OnCostumeUnchecked( wndHandler, wndControl, eMouseButton )
	if self.currentSet == nil then return end
	self.currentSet.costumeSlot = nil
end

function MrFancyPants:OnDeleteCurrentSet( wndHandler, wndControl, eMouseButton )
	self.wndConfirmSave:Close()
	self.wndRename:Close()
	self.wndSlots:Close()
	
	self.wndConfirmDelete:FindChild("AreYouSureText"):SetText("Are you sure you want to delete "..self.currentSet.name.."?")
	self.wndConfirmDelete:Invoke()
end

function MrFancyPants:OnSaveCurrentSet( wndHandler, wndControl, eMouseButton )
	self.wndConfirmDelete:Close()
	self.wndRename:Close()	
	self.wndSlots:Close()
	
	if self.currentSet ~= nil and self.currentSet.name ~= nil then
		self.wndConfirmSave:FindChild("AreYouSureText"):SetText("Are you sure you want to replace the contents of "..self.currentSet.name.." with your currently equipped gear?")
		self.wndConfirmSave:Invoke()
	end
end

function MrFancyPants:OnRenameCurrentSet( wndHandler, wndControl, eMouseButton )
	self.wndConfirmSave:Close()
	self.wndConfirmDelete:Close()
	
	self.wndRename:FindChild("OldNameText"):SetText(self.currentSet.name)
	self.wndRename:FindChild("NewNameEditBox"):SetText(self.currentSet.name)
	
	self.wndRename:Invoke()
end

function MrFancyPants:OnSetUsedSlots(wndHandler, wndControl, eMouseButton)
	self.wndConfirmSave:Close()
	self.wndConfirmDelete:Close()
	self.wndRename:Close()
	
	self.wndSlots:FindChild("SetLabel"):SetText(self.currentSet.name .. " Used Slots")
	
	self.wndSlots:FindChild("ChestConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[0])
	self.wndSlots:FindChild("LegsConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[1])
	self.wndSlots:FindChild("HeadConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[2])
	self.wndSlots:FindChild("ShoulderConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[3])
	self.wndSlots:FindChild("FeetConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[4])
	self.wndSlots:FindChild("HandConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[5])
	self.wndSlots:FindChild("ToolSlotConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[6])
	self.wndSlots:FindChild("WeaponAttachmentConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[7])
	self.wndSlots:FindChild("SupportSystemConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[8])
	self.wndSlots:FindChild("AugmentSlotConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[9])
	self.wndSlots:FindChild("ImplantSlotConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[10])
	self.wndSlots:FindChild("GadgetConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[11])
	self.wndSlots:FindChild("ShieldConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[15])
	self.wndSlots:FindChild("WeaponConfig"):FindChild("CheckBox"):SetCheck(self.currentSet.usedSlots[16])
	
	self.wndSlots:Invoke()
end

function MrFancyPants:OnToggleConfigButton( wndHandler, wndControl, eMouseButton )
	self.config:Invoke()
end

function MrFancyPants:OnMainWindowMoved( wndHandler, wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom )
	if self.db ~= nil then
		local left, top, right, bottom = self.wndMain:GetAnchorOffsets()	
		
		self.db.mainPosition = {}
		
		self.db.mainPosition.left = left
		self.db.mainPosition.top = top
		self.db.mainPosition.right = right
		self.db.mainPosition.bottom = bottom 
	end
end

-----------------------------------------------------------------------------------------------
-- MrFancyPantsForm Functions
-----------------------------------------------------------------------------------------------
function MrFancyPants:OnCreateNewSet( wndHandler, wndControl, eMouseButton )
	local newSet = deepcopy(setPrototype)
	newSet.name = self:GenerateUniqueSetName(newSet.name)
	
	if newSet.name == nil then
		Apollo.AddAddonErrorText("Could not generate new set, unable to find unique name!")
		return
	end
	
	self.db.sets[newSet.name] = newSet;
	
	self:SetCurrentSet(newSet)
	self:ReplaceCurrentSet()
	--self:UpdateCurrentSet()
	self:UpdateAvailableSets()
	
	-- Print("Created set: "..newSet.name)
end

function MrFancyPants:OnUpdateSorting( wndHandler, wndControl, eMouseButton )
	self:SetInventorySorting()
end

function MrFancyPants:OnGenerateTooltip(wndControl, wndHandler, tType, item)
	--Print("Generating tooltip...")
	if wndControl ~= wndHandler then return end
	wndControl:SetTooltipDoc(nil)
	if item ~= nil then
		local itemEquipped = item:GetEquippedItemForItemType()
		--Print("Actually doing it!")
		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		-- Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = item})
	end
end

function MrFancyPants:OnWindowShow( wndHandler, wndControl )
	if self.wndMain:IsShown() then
		self:SetInventorySorting()
		self:UpdateAvailableSets()
	end
end

function MrFancyPants:OnCloseMainWindow( wndHandler, wndControl, eMouseButton )
	self.wndMain:Close()
end

---------------------------------------------------------------------------------------------------
-- ConfirmSaveWindow Functions
---------------------------------------------------------------------------------------------------

function MrFancyPants:OnConfirmSave( wndHandler, wndControl, eMouseButton )
	self:ReplaceCurrentSet()
	self:SetInventorySorting()
	self.wndConfirmSave:Close()
end

function MrFancyPants:OnCancelSave( wndHandler, wndControl, eMouseButton )
	self.wndConfirmSave:Close()
end

---------------------------------------------------------------------------------------------------
-- EquipmentSetForm Functions
---------------------------------------------------------------------------------------------------

function MrFancyPants:OnSelectEquipmentSet( wndHandler, wndControl, eMouseButton )
	self:SetCurrentSet(wndControl:GetText())
end

---------------------------------------------------------------------------------------------------
-- ConfirmDeleteWindow Functions
---------------------------------------------------------------------------------------------------

function MrFancyPants:OnConfirmDelete( wndHandler, wndControl, eMouseButton )
	self:DeleteCurrentSet()
	self.wndConfirmDelete:Close()
end

function MrFancyPants:OnCancelDelete( wndHandler, wndControl, eMouseButton )
	self.wndConfirmDelete:Close()
end

---------------------------------------------------------------------------------------------------
-- RenameWindow Functions
---------------------------------------------------------------------------------------------------

function MrFancyPants:OnConfirmRename( wndHandler, wndControl, eMouseButton )
	self:RenameCurrentSet(self.wndRename:FindChild("NewNameEditBox"):GetText())
	self:UpdateCurrentDisplay()
	self.wndRename:Close()
end

function MrFancyPants:OnCancelRename( wndHandler, wndControl, eMouseButton )
	self.wndRename:Close()
end

---------------------------------------------------------------------------------------------------
-- QuickSwapForm Functions
---------------------------------------------------------------------------------------------------

function MrFancyPants:OnQuickSwapSetLeftBtn( wndHandler, wndControl, eMouseButton )
	AbilityBook.PrevSpec()
end



function MrFancyPants:OnQuickSwapSetRightBtn( wndHandler, wndControl, eMouseButton )
	AbilityBook.NextSpec()
end

function MrFancyPants:RedrawQuickSwap()
	if self.db.killQuickSwap then
		self.quickSwap:Show(false);
		return
	end	
	
	self.quickSwap:Show(true)
	
	if self.currentSet ~= nil then
		self.quickSwap:FindChild("SetName"):SetText(AbilityBook.GetCurrentSpec()..": "..self.currentSet.name)
	else
		self.quickSwap:FindChild("SetName"):SetText(AbilityBook.GetCurrentSpec()..": NONE")
	end
	
	if self.db.quickSwapSize == nil then
		self.db.quickSwapSize = 40
	end
	
	self.quickSwap:FindChild("BagContainer"):SetAnchorOffsets(self.db.quickSwapSize * -1,-27 - (self.db.quickSwapSize*2),self.db.quickSwapSize,-27)
	
	--[[if not self.lastSwapWasLAS and self.currentSet ~= nil and self.currentSet.name ~= nil then
		self.quickSwap:FindChild("SetName"):SetText(self.currentSet.name);
	else
		self.quickSwap:FindChild("SetName"):SetText("LAS: "..AbilityBook.GetCurrentSpec());
	end
	]]
end

function MrFancyPants:OnSpecChanged(newSpecIndex, specError)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	
	local desiredSet = self:GetSetFromLAS(newSpecIndex)
	--Print("Desired set: "..tostring(desiredSet).." from index "..newSpecIndex)
	if desiredSet ~= nil then
		self:SetCurrentSet(desiredSet)
		self.lastSwapWasLAS = true
	end
	
	self:SetInventorySorting()
end

function MrFancyPants:OnQuickSwapMoved( wndHandler, wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom )
	if self.db ~= nil then
		local left, top, right, bottom = self.quickSwap:GetAnchorOffsets()	
		
		self.db.quickPosition = {}
		
		self.db.quickPosition.left = left
		self.db.quickPosition.top = top
		self.db.quickPosition.right = right
		self.db.quickPosition.bottom = bottom 
	end
end

function MrFancyPants:OnMouseDownSetName( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	--Print(tostring(eMouseButton))
	if tostring(eMouseButton) == "1" then
		--Print("Should show");
		--self.wndMain:Invoke()
		--self.wndConfirmSave:Show(true)
		
		self:OnSaveCurrentSet( wndHandler, wndControl, eMouseButton )
		
	else
		self:DrawQuickList(not self.quickList:IsVisible())
	end
end

---------------------------------------------------------------------------------------------------
-- MrFancyPantsConfigForm Functions
---------------------------------------------------------------------------------------------------

function MrFancyPants:OnCloseConfigWindow( wndHandler, wndControl, eMouseButton )
	self.config:Show(false, false)
end

function MrFancyPants:OnCheckQuickSwapOption( wndHandler, wndControl, eMouseButton )
	if self.db == nil then return end
	
	self.db.killQuickSwap = false
	
	self:RedrawQuickSwap()
end

function MrFancyPants:OnUncheckQuickSwapOption( wndHandler, wndControl, eMouseButton )
	if self.db == nil then return end
	
	self.db.killQuickSwap = true
	
	self:RedrawQuickSwap()
end

function MrFancyPants:OnShowConfigWindow( wndHandler, wndControl )
	if self.db == nil then return end
	
	if self.db.quickSwapSize == nil then
		self.db.quickSwapSize = 40
	end
	
	self.config:FindChild("QuickSwapCheckBox"):SetCheck(not self.db.killQuickSwap)
	self.config:FindChild("QuickIconSizeEditBox"):SetText(self.db.quickSwapSize)
	self.config:FindChild("QuickIconSizeSlider")
end

function MrFancyPants:OnOptionsSliderChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.db.quickSwapSize = fNewValue
	
	self.config:FindChild("QuickIconSizeEditBox"):SetText(self.db.quickSwapSize)
	
	self:RedrawQuickSwap()
end

---------------------------------------------------------------------------------------------------
-- QuickSwapSetForm Functions
---------------------------------------------------------------------------------------------------

function MrFancyPants:OnSelectedQuickSwapOption( wndHandler, wndControl, eMouseButton )
	local selectedOption = wndControl:GetText()
	
	if selectedOption == self.textMainWindow then
		self.wndMain:Show(true)
	elseif selectedOption == self.config then
		self.config:Show(true)
	else
		self:SetCurrentSet(selectedOption)
	end
	
	self:DrawQuickList(false)
end

---------------------------------------------------------------------------------------------------
-- QuickSwapSetList Functions
---------------------------------------------------------------------------------------------------


function MrFancyPants:DrawQuickList(bShouldDraw)
	if bShouldDraw then
		local left, top, right, bottom = self.quickSwap:GetAnchorOffsets()	
			
		self.quickList:SetAnchorOffsets(left - 27, bottom - 180, right + 27, bottom - 30)
		
		-- Easier to just rebuild from scratch when needed
		self.quickList:FindChild("SetList"):DestroyChildren()
		
		for i,k in pairs(self.db.sets) do
			if k ~= nil then
				self:GetSetDisplay(k.name, self.quickList:FindChild("SetList"))
			end
		end
		
		self:GetSetDisplay(self.textMainWindow, self.quickList:FindChild("SetList"))
		--self:GetSetDisplay(self.textConfig, self.quickList:FindChild("SetList"))
		
		self.quickList:FindChild("SetList"):ArrangeChildrenVert()
		
		self.quickList:Show(true)
	else
		self.quickList:Show(false)
	end
	
	self:SetInventorySorting()
end

function MrFancyPants:OnQuickSwapSetListMouseWheel( wndHandler, wndControl, nLastRelativeMouseX, nLastRelativeMouseY, fScrollAmount, bConsumeMouseWheel )
	
end

---------------------------------------------------------------------------------------------------
-- EquipmentSlotForm Functions
---------------------------------------------------------------------------------------------------

function MrFancyPants:ToggleEquipmentSlotInCurrentSet(slot, shouldUse)
	if self.currentSet == nil then return end
	
	self.currentSet.usedSlots[slot] = shouldUse
	self.neededBag = nil
	self:SetInventorySorting()
end

function MrFancyPants:OnCloseSlotConfigWindow( wndHandler, wndControl, eMouseButton )
	self.wndSlots:Show(false, false)
end

function MrFancyPants:OnEnableChestSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(0, true)
end

function MrFancyPants:OnDisableChestSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(0, false)
end

function MrFancyPants:OnEnableLegsSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(1, true)
end

function MrFancyPants:OnDisableLegsSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(1, false)
end

function MrFancyPants:OnEnableHeadSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(2, true)
end

function MrFancyPants:OnDisableHeadSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(2, false)
end

function MrFancyPants:OnEnableShoulderSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(3, true)
end

function MrFancyPants:OnDisableShoulderSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(3, false)
end

function MrFancyPants:OnEnableFeetSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(4, true)
end

function MrFancyPants:OnDisableFeetSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(4, false)
end

function MrFancyPants:OnEnableHandSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(5, true)
end

function MrFancyPants:OnDisableHandSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(5, false)
end

function MrFancyPants:OnEnableShieldSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(15, true)
end

function MrFancyPants:OnDisableShieldtSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(15, false)
end

function MrFancyPants:OnEnableWeaponSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(16, true)
end

function MrFancyPants:OnDisableWeaponSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(16, false)
end

function MrFancyPants:OnEnableWeaponAttachmentSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(7, true)
end

function MrFancyPants:OnDisableWeaponAttachmentSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(7, false)
end

function MrFancyPants:OnEnableSupportSystemSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(8, true)
end

function MrFancyPants:OnDisableSupportSystemSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(8, false)
end

function MrFancyPants:OnEnableAugmentSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(9, true)
end

function MrFancyPants:OnDisableAugmentSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(9, false)
end

function MrFancyPants:OnEnableImplantSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(10, true)
end

function MrFancyPants:OnDisableImplantSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(10, false)
end

function MrFancyPants:OnEnableGadgetSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(11, true)
end

function MrFancyPants:OnDisableGadgetSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(11, false)
end

function MrFancyPants:OnEnableToolSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(6, true)
end

function MrFancyPants:OnDisableToolSlot( wndHandler, wndControl, eMouseButton )
	self:ToggleEquipmentSlotInCurrentSet(0, false)
end

----------------------------------------------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------------------------------------------
function MrFancyPants:GetItemSetString(item)
	--Print("Checking item tooltip")
	if type(item) ~= "userdata" then return nil end
	
	--Print("Is userdata")
	
	if self.db == nil or self.db.sets == nil then return nil end
	
	local itemString = nil
	local itemSlot = item:GetSlot()
	
	for key,set in pairs(self.db.sets) do
		if self:GetItemIsInSet(item, set) then
			if itemString == nil then
				itemString = set.name
			else
				itemString = itemString..", "..set.name
			end
		end
	end
	
	return itemString
end

function MrFancyPants:ItemToolTip(wndControl, item, bStuff, nCount)
	local this = Apollo.GetAddon("MrFancyPants")
	--Print("Found addon? "..type(this))
	wndControl:SetTooltipDoc(nil)
	local wndTooltip, wndTooltipComp = this.carbineItemForm(this, wndControl, item, bStuff, nCount)
	
	if wndTooltip and bStuff.bPermanent ~= true then
		local setString = this:GetItemSetString(item)
		
		if setString ~= nil then
			local tooltipForm = Apollo.LoadForm(this.xmlDoc, "SetTooltipForm", wndTooltip:FindChild("Items"), this)
			tooltipForm:FindChild("TooltipText"):SetText("SETS: "..setString)
			wndTooltip:FindChild("Items"):ArrangeChildrenVert()
			-- Print("Added form?"..type(tooltipForm ))
			
			--Print(type(item))
			
			wndTooltip:Move(0, 0, wndTooltip:GetWidth(), wndTooltip:GetHeight() + 35)
			--local wndTypeTxt = wndTooltip:FindChild("ItemTooltip_Header_Types")
			--wndTypeTxt:SetText(wndTypeTxt:GetText() .. "\nSETS: ")
		end
	end
	
	return wndTooltip, wndTooltipComp
end

---------------------------------------------------------------------------------------------------
-- WelcomeScreen Functions
---------------------------------------------------------------------------------------------------

function MrFancyPants:OnCloseWelcomeScreen( wndHandler, wndControl, eMouseButton )
	self.wndWelcome:Show(false, true)
end

----------------------------------------------------------------------------
-- MrFancyPants Instance
-----------------------------------------------------------------------------------------------
local MrFancyPantsInst = MrFancyPants:new()
MrFancyPantsInst:Init()
