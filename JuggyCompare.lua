-------------------------------------------------------------------------------
-- Locals																	 --
-------------------------------------------------------------------------------

-- Takes the JuggyCompare_Data tables and stores it in a format we want
local data = {}

-- This table value gets wiped out later, so store it locally
local updated = JuggyCompare_Data.updated

-- This addon's public now, so only accept comparison tells from very specific people!
local officers = {
	'tsigo', 'kamien',
	'sebudai', 
	'souai', 
	'duskshadow', 
	'baud', 'baudz',
	'ruhntar', 'parawon'
}

local pairs, getmetatable, setmetatable = _G.pairs, _G.getmetatable, _G.setmetatable

-- Copy a table value to a new table
local function tcopy(t)
	local new = {}
	for key, value in pairs(t) do
	  new[ key ] = value
	end
	local m = getmetatable(t)
	if m then setmetatable(new,m) end
	return new
end

-------------------------------------------------------------------------------
-- AddOn Declaration														 --
-------------------------------------------------------------------------------

local mod = LibStub("AceAddon-3.0"):NewAddon("JuggyCompare", "AceConsole-3.0", "AceEvent-3.0")

function mod:OnInitialize()
	self:RegisterChatCommand('jcomp', 'PrintInfo')
	self:RegisterChatCommand('compare', 'OnCompare')

	self.display = {} -- Temporary table that gets sorted and printed
	
	JuggyCompare_Data.updated = nil
	for _,t in pairs(JuggyCompare_Data) do
		local v = {
			name	 = t.NAME,
			raids_30 = t.RAIDS_30,
			raids_90 = t.RAIDS_90,
			raids_lt = t.RAIDS_LT,
			lastloot = t.LASTLOOT,
			lf	   = t.LF,
			slf	  = t.SLF,
			bislf	= t.BISLF,
			sortlf   = t.LF,
		}
		table.insert(data, v)
	end
end

function mod:OnEnable()
	self.display = {}
	self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
end

function mod:OnDisable()
	self.display = nil
	self:UnregisterEvent("CHAT_MSG_WHISPER")
end

function mod:PrintInfo(args)
	if args == "" or args == 'updated' then
		self:Print("Data updated: " .. updated)
	end
end

-------------------------------------------------------------------------------
-- Events																	 --
-------------------------------------------------------------------------------

function mod:OnCompare(msg)
	msg = "compare " .. msg
	self:OnWhisper("CHAT_MSG_WHISPER", msg, UnitName("player"))
end

function mod:OnWhisper(event, msg, sender)
	self.display = {}
	
	if not self:ValidateSender(sender) then return end
	
	if string.find(msg, '^compare') then
		local args = string.gsub(msg, "^compare ", "")
		
		local list = old_strsplit(",%s*", args)
		
		if table.getn(list) == 0 then return end
		
		-- Print the header
		local _,_, itemId = string.find(list[1], "item:(%d+):")
		if itemId == nil and string.find(list[1], "^%[(.+)%]$") then
			itemId = list[1]
		end
		
		if itemId ~= nil then
			self:PrintHeader(sender, itemId)
			list[1] = nil
		else
			self:PrintHeader(sender)
		end

		-- Populate self.display table with member data		
		for k,v in pairs(list) do
			self:ParseArgument(v)
		end

		-- Sort and print the display rows
		self:DoCompare()
	end
end

-------------------------------------------------------------------------------
-- AddOn Methods															 --
-------------------------------------------------------------------------------

function mod:PrintHeader(sender, item)
	local str = "--"
	
	-- Insert the sender into the header
	sender = (sender == nil) and UnitName("player") or sender
	str = str .. string.format(" %s -", sender)
	
	-- Insert the item name into the header
	local itemName = nil
	if item ~= nil then
		if string.find(item, "^%[(.+)%]$") then
			itemName = select(3, item:find("^%[(.+)%]$"))
		else
			itemName = GetItemInfo(item)
		end
		
		if itemName ~= nil then
			str = str .. string.format(" %s -", itemName)
		end
	end
	
	str = pad(str, 60, "-")
	self:Message(str)
end

