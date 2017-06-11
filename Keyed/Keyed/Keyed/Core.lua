-- Initialize our Ace3 AddOn
Keyed = LibStub("AceAddon-3.0"):NewAddon("Keyed", "AceConsole-3.0", "AceHook-3.0", "AceComm-3.0")
KEYED_BROADCAST = 0
local L = LibStub("AceLocale-3.0"):GetLocale("Keyed")
local KeystoneId = 138019
local prefix = "KEYED_17"
local KeyedName = "|cffd6266cKeyed|r"
local keystoneRequest = "keystones"
local playerKeystoneRequest = "playerkeystone"

-- Default Profile
local defaults = {
	profile = {
		region = "Americas",
		minimap = {
			hide = false,
		},
	},
	factionrealm = {
		["*"] = {
			name = "",
			guid = nil,
			class = "PALADIN",
			time = 0,
			upgradeRequired = true,
			keystones = {}
		}
	}
}

local keyedLDB = LibStub("LibDataBroker-1.1"):NewDataObject("Keyed", {
	type = "launcher",
	text = "Keyed",
	icon = "Interface\\AddOns\\Keyed\\Textures\\Keyed-Portrait",
	OnClick = function(self, button, down)
		if button == "LeftButton" then
			if KeyedFrame then
				if KeyedFrame:IsShown() then KeyedFrame:Hide()
				else KeyedFrame:Show() end
			end
		elseif button == "RightButton" then
			--Find keystones...
			local keystones = Keyed:FindKeystones()

			--Check keystones and perform a sanity check...
			if #keystones > 0 and ChatFrame1EditBox then
				ChatFrame1EditBox:Show()
				ChatFrame1EditBox:SetFocus()
				ChatFrame1EditBox:Insert(keystones[1])
			end
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine(KeyedName, 1, 1, 1);
		tt:AddLine(L.MinimapTooltip)
	end,
})
KeyedMinimapButton = LibStub("LibDBIcon-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Keyed")

local KeystoneId = 138019
local prefix = "KEYED_17"
local KeyedName = "|cffd6266cKeyed|r"
local keystoneRequest = "keystones"
local playerKeystoneRequest = "playerkeystone"
KeyedPartyKeystones = {}

function Keyed:OnInitialize()
	-- Register "/keyed" command
	Keyed:RegisterChatCommand("keyed", "Options")
	Keyed:RegisterComm(prefix, "OnCommReceived")
	KeystoneListFrame:RegisterForDrag("LeftButton")

	-- Load Database
	self.db = LibStub("AceDB-3.0"):New("Keyedv3DB", defaults)

	-- Register Minimap Button
	KeyedMinimapButton:Register("Keyed", keyedLDB, self.db.profile.minimap)
	KeyedFrameShowMinimapButton:SetChecked(not(self.db.profile.minimap.hide))
end

function Keyed:OnEnable()
end

function Keyed:OnDisable()
end

