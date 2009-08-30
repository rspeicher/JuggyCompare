-- ---------------------
-- Locals
-- ---------------------

-- Only copy epic and legendary loots
local loot_cutoff = 4

-- ---------------------
-- AddOn Declaration
-- ---------------------

local mod = LibStub("AceAddon-3.0"):NewAddon("JuggyAttendance", "AceConsole-3.0")

function mod:OnInitialize()
	self:RegisterChatCommand('att', 'CopyAttendance')
	self:RegisterChatCommand('lc',  'CopyLoot')
end

function mod:OnEnable()
end

function mod:OnDisable()
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
-- Methods
-- ---------------------

function mod:CopyAttendance(method)
	method = method == "" and "1" or method
	
	local str = ""
	local sep = method == "1" and "\n" or ','
	
	for i=1, GetNumRaidMembers() do
		str = str .. UnitName('raid' .. i) .. sep
	end
	
	--str = "Tsigo\nBaud\nSebudai\nSouai\nDuskshadow"
	
	if method == "1" then
		currentText = string.gsub(str, "\n$", '')
		StaticPopup_Show("JuggyCopyDialog")
	else
		currentText = string.gsub(str, ',$', '')
		StaticPopup_Show("JuggyCopyDialog")
	end
end

function mod:CopyLoot(method)
	method = method == "" and "1" or method
	
	local str = ""
	
	for i=1, GetNumLootItems() do
		local _, name, _, rarity = GetLootSlotInfo(i)

		if (rarity >= loot_cutoff and not string.find(name, "^Emblem of") and not string.find(name, "^(Plans|Pattern)")) then
			local _, itemId = strsplit(":", GetLootSlotLink(i))
			if method == "1" then
				str = str .. " - " .. name .. "|" .. itemId .. "\n"
			else
				str = str .. itemId .. "|"
			end
		end
	end
	
	--str = " - Item|12345\n - Item2|54321"
	
	if (str ~= "") then
		if method == "1" then
			currentText = string.gsub(str, "\n$", '')
			StaticPopup_Show("JuggyCopyDialog")
		else
			currentText = string.gsub(str, '\|$', '')
			StaticPopup_Show("JuggyCopyDialog")
		end
	end
end