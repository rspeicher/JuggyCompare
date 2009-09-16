-- ---------------------
-- Locals
-- ---------------------

-- Debugging
local dbg = false

-- Only copy epic and legendary loots
local rarity_cutoff = 4

-- Only copy item level 80 or higher loots (Trophy of the Crusade is 80)
local level_cutoff = 80

-- Stores data about broadcasted loots
local loots = {}

-- Stores data about GUIDs we already copied loot for
local copied = {}

local UnitInRaid = _G.UnitInRaid

-- Clear a table's contents
local function terase(t)
	for i in pairs(t) do t[i] = nil end
end

-- Check if a table contains a value
local function tcontains(t, value)
	if value == nil then return end
	
	for k,v in pairs(t) do
		if v == value or string.lower(v) == string.lower(value) then
			return true
		end
	end
	
	return false
end

-- Copied from Chatter's urlCopy, thanks!
local currentText
StaticPopupDialogs["JuggyCopyDialog"] = {
	text = "Copy",
	button2 = CLOSE,
	hasEditBox = 1,
	hasWideEditBox = 1,
	OnShow = function()
		local editBox = _G[this:GetName().."WideEditBox"]
		if editBox then
			editBox:SetText(currentText)
			editBox:SetFocus()
			editBox:HighlightText(0)
		end
		local button = _G[this:GetName().."Button2"]
		if button then
			button:ClearAllPoints()
			button:SetWidth(200)
			button:SetPoint("CENTER", editBox, "CENTER", 0, -30)
		end
	end,
	EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	maxLetters=1024, -- this otherwise gets cached from other dialogs which caps it at 10..20..30...
}

-- ---------------------
-- AddOn Declaration
-- ---------------------

local mod = LibStub("AceAddon-3.0"):NewAddon("JuggyAttendance", "AceConsole-3.0", "AceComm-3.0", "AceEvent-3.0")

function mod:OnInitialize()
	self:RegisterChatCommand('att', 'CopyAttendance')
	self:RegisterChatCommand('lc',  'CopyLoot')
	
	self.prefix = "jcomp"
end

function mod:OnEnable()
	self:RegisterComm(self.prefix)
	self:RegisterEvent("LOOT_OPENED")
end

function mod:OnDisable()
end

function mod:Debug(...)
	if not dbg then return end
	self:Print(...)
end

-- ---------------------
-- Distributed Looting
-- ---------------------

function mod:OnCommReceived(prefix, msg, distro, sender)
	local guid, itemId = select(3, msg:find("(%w+) (%d+)"))
	
	self:Debug("Comm:", msg, sender)
	
	if guid == nil then return end
	
	-- A table for this GUID already exists, and it wasn't created by this person
	-- Probably means multiple people looted the corpse and broadcasted it, so just 
	-- ignore duplicates
	if loots[guid] ~= nil and loots[guid].source ~= sender then return end
	
	-- If a copied entry for this GUID already exists, it means we copied it and don't 
	-- need to create it again
	if tcontains(copied, guid) then return end
	
	self:Debug("Comm: Processing")
	
	-- Table for this GUID doesn't exist, initialize it, giving credit to the 
	-- first sender
	if loots[guid] == nil then
		loots[guid] = {
			source = sender,
			items  = {}
		}
	end
	
	table.insert(loots[guid].items, itemId)
end

function mod:LOOT_OPENED(event, arg1)
	if not dbg and not UnitInRaid('player') then return end
	
	local guid = self:GetCorpseInfo()
	
	for i=1, GetNumLootItems() do
		-- Get loot info for each loot slot, and broadcast its data if it's an
		-- item we're interested in
		local _, name, _, rarity = GetLootSlotInfo(i)
		-- NOTE: We only do a rarity check here; doing a level check would require extra calls
		if dbg or rarity >= rarity_cutoff then
			local link = GetLootSlotLink(i)
			if link then
				local _, itemId = strsplit(":", link)
				self:SendCommMessage(self.prefix, (guid .. " " .. itemId), "GUILD")
			end
		end
	end
end

function mod:GetCorpseInfo()
	local retval = UnitGUID('target')
	
	-- No GUID, probably means it's a chest
	if retval == nil or retval == '' then
		retval = GetSubZoneText()
	end
	
	-- No SubZoneText, probably means we're in ToC
	if retval == nil or retval == '' then
		retval = GetZoneText()
	end
	
	return retval
end

-- ---------------------
-- Methods
-- ---------------------

function mod:CopyAttendance(method)
	method = method == "" and "1" or method
	
	local str = ""
	local sep = method == "1" and "\n" or ','
	
	for i=1, GetNumRaidMembers() do
		str = str .. UnitName('raid' .. i) .. sep
	end
	
	if str ~= "" then
		if method == "1" then
			currentText = string.gsub(str, "\n$", '')
			StaticPopup_Show("JuggyCopyDialog")
		else
			currentText = string.gsub(str, ',$', '')
			StaticPopup_Show("JuggyCopyDialog")
		end
	end
end

function mod:CopyLoot(method)
	method = method == "" and "1" or method
	
	local str = ""
	
	for guid, vals in pairs(loots) do
		for k, itemId in pairs(vals.items) do
			local name, _, rarity, level = GetItemInfo(itemId)
			-- Make sure the item is high enough quality AND level
			if name and (dbg or (rarity >= rarity_cutoff and level >= level_cutoff)) then
				str = str .. " - " .. name .. "|" .. itemId .. "\n"
			end
		end
		
		-- Only make a note that we copied this loot if it's actually a GUID
		if string.find(guid, "^0x") then
			table.insert(copied, guid)
		end
	end
	
	-- Clear out this loots table since we've got everything we need
	terase(loots)
	
	if str ~= "" then
		if method == "1" then
			currentText = string.gsub(str, "\n$", '')
			StaticPopup_Show("JuggyCopyDialog")
		else
			currentText = string.gsub(str, '\|$', '')
			StaticPopup_Show("JuggyCopyDialog")
		end
	end
end