function Keyed:Options(input)
	-- Check...
	if self:isempty(input) then
		KeystoneList_Update()
		KeyedFrame:Show()
	else
		local Arguments = self:SplitString(input, ' ')
		if Arguments[1] == "get" then
			if Arguments[2] == "all" then
				self:BroadcastKeystoneRequest()
			else
				self:SendKeystoneRequest(Arguments[2])
			end
		elseif Arguments[1] == "version" then
			local version = GetAddOnMetadata("Keyed", "Version")
			if version then print(KeyedName, L["Version"], version) end
		elseif Arguments[1] == "print" and (Arguments[2] == "db" or Arguments[2] == "database") then
				print(KeyedName, L["Keystones in database:"])
				for uid, entry in pairs(self.db.factionrealm) do
				for i = 1, #entry.keystones do
					print(KeyedName, entry.name, "(" .. i .. "/" .. #entry.keystones .. ")", entry.keystones[i])
					end
			end
		elseif Arguments[1] == "clear" then
			if Arguments[2] == "db" or Arguments[2] == "database" then
				table.wipe(self.db.factionrealm)
				self.db.factionrealm = defaults.factionrealm
				print(KeyedName, L["Wiped database..."])
				print("  " .. L["Please reload your UI to continue..."])
			else
				self.db.factionrealm[Arguments[2]] = nil
				print(KeyedName, L["Wiped"], Arguments[2])
			end
		else
			print(KeyedName, L["Incorrect usage..."])
		end
	end
end

function Keyed:SendParty(response)
	Keyed:SendCommMessage(prefix, response, "PARTY")
end

function Keyed:SendResponse(playerName, response)
	Keyed:SendCommMessage(prefix, response, "WHISPER", playerName)
end

function Keyed:BroadcastKeystoneRequest (silent)
	if GetGuildInfo("player") then
		if (GetServerTime() - KEYED_BROADCAST) > 4 then
			if not silent then print(KeyedName, L["Updating keystone database..."]) end
			Keyed:SendCommMessage(prefix, "request;" .. keystoneRequest, "GUILD")
			KEYED_BROADCAST = GetServerTime()
		elseif not silent then
			print(KeyedName, L["You must wait before requesting keystones again."])
		end
	end
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
	local classFileName = ""

	-- Handle...
	if arguments[1] == "request" then
		if arguments[2] == keystoneRequest then
			self:SendEntries(sender)		-- Send database contents...
			self:SendKeystones(sender)		-- Send your latest keystones...
		end
	elseif arguments[1] == keystoneRequest then
		player = arguments[2]
		uid = arguments[3]
		classFileName = arguments[4]
		time = tonumber(arguments[5])
		for i = 6, #arguments do
			if not self:isempty(arguments[i]) then
				link = arguments[i]
				table.insert(keystones, link)
			end
		end

		-- Wipe and add...
		if self.db.factionrealm[uid].time < time then
			self.db.factionrealm[uid].time = time
			self.db.factionrealm[uid].name = player
			self.db.factionrealm[uid].uid = uid
			self.db.factionrealm[uid].class = classFileName
			self.db.factionrealm[uid].upgradeRequired = false
			table.wipe(self.db.factionrealm[uid].keystones)
			for i = 1, #keystones do
				table.insert(self.db.factionrealm[uid].keystones, keystones[i])
			end

			-- Update List...
			KeystoneList_Update ()
		end
	end
end

function Keyed:SendEntries(target)
	-- Prepare
	local name, realm = UnitName("player")
	local message = ""
	for playerName, entry in pairs(self.db.factionrealm) do
		if playerName ~= name and entry.upgradeRequired ~= nil and not(entry.upgradeRequired) then
			message = keystoneRequest .. ";"  .. entry.name .. ";" .. entry.uid .. ";" .. entry.class .. ";" .. tostring(entry.time) .. ";"
			for i = 1, #entry.keystones do message = message .. entry.keystones[i] .. ";" end
			self:SendResponse(target, message)
		end
	end
end

function Keyed:SendKeystones(target)
	-- Prepare
	local localizedClass, classFileName = UnitClass("player")
	local uid = UnitGUID("player")
	local name = UnitName("player")
	local message = keystoneRequest .. ";" .. name .. ";" .. uid .. ";" .. classFileName .. ";" .. tostring(GetServerTime()) .. ";"
	local keystones = self:FindKeystones()
	for i = 1, #keystones do
		message = message .. keystones[i] .. ";"
	end
	self:SendResponse(target, message)
end

function Keyed:SendKeystonesToParty()
	-- Prepare
	local localizedClass, classFileName = UnitClass("player")
	local uid = UnitGUID("player")
	local name = UnitName("player")
	local message = keystoneRequest .. ";" .. name .. ";" .. uid .. ";" .. classFileName .. ";" .. tostring(GetServerTime()) .. ";"
	local keystones = self:FindKeystones()
	for i = 1, #keystones do
		message = message .. keystones[i] .. ";"
	end
	self:SendParty(message)
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
	slots[5] = GetContainerNumSlots(4)

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