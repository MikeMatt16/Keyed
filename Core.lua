-------------------------
-- Keyed Global Variables
-------------------------
Keyed = LibStub("AceAddon-3.0"):NewAddon("Keyed", "AceConsole-3.0", "AceHook-3.0");
KEYED_MAJOR, KEYED_MINOR = "Keyed-1.9", 1;

------------------------
-- Keyed Local Variables
------------------------
local PLAYER_NAME, PLAYER_REALM, PLAYER_GUILD, PLAYER_GUID;
local KEYSTONE_ITEM_ID, KEYED_TEXT, KEYED_DB_VERSION = 138019, "|cffd6266cKeyed|r", 5;
local L = LibStub("AceLocale-3.0"):GetLocale("Keyed");
local keyedLib = LibStub("KeyedLib-1.0");

----------------------
-- Default AceDB table
----------------------
local default = {
	global = {
		chars = {
			["*"] = {
				dbVersion = 0,
				upgradeRequired = true,
				keystone = {}
			},
		},
		bnet = {
			["*"] = {
				dbVersion = 0,
				upgradeRequired = true,
				keystone = {},
			}
		},
	},
	profile = {
		region = "Americas",
		minimap = {
			hide = false,
		},
	},
	factionrealm = {
		guilds = {
			["*"] = {
				["*"] = {
					dbVersion = 0,
					upgradeRequired = true,
					keystone = {},
				},
			},
		},
	},
};

-------------------------------
-- LibDataBroker minimap button
-------------------------------
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

---------------------------------
-- debug(s)
--	Prints a lovely debug message
--		s: the debug message
--		args: the debug arguments
---------------------------------
local function debug(s, ...)
	if s then print("[" .. KEYED_TEXT .. "]: " .. s) end
	if (...) then print("\t" .. ...) end
end

------------------------------------------------------------------
-- splitString(input, separator)
--		input: the input string
--		separator: the character/string to separate the input with
------------------------------------------------------------------
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

-------------------------------------------------------------------------------------------------------------------------
-- CheckEntry(db, guid, entry)
--	Checks an entry in a database, and removes it if necessary, returns true if the entry is OK, otherwise returns false.
--		db: The database.
--		guid: The entry GUID
--		entry: The entry
--------------------------------------------------------------------------------------------------------------------------
local function CheckEntry(db, guid, entry)
	if entry.guid ~= guid or entry.dbVersion ~= KEYED_DB_VERSION or entry.upgradeRequired then db[guid] = nil return false
	elseif entry.keystoneWeekIndex ~= KCLib:GetWeeklyIndex() then db[guid] = nil return false end
	return true
end

----------------------------------------
-- Keyed->OnInitialize
--	Occurs when the AceAddOn initializes
----------------------------------------
function Keyed:OnInitialize()
	-- Setup DBs
	self.db = LibStub("AceDB-3.0"):New("KeyedDB", default);
	self.groupDb = {};

	-- Register "/keyed" command
	Keyed:RegisterChatCommand("keyed", "Options");
end

---------------------------------------
-- Keyed->OnEnable()
--	Occurs on the 'PLAYER_LOGIN' event.
---------------------------------------
function Keyed:OnEnable()
	-- Setup
	PLAYER_NAME, PLAYER_REALM = UnitFullName("player")
	PLAYER_GUILD = GetGuildInfo("player")

	-- Clean guild DB
	for guildName,guild in pairs(self.db.factionrealm.guilds) do
		for guid,entry in pairs(guild) do
			CheckEntry(self.db.factionrealm.guilds, guid, entry);
		end
	end

	-- Clean BNet DB
	for guid,entry in pairs(Keyed:GetBnetDb()) do
		if entry.guid ~= guid or entry.dbVersion ~= KEYED_DB_VERSION or entry.upgradeRequired then
			CheckEntry(Keyed:GetBnetDb(), guid, entry);
		end
	end

	-- Clean Chars DB
	for guid,entry in pairs(Keyed:GetCharsDb()) do
		if CheckEntry(Keyed:GetCharsDb(), guid, entry) and entry.keystone.name ~= PLAYER_NAME then
			keyedLib:AddAltKeystone(entry.keystone);
		end
	end

	-- Register Minimap Button
	KeyedMinimapButton:Register("Keyed", keyedLDB, self.db.profile.minimap);
	KeyedFrameShowMinimapButton:SetChecked(not(self.db.profile.minimap.hide));

	-- Register KeyedFrame events...
	KeyedFrame_HandleEvent("PLAYER_GUILD_UPDATE", Keyed.GuildUpdate);
	KeyedFrame_HandleEvent("GROUP_ROSTER_UPDATE", Keyed.WipeGroupDb);
	KeyedFrame_HandleEvent("GROUP_LEFT", Keyed.WipeGroupDb);

	-- Register Keystone Listener
	keyedLib:AddKeystoneListener(function(keystone, channel, sender)
		Keyed:OnKeystoneReceived(keystone, channel, sender)
	end);

	-- Get link
	local link = keyedLib:GetKeystoneLink();
	self.db.profile.keystoneLink = link;
