-- ---------------------
-- Locals
-- ---------------------

-- Debugging
local dbg = false

-- Only copy epic and legendary loots
local rarity_cutoff = 4

-- Only copy item level 80 or higher loots (Trophy of the Crusade is 80)
--local level_cutoff = 80

-- Stores alt names mapped to mains
local altMap = {}

local UnitInRaid = _G.UnitInRaid

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

local mod = LibStub("AceAddon-3.0"):NewAddon("JuggyAttendance", "AceConsole-3.0", "AceEvent-3.0")

function mod:OnInitialize()
	self:RegisterChatCommand('att', 'CopyAttendance')
	self:RegisterChatCommand('lc',  'CopyLoot')
end

function mod:OnEnable()
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
end

function mod:OnDisable()
end

function mod:Debug(...)
	if not dbg then return end
	self:Print(...)
end

-- ---------------------
-- Methods
-- ---------------------

function mod:GUILD_ROSTER_UPDATE(event, arg1)
	local unregister = false
	for i=1, GetNumGuildMembers(true) do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
		if (rank == 'Alt' or rank == 'Officer') and note ~= '' then
			altMap[name] = note
			unregister = true
		end
	end
	
	-- Note: Wanted to use #altMap > 0, but that didn't work???
	if unregister then
		self:UnregisterEvent('GUILD_ROSTER_UPDATE')
	end
end

function mod:CopyAttendance(method)
	method = method == "" and "1" or method
	
	local str = ""
	local sep = method == "1" and "," or "\n"
	
	for i=1, GetNumRaidMembers() do
		local name = UnitName('raid' .. i)
		
		-- If it's an alt, use the main's name
		if altMap[name] ~= nil then
			name = altMap[name]
		end
		
		str = str .. name .. sep
	end
	
	if str ~= "" then
		currentText = string.gsub(str, sep .. "$", '')
		StaticPopup_Show("JuggyCopyDialog")
	end
end

function mod:CopyLoot()
	local str = ""
	
	for i=1, GetNumLootItems() do
		-- Get loot info for each loot slot
		local _, name, _, rarity = GetLootSlotInfo(i)
		if dbg or rarity >= rarity_cutoff then
			local link = GetLootSlotLink(i)
			if link then
				local _, itemId = strsplit(":", link)
				str = str .. " - " .. name .. "|" .. itemId .. "\n"
			end
		end
	end
	
	if str ~= "" then
		currentText = string.gsub(str, "\n$", '')
		StaticPopup_Show("JuggyCopyDialog")
	end
end