function mod:ParseArgument(arg)
	local split = {}
	-- Split by words; [1] = name, [[2] = telltype]
	string.gsub(arg, "(%w+)", function(w) table.insert(split, w) end)
	if table.getn(split) == 0 then return end
	
	local member = self:PlayerExists(split[1])
	
	if member >= 0 then
		local row = tcopy(data[member])
		
		if split[2] ~= nil then
			row.telltype = string.upper(split[2])
			
			if row.telltype == "BES" or row.telltype == "BIS" or row.telltype == "BISROT" then
				row.sortlf = tonumber(row.bislf) - 500	-- Sort BiS before everything
			elseif row.telltype == "ROT" then
				row.sortlf = tonumber(row.lf) + 500		-- Sort rot after normal
			elseif row.telltype == "SIT" then
				row.sortlf = tonumber(row.slf) + 999	-- Sort sit after rot
			elseif row.telltype == "NOR" then
				row.sortlf = tonumber(row.lf)			-- Normal is normal!
				row.telltype = nil
			else
				row.sortlf = tonumber(row.lf) + 1500	-- ?
			end
		else
			row.sortlf = row.lf
			row.telltype = nil
		end
		
		table.insert(self.display, row)
	else
		-- Insert an error'd data[member] to be output later, using a high LF so the sort doesn't get messed up
		table.insert(self.display, { name = split[1], err = "Not found", lf = "0.00", sortlf = 99999 })
	end
end

function mod:DoCompare()
	table.sort(self.display, function(a, b) return tonumber(a.sortlf) < tonumber(b.sortlf) end)
	
	for _, row in pairs(self.display) do
		local str = nil
		
		if type(row) ~= "table" then return end
		if row.lf == nil then return end
		
		if row.err == nil then
			str = pad(row.name, 15) ..
				pad(row.raids_30, -4) ..
				pad(row.lastloot, -13) ..
				""
				
			if row.telltype == "BES" or row.telltype == "BIS" then
				str = str .. pad(row.bislf, -8)
				str = str .. "	BiS"
			elseif row.telltype == "BISROT" then
				str = str .. pad(row.bislf, -8)
				str = str .. "	BiS ROT"
			elseif row.telltype == "SIT" then
				str = str .. pad(row.slf, -8)
				str = str .. "	SIT"
			else
				str = str .. pad(row.lf, -8)
				
				-- Show ROT/FERAL/etc.?
				if row.telltype ~= nil then
					str = str .. "	" .. row.telltype
				end
			end
		else
			str = pad(row.name, 15) .. row.err
		end

		self:Message(str)
	end
end

function mod:PlayerExists(player)
	for i=1, #data do
		if string.lower(data[i].name) == string.lower(player) then
			return i
		end
	end
	
	-- Wasn't found in the main table, check nicknames
	for nick, full in pairs(JuggyCompare_Nicks) do
		if string.lower(nick) == string.lower(player) then
			-- Found their nickname, recurse with the full name
			return self:PlayerExists(full)
		end
	end
	
	-- Still no match, attempt to match the start of a string
	-- Must be at least three characters long to check for a match
	if string.len(player) >= 3 then
		for i=1, #data do
			if string.find(string.lower(data[i].name), "^" .. string.lower(player)) then
				return i
			end
		end
	end
	
	return -1
end

function mod:Message(msg)
	SendChatMessage(msg, "OFFICER")
	--self:Print(msg)
end

function mod:ValidateSender(arg1)
	return tcontains(officers, arg1)
end

-------------------------------------------------------------------------------
-- Convenience Functions													 --
-------------------------------------------------------------------------------

-- Check if a table contains a value
function tcontains(tab, value)
	value = string.lower(value)
	for k,v in pairs(tab) do
		if v == value then
			return true
		end
	end
	
	return false
end

-- Justify a string
--   s: string to justify
--   width: width to justify to (+ve means right-justify; negative
--	 means left-justify)
--   [padder]: string to pad with (" " if omitted)
-- returns
--   s: justified string
function pad(s, width, padder)
  padder = string.rep(padder or " ", math.abs(width))
  if width < 0 then return string.sub(padder .. s, width) end
  return string.sub(s .. padder, 1, width)
end

-- Split text into a list consisting of the strings in text,
-- separated by strings matching delimiter (which may be a pattern). 
-- example: strsplit(",%s*", "Anna, Bob, Charlie,Dolores")
function old_strsplit(delimiter, text)
  local list = {}
  local pos = 1
  if strfind("", delimiter, 1) then -- this would result in endless loops
	error("delimiter matches empty string!")
  end
  while 1 do
	local first, last = strfind(text, delimiter, pos)
	if first then -- found?
	  table.insert(list, strsub(text, pos, first-1))
	  pos = last+1
	else
	  table.insert(list, strsub(text, pos))
	  break
	end
  end
  return list
end