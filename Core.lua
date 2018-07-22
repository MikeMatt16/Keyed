Keyed = LibStub("AceAddon-3.0"):NewAddon("Keyed", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0");
KEYED_MAJOR, KEYED_MINOR = "Keyed-1.9", 1;

local PLAYER_NAME, PLAYER_REALM, PLAYER_GUILD, PLAYER_GUID;
local KEYSTONE_ITEM_ID, KEYED_TEXT, KEYED_DB_VERSION = 138019, "|cffd6266cKeyed|r", 5;
local L = LibStub("AceLocale-3.0"):GetLocale("Keyed");
local keyedLib = KeyedLib or LibStub("KeyedLib-1.0");
local debugMode = true;	--[[Enables or disables the functionality of the debug(...) function.]]
local delayedRun = 0;

-- Default table
local default = {
	global = {
		chars = {},
		bnet = {},
	},
	profile = {
		minimap = {
			hide = false,
		},
	},
	factionrealm = {
		guilds = {},
	},
};
local keyedLDB = LibStub("LibDataBroker-1.1"):NewDataObject("Keyed", {
	type = "launcher",
	text = "Keyed",
	icon = "Interface\\AddOns\\Keyed\\Textures\\Keyed-Portrait",
	OnClick = function(self, button, down)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		if button == "LeftButton" then
			if KeyedFrame then
				if KeyedFrame:IsShown() then KeyedFrame:Hide()
				else KeyedFrame:Show() end
			end
		elseif button == "RightButton" then
			local keystoneLink = keyedLib:GetKeystoneLink();
			if keystoneLink then
				ChatFrame1EditBox:Show()
				ChatFrame1EditBox:SetFocus()
				ChatFrame1EditBox:Insert(keystoneLink)
			end
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine(KEYED_TEXT, 1, 1, 1);
		tt:AddLine(L.MinimapTooltip)
	end,
});
KeyedMinimapButton = LibStub("LibDBIcon-1.0");

local function GetGroupChatChannel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT";
	elseif UnitInRaid("player") then
		return "RAID";
	elseif IsInGroup() then
		return "PARTY";
	end
	return nil;
end

local function debug(...)
	if debugMode then
		print("|cffd6266c[Keyed]|r", ...);
	end
end

local function splitString(input, separator)
	local parts = {};
	local theStart = 1;
	local theSplitStart, theSplitEnd = string.find(input, separator, theStart);
	while theSplitStart do
		table.insert(parts, string.sub(input, theStart, theSplitStart-1));
		theStart = theSplitEnd + 1;
		theSplitStart, theSplitEnd = string.find(input, separator, theStart);
	end
	table.insert(parts, string.sub(input, theStart));
	return parts;
end

local function CheckEntry(db, guid, entry)
	if entry.guid ~= guid or entry.dbVersion ~= KEYED_DB_VERSION or entry.upgradeRequired then 
		db[guid] = nil;
		return false;
	elseif entry.keystoneWeekIndex ~= keyedLib:GetWeeklyIndex() then
		db[guid] = nil;
		return false 
	end
	return true
end

----------------------------------------
-- Keyed:OnInitialize
--	Occurs on the ADDON_LOADED event.
----------------------------------------
function Keyed:OnInitialize()
	-- Setup DBs
	self.db = LibStub("AceDB-3.0"):New("KeyedDB", default);
	self.groupDb = {};

	-- Register "/keyed" command
	Keyed:RegisterChatCommand("keyed", "Options");
end

---------------------------------------
-- Keyed:OnEnable()
--	Occurs on the PLAYER_LOGIN event.
---------------------------------------
function Keyed:OnEnable()
	-- Setup
	PLAYER_NAME, PLAYER_REALM = UnitFullName("player")
	PLAYER_GUILD = GetGuildInfo("player")

	-- Initialize guild database
	if PLAYER_GUILD then
		self.db.factionrealm.guilds[PLAYER_GUILD] = self.db.factionrealm.guilds[PLAYER_GUILD] or {};
	end
	local db = nil

	-- Clean guild DB
	for _, guild in pairs(self.db.factionrealm.guilds) do
		db = guild;
		for guid,entry in pairs(db) do
			if not CheckEntry(db, guid, entry) then debug("Cleaned guild entry", guid) end
		end
	end

	-- Clean BNet DB
	db = Keyed:GetBnetDb();
	for guid,entry in pairs(db) do
		if entry.guid ~= guid or entry.dbVersion ~= KEYED_DB_VERSION or entry.upgradeRequired then
			if not CheckEntry(db, guid, entry) then debug("Cleaned BNet entry", guid) end
		end
	end

	-- Clean Chars DB
	db = Keyed:GetCharsDb();
	for guid,entry in pairs(db) do
		if CheckEntry(db, guid, entry) and entry.keystone.name ~= PLAYER_NAME then
			KeyedLib:AddAltKeystone(entry.keystone);
		end
	end

	-- Register Minimap Button
	KeyedMinimapButton:Register("Keyed", keyedLDB, self.db.profile.minimap);
	KeyedFrameShowMinimapButton:SetChecked(not(self.db.profile.minimap.hide));

	-- Register KeyedFrame events...
	KeyedFrame_HandleEvent("PLAYER_GUILD_UPDATE", Keyed.GuildUpdate);
	KeyedFrame_HandleEvent("GROUP_ROSTER_UPDATE", Keyed.WipeGroupDb);
	KeyedFrame_HandleEvent("GROUP_LEFT", Keyed.WipeGroupDb);

	-- Add keystone listener
	keyedLib:AddKeystoneListener(function(keystone, channel, sender)
		-- Check
		if not(keystone) then return end
	
		-- Prepare
		local entry = nil
		if channel == nil then
			debug("Keystone received from self.", "Updating...");
			entry = Keyed:CreateCharEntry(keystone.guid);
		elseif channel == "GUILD" and Keyed:GetGuildDb() then
			debug("Keystone received from guild.");
			entry = Keyed:GetGuildDb()[keystone.guid];
			if not(entry) or entry.keystone.timeGenerated < keystone.timeGenerated then
				debug("Initializing guild entry.");
				entry = Keyed:CreateGuildEntry(keystone.guid);
			end
		elseif channel == "BNET" then
			debug("Keystone received from friends.");
			entry = Keyed:CreateBnetEntry(keystone.guid);
		elseif IsInGroup() and channel == GetGroupChatChannel() then
			entry = Keyed:CreateGroupEntry(keystone.guid);
		end
	
		-- Check
		if entry then
			entry.dbVersion = KEYED_DB_VERSION;
			entry.upgradeRequired = false;
			if entry.keystone.timeGenerated < keystone.timeGenerated then
				debug(keystone.name, "Keystone was updated.");
				entry.keystone = keystone;
			end
		end
	
		-- Update Keystone List
		KeystoneList_Update()
	end);

	-- Queue Synchronization
	keyedLib:QueueSynchronization();
end

----------------------------------------
-- Keyed:GuildUpdate()
--	Updates the PLAYER_GUILD variable.
----------------------------------------
function Keyed:GuildUpdate()
	-- Change player guild
	PLAYER_GUILD = GetGuildInfo("player")

	-- Update keystone list
	KeystoneList_Update()
end

------------------------------
-- Keyed:WipeGroupDb()
--	Clears the group database.
------------------------------
function Keyed:WipeGroupDb()
	-- Wipe Group
	if Keyed:GetGroupDb() then table.wipe(Keyed:GetGroupDb()) end

	-- Update keystone list
	KeystoneList_Update()
end

--------------------------------------------
-- Keyed->Options(input)
--	Handles the slash command.
--		input: The command arguments string.
--------------------------------------------
function Keyed:Options(input)
	-- Check...
	if input == "" then	-- no options; just show the GUI
		KeystoneList_Update()
		KeyedFrame:Show()
	else
		-- Get arguments
		local Arguments = splitString(input, ' ')
		
		-- Check 1st argument (version, clear/wipe)
		if Arguments[1] == "help" then
			print(KEYED_TEXT, L["Commands"]);
			for i,v in pairs(L.commands) do print(v) end
		elseif Arguments[1] == "version" then
			local version = GetAddOnMetadata("Keyed", "Version")
			if version then 
				print(KEYED_TEXT, L["Version"], version) 
			end
		elseif Arguments[1] == "clear" or Arguments[1] == "wipe" then
			if Arguments[2] == "db" or Arguments[2] == "database" then
				-- Wipe databases...
				if Keyed:GetBnetDb() then table.wipe(Keyed:GetBnetDb()) end
				if Keyed:GetGuildDb() then table.wipe(Keyed:GetGuildDb()) end
				if Keyed:GetCharsDb() then table.wipe(Keyed:GetCharsDb()) end
				if Keyed:GetGroupDb() then table.wipe(Keyed:GetGroupDb()) end
				print(KEYED_TEXT, L["Database Wiped"])

				-- Update keystone list
				KeystoneList_Update()
			end
		else print(KEYED_TEXT, L["Incorrect Usage"]) end
	end
end

------------------------------
-- Keyed:GetGroupDb()
--	Returns the group databse.
------------------------------
function Keyed:GetGroupDb()
	return groupDb;
end

------------------------------------
-- Keyed:GetBnetDb()
--	Returns the Battle.net database.
------------------------------------
function Keyed:GetBnetDb()
	return self.db.global.bnet;
end

------------------------------------
-- Keyed:GetCharsDb()
--	Returns the characters database.
------------------------------------
function Keyed:GetCharsDb()
	return self.db.global.chars;
end

-------------------------------
-- Keyed:GetGuildDb()
--	Returns the guild database.
-------------------------------
function Keyed:GetGuildDb()
	if PLAYER_GUILD then
		return self.db.factionrealm.guilds[PLAYER_GUILD];
	end
end

----------------------------------------------------
-- Keyed:CreateGuildEntry(name)
--	Creates a guild entry with the specified GUID.
--		guid: the player guid
----------------------------------------------------
function Keyed:CreateGuildEntry(guid)
	local db = Keyed:GetGuildDb();
	if(db and guid) then
		if not db[guid] then db[guid] = { keystone = { guid = guid, timeGenerated = 0 } } end
		return db[guid];
	end
end

------------------------------------------------------
-- Keyed:CreateCharEntry(guid)
--	Creates a character entry with the specified GUID.
--		guid: the player guid
------------------------------------------------------
function Keyed:CreateCharEntry(guid)
	local db = self.db.global.chars;
	if db then
		if not db[guid] then db[guid] = { keystone = { guid = guid, timeGenerated = 0 } } end
		return db[guid];
	end
end

-------------------------------------------------------
-- Keyed:CreateBnetEntry(name)
--	Creates a Battle.net entry with the specified GUID.
--		guid: the player guid
-------------------------------------------------------
function Keyed:CreateBnetEntry(guid)
	local db = self.db.global.bnet;
	if db then
		if not db[guid] then db[guid] = { keystone = { guid = guid, timeGenerated = 0 } } end
		return db[guid];
	end
end

--------------------------------------------------
-- Keyed:CreateGroupEntry(guid)
--	Creates a group entry with the specified GUID.
--		guid: the player guid
--------------------------------------------------
function Keyed:CreateGroupEntry(guid)
	local db = self.groupDb;
	if db then
		if not db[guid] then db[guid] = { keystone = { guid = guid, timeGenerated = 0 } } end
		return db[guid];
	end
end
