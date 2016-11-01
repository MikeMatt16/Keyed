-- Initialize our Ace3 AddOn
Keyed = LibStub("AceAddon-3.0"):NewAddon("Keyed", "AceConsole-3.0", "AceHook-3.0", "AceComm-3.0")

-- Default Profile
local defaults = {
	profile = {
		MinimapPos = 45,
	},
	factionrealm = {
		["*"] = {
			name = "",
			guid = nil,
			time = 0,
			keystones = {}
		}
	}
}

local KeystoneId = 138019
local prefix = "KEYED_13"
local KeyedName = "|cffd6266cKeyed|r"
local keystoneRequest = "keystones"
local playerKeystoneRequest = "playerkeystone"

function Keyed:OnInitialize()
	-- Register "/keyed" command
	Keyed:RegisterChatCommand("keyed", "Options")
	Keyed:RegisterComm(prefix, "OnCommReceived")
	KeyedFrame:RegisterForDrag("LeftButton")

	-- Load Database
	self.db = LibStub("AceDB-3.0"):New("Keyedv2DB", defaults)
end

function Keyed:OnEnable()
end

function Keyed:OnDisable()
end

function Keyed:Options(input)
	-- Check...
	if self:isempty(input) then
		KeyedFrameKeystoneList_Update(KeyedFrameKeystoneList)
		KeyedFrame:Show()
	else
		local Arguments = self:SplitString(input, ' ')
		if Arguments[1] == "get" then
			if Arguments[2] == "all" then
				self:BroadcastKeystoneRequest()
			else
				self:SendKeystoneRequest(Arguments[2])
			end
		elseif Arguments[1] == "print" and (Arguments[2] == "db" or Arguments[2] == "database") then
				print(KeyedName, "Keystones in database:")
				for uid, entry in pairs(self.db.factionrealm) do
				for i = 1, #entry.keystones do
					print(KeyedName, entry.name, "(" .. i .. "/" .. #entry.keystones .. ")", entry.keystones[i])
					end
			end
		elseif Arguments[1] == "clear" then
			if Arguments[2] == "db" or Arguments[2] == "database" then
				table.wipe(self.db.factionrealm)
				self.db.factionrealm = defaults.factionrealm
				print(KeyedName, "Wiped database...")
				print("  Please reload your UI to continue...")
			else
				self.db.factionrealm[Arguments[2]] = nil
				print(KeyedName, "Wiped", Arguments[2])
			end
		elseif Arguments[1] == "test" then
			print(KeyedName, "Test Scroll Frame!")
			print("  Hide with \"/run TestScrollFrame:Hide()\"")

			TestData = TestData or {}
			table.wipe(TestData)
			for name, entry in pairs(self.db.factionrealm) do
				table.insert(TestData, entry)
			end

			local backdrop = {
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
				tile = true,
				tileSize = 32,
				edgeSize = 32,
				insets = {
					left = 11,
					right = 12,
					top = 12,
					bottom = 11
				}
			}

			TestScrollFrame = CreateFrame("ScrollFrame", "TestScrollFrame", UIParent, "FauxScrollFrameTemplate")
			TestScrollFrame:SetPoint("CENTER")
			TestScrollFrame:SetBackdrop(backdrop)
			TestScrollFrame:SetSize(240, 240)
			TestScrollFrame:SetScript("OnVerticalScroll", function(self, offset) 
				FauxScrollFrame_OnVerticalScroll(self, offset, 240, TestScrollFrame_Update)
			end)

			TestButton1 = CreateFrame("Button", "TestButton1", TestScrollFrame, "KeystoneButtonTemplate")
			TestButton1:SetID(1)
			TestButton1:SetPoint("TOP", TestScrollFrame)
			TestButton1Keystone = CreateFrame("Button", "TestButton1Keystone", TestButton1, "KeystoneItemTemplate")
			TestButton1Keystone:SetPoint("RIGHT", TestButton1, 0, -2)
			TestButton1Keystone.link = ""

			for n=2,10,1 do
				local button = CreateFrame("Button", "TestButton" .. n, TestScrollFrame, "KeystoneButtonTemplate")
				button:SetID(n)
				button:SetPoint("TOP", _G["TestButton" .. (n-1)], "BOTTOM")
				local keystone = CreateFrame("Button", "TestButton" .. n .. "Keystone", button, "KeystoneItemTemplate")
				keystone:SetPoint("RIGHT", button, 0, -2)
				keystone.link = ""
			end

			TestScrollFrame_Update()
			TestScrollFrame:Show()
			else
			print(KeyedName, "Incorrect usage...")
		end
	end
end

function TestScrollFrame_Update()
	local dataCount = #TestData
	local button, buttonText, keystone, name
	local entryOffset = FauxScrollFrame_GetOffset(TestScrollFrame)
	local entryIndex
	local count = dataCount
	if dataCount > 10 then
		count = 10
	end
	for i=1, 10,1 do
		entryIndex = entryOffset + i
		button = _G["TestButton" .. i]
		button.entryIndex = entryIndex
		if(TestData[entryIndex]) then
			name = "Entry: " .. tostring(TestData[entryIndex].name)
			buttonText = _G["TestButton" .. i .. "Name"]
			keystone = _G["TestButton" .. i .. "Keystone"]
			buttonText:SetText(name)
			if #TestData[entryIndex].keystones > 0 then
				keystone.link = TestData[entryIndex].keystones[1]
				keystone:Show()
			else
				keystone:Hide()
			end
		end
		if entryIndex > dataCount then
			button:Hide()
		else
			button:Show()
		end
	end

	FauxScrollFrame_Update(TestScrollFrame, dataCount, 10, 240);
end

function Keyed:SendResponse(playerName, response)
	Keyed:SendCommMessage(prefix, response, "WHISPER", playerName)
end

function Keyed:BroadcastKeystoneRequest()
	print(KeyedName, "Updating keystone database...")
	Keyed:SendCommMessage(prefix, "request;" .. keystoneRequest, "GUILD")
end

function Keyed:SendKeystoneRequest(playerName)
	if playerName then Keyed:SendCommMessage(prefix, "request;" .. keystoneRequest, "WHISPER", playerName) end
end

function Keyed:OnCommReceived (prefix, message, channel, sender)
	-- Prepare
	local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice
	local arguments = self:SplitString(message, ';')
	local keystones = {}
	local time = 0
	local player = ""
	local uid = ""

	-- Handle...
	if arguments[1] == "request" then
		if arguments[2] == keystoneRequest then
			self:SendEntries(sender)		-- Send database contents...
			self:SendKeystones(sender)		-- Send your latest keystones...
		end
	elseif arguments[1] == keystoneRequest then
		player = arguments[2]
		uid = arguments[3]
		time = tonumber(arguments[4])
		for i = 5, #arguments do
			if not self:isempty(arguments[i]) then
				name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(arguments[i])
				if name and link then table.insert(keystones, link) end
			end
		end

		-- Wipe and add...
		if self.db.factionrealm[uid].time < time then
			self.db.factionrealm[uid].time = time
			self.db.factionrealm[uid].name = player
			self.db.factionrealm[uid].uid = uid
			table.wipe(self.db.factionrealm[uid].keystones)
			for i = 1, #keystones do
				table.insert(self.db.factionrealm[uid].keystones, keystones[i])
			end

			-- Update List...
			KeyedFrameKeystoneList_Update(KeyedFrameKeystoneList)
		end
	end
end

function Keyed:SendEntries(target)
	-- Prepare
	local name, realm = UnitName("player")
	local message = ""
	for playerName, entry in pairs(self.db.factionrealm) do
		if playerName ~= name then
			message = keystoneRequest .. ";"  .. entry.name .. ";" .. entry.uid .. ";" .. tostring(entry.time) .. ";"
			for i = 1, #entry.keystones do message = message .. entry.keystones[i] .. ";" end
			self:SendResponse(target, message)
		end
	end
end

function Keyed:SendKeystones(target)
	-- Prepare
	local uid = UnitGUID("player")
	local name = UnitName("player")
	local message = keystoneRequest .. ";" .. name .. ";" .. uid .. ";" .. tostring(GetServerTime()) .. ";"
	local keystones = self:FindKeystones()
	for i = 1, #keystones do
		message = message .. keystones[i] .. ";"
	end
	self:SendResponse(target, message)
end

function Keyed:FindKeystones()
	-- Prepare...
	local texture, count, locked, quality, readable, lootable, link, isFiltered, hasNoValue, itemId
	local keystones = {}
	local slots = {}
	slots[1] = GetContainerNumSlots(0)
	slots[2] = GetContainerNumSlots(1)
	slots[3] = GetContainerNumSlots(2)
	slots[4] = GetContainerNumSlots(3)
	slots[5] = GetContainerNumSlots(5)

	-- Loop through every bag slot...
	for i = 1, #slots do
		for j = 1, slots[i] do
			-- Load Item info...
			texture, count, locked, quality, readable, lootable, link, isFiltered, hasNoValue, itemId = GetContainerItemInfo(i - 1, j)

			-- Check...
			if itemId and itemId == KeystoneId then
				table.insert(keystones, link)
			end
		end
	end

	-- Return
	return keystones
end

function Keyed:SplitString(input, separator)
	local parts = {}
	local theStart = 1
	local theSplitStart, theSplitEnd = string.find(input, separator, theStart)
	while theSplitStart do
		table.insert( parts, string.sub(input, theStart, theSplitStart-1 ) )
		theStart = theSplitEnd + 1
		theSplitStart, theSplitEnd = string.find(input, separator, theStart )
	end
	table.insert(parts, string.sub(input, theStart))
	return parts
end

function Keyed:isempty(s)
	return s == nil or s == ''
end