end

----------------------------------------
-- Keyed->GuildUpdate()
--	Updates the 'PLAYER_GUILD' variable.
----------------------------------------
function Keyed:GuildUpdate()
	-- Change player guild
	PLAYER_GUILD = GetGuildInfo("player")

	-- Update keystone list
	KeystoneList_Update()
end

------------------------------
-- Keyed->WipeGroupDb()
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
	if self:isempty(input) then	-- no options; just show the GUI
		KeystoneList_Update()
		KeyedFrame:Show()
	else
		-- Get arguments
		local Arguments = splitString(input, ' ')
		
		-- Check 1st argument (version, clear/wipe)
		if Arguments[1] == "version" then
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

----------------------------------------------------------
-- Keyed->OnKeystoneReceived(keystone)
--	Occurs when a keystone is received.
-- 		keystone: The keystone received.
-- 		channel: The channel the keystone was received on.
-- 		sender: The sender of the keystone.
----------------------------------------------------------
function Keyed:OnKeystoneReceived(keystone, channel, sender)
	-- Check
	if not keystone then return end

	-- Prepare
	local entry = nil

	-- Check channel
	if channel == "PLAYER" then entry = Keyed:CreateCharEntry(keystone.guid)
	elseif channel == "GUILD" then entry = Keyed:CreateGuildEntry(keystone.guid)
	elseif channel == "BNET" then entry = Keyed:CreateBnetEntry(keystone.guid)
	elseif IsInGroup() and channel == GetGroupChatChannel() then
		entry = Keyed:CreateGroupEntry(keystone.guid)
	end
	
	-- Setup entry
	if not entry then return end
		entry.dbVersion = KEYED_DB_VERSION
		entry.upgradeRequired = false
		entry.keystone = keystone

	-- Update Keystone List
	if KeystoneList_Update then KeystoneList_Update() end
end

-------------------------------------------
-- Keyed->isempty(s)
--	Determines if a string is nil or empty.
--		s: input string
-------------------------------------------
function Keyed:isempty(s)
	return s == nil or s == ''
end

------------------------------
-- Keyed->GetGroupDb()
--	Returns the group databse.
------------------------------
function Keyed:GetGroupDb()
	return self.groupDb
end

------------------------------------
-- Keyed->GetBnetDb()
--	Returns the Battle.net database.
------------------------------------
function Keyed:GetBnetDb()
	return self.db.global.bnet
end

------------------------------------
-- Keyed->GetCharsDb()
--	Returns the characters database.
------------------------------------
function Keyed:GetCharsDb()
	return self.db.global.chars
end

-------------------------------
-- Keyed->GetGuildDb()
--	Returns the guild database.
-------------------------------
function Keyed:GetGuildDb()
	if PLAYER_GUILD then
		if not self.db.factionrealm.guilds[PLAYER_GUILD] then
			self.db.factionrealm.guilds[PLAYER_GUILD] = {}
		end
		return self.db.factionrealm.guilds[PLAYER_GUILD]
	end
end

----------------------------------------------------
-- Keyed->CreateGuildEntry(name)
--	Creates a guild entry with the specified GUID.
--		guid: the player guid
----------------------------------------------------
function Keyed:CreateGuildEntry(guid)
	local db = Keyed:GetGuildDb()
	if(db and guid) then
		if not db[guid] then db[guid] = {} end
		return db[guid]
	end
end

------------------------------------------------------
-- Keyed->CreateCharEntry(guid)
--	Creates a character entry with the specified GUID.
--		guid: the player guid
------------------------------------------------------
function Keyed:CreateCharEntry(guid)
	local db = self.db.global.chars
	if db then
		if not db[guid] then db[guid] = {} end
		return db[guid]
	end
end

-------------------------------------------------------
-- Keyed->CreateBnetEntry(name)
--	Creates a Battle.net entry with the specified GUID.
--		guid: the player guid
-------------------------------------------------------
function Keyed:CreateBnetEntry(guid)
	local db = self.db.global.bnet
	if db then
		if not db[guid] then db[guid] = {} end
		return db[guid]
	end
end

--------------------------------------------------
-- Keyed->CreateGroupEntry(guid)
--	Creates a group entry with the specified GUID.
--		guid: the player guid
--------------------------------------------------
function Keyed:CreateGroupEntry(guid)
	local db = self.groupDb
	if db then
		if not db[guid] then db[guid] = {} end
		return db[guid]
	end
end
