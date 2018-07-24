﻿KEYED_SORT_LEVEL, KEYED_SORT_NAME, KEYED_SORT_DUNGEON = "LEVEL", "NAME", "DUNGEON";
KEYED_GUILD, KEYED_GROUP, KEYED_BNET, KEYED_ALTS = "GUILD", "PARTY", "BNET", "CHARS";
KEYED_SORT_TYPE = KEYED_SORT_LEVEL;
KEYED_TAB = KEYED_GUILD;
KEYED_FRAME_PLAYER_HEIGHT = 16;
KEYSTONES_TO_DISPLAY = 19;
KEYED_SORT_ORDER_DESCENDING = true;
KEYED_SORT_FUNCTION = Keyed_SortByLevel;
KEYED_LOCALE = GetKeyedLocale();
KEYED_DEBUG_TABLE = {};

local groupDB, guildDB, charactersDB, friendsDB = {}, {}, {}, {};
local playerGuild, playerName, playerRealm, playerGuid;
local svLoaded, playerLogin = false, false;
local keyedSvVersion = 1;
local keyedDbVersion = 1;
local keyedName = select(1, ...);
local keyedText = "|cffd6266cKeyed|r";
local eventHandlers = {};
local challengeModeMaps = {};
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
			local keystoneLink = KeyedLib:GetKeystoneLink();
			if keystoneLink then
				ChatFrame1EditBox:Show()
				ChatFrame1EditBox:SetFocus()
				ChatFrame1EditBox:Insert(keystoneLink)
			end
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine(keyedText, 1, 1, 1);
		tt:AddLine(KEYED_LOCALE.MinimapLine1);
		tt:AddLine(KEYED_LOCALE.MinimapLine2);
	end,
});
KeyedMinimapButton = LibStub("LibDBIcon-1.0");

local function SaveDatabases()
	KeyedDB.characters = charactersDB;
	KeyedDB.friends = friendsDB;
	if playerGuild then KeyedDB.guilds[playerRealm][playerGuild] = guildDB; end
end

local function LoadDatabases()
	for guid, entry in pairs(KeyedDB.characters) do
		charactersDB[guid] = entry;
	end
	for guid, entry in pairs(KeyedDB.friends) do
		friendsDB[guid] = entry;
	end
end

eventHandlers["ADDON_LOADED"] = function(self, name)
	if name ~= keyedName then return; end
	tinsert(KEYED_DEBUG_TABLE, "addon loaded");
	
	-- Initialize/upgrade database
	if not KeyedSV or KeyedSV ~= keyedSvVersion then
		-- Initialize all databases
		KeyedSV = keyedSvVersion;
		KeyedDB = { 
				icon = {
					hide = false,
				},
				guilds = {},
				friends = {},
				characters = {},
		};
	end
	
	-- Clean guild database of out-of-date entries
	for _, realmTable in pairs(KeyedDB.guilds) do
		for guildName, guildTable in pairs(realmTable) do
			for guid, entry in pairs(guildTable) do
					if (entry.version or 0) ~= keyedDbVersion then
						realmTable[guid] = nil;
					end
			end
		end
	end

	-- Clean friends database of out-of-date entries
	for guid, entry in pairs(KeyedDB.friends) do
		if (entry.version or 0) ~= keyedDbVersion then
			KeyedDB.friends[guid] = nil;
		end
	end

	-- Clean characters database of out-of-date entries
	for guid, entry in pairs(KeyedDB.characters) do
		if (entry.version or 0) ~= keyedDbVersion then
			KeyedDB.characters[guid] = nil;
		end
	end

	-- SavedVariables loaded
	svLoaded = true;

	-- Load immediate databases from saved variables.
	LoadDatabases();
end

eventHandlers["PLAYER_GUILD_UPDATE"] = function(self, ...)
	if not IsInGuild() then return; end
	tinsert(KEYED_DEBUG_TABLE, "player guild update");
	playerGuild = select(1, GetGuildInfo("player"));
	if not playerGuild then return; end

	-- Initialize realm and guild
	KeyedDB.guilds[playerRealm] = KeyedDB.guilds[playerRealm] or {};
	KeyedDB.guilds[playerRealm][playerGuild] = KeyedDB.guilds[playerRealm][playerGuild] or {};
	
	-- Load guild database from saved variables
	for guid, entry in pairs(KeyedDB.guilds[playerRealm][playerGuild]) do
		guildDB[guid] = entry;
	end

	-- Add guild members to KeyedLib
	for guid, entry in pairs(guildDB) do
		if entry.keystone and guid == entry.keystone.guid and guid ~= playerGuid then KeyedLib:AddGuildKeystone(entry.keystone); end
	end
	
	-- Queue sync and update
	KeyedLib:QueueSynchronization();
	KeystoneList_Update();
end

eventHandlers["PLAYER_LOGIN"] = function(self, ...)
	tinsert(KEYED_DEBUG_TABLE, "player login");
	-- Minimap button
	KeyedMinimapButton:Register(keyedName, keyedLDB, KeyedDB.icon);
	KeyedFrameShowMinimapButton:SetChecked(not(KeyedDB.icon.hide));

	-- Load player information
	playerGuid = string.sub(UnitGUID("player"), 8);
	playerName, playerRealm = UnitFullName("player");
	
	-- Add characters to KeyedLib
	for guid, entry in pairs(charactersDB) do
		if entry.keystone and guid == entry.keystone.guid and guid ~= playerGuid then KeyedLib:AddAltKeystone(entry.keystone); end
	end

	-- Add character entry to characters and guild if applicable
	local keystone = KeyedLib:GetPlayerKeystone();
	local entry = { version = keyedDbVersion, keystone = keystone };
	if keystone and keystone.guid then
		charactersDB[keystone.guid] = entry;
		if playerGuild then
			guildDB[keystone.guid] = entry;
		end
	end

	-- Listen for keystones
	KeyedLib:AddKeystoneListener(function(keystone, channel, sender)
		if sender and keystone then
			local entry = { version = keyedDbVersion, keystone = keystone };
			local indexer = keystone.guid;
			local unitPrefix = channel == "PARTY" and "party" or "raid";

			-- Check
			if channel == "INSTANCE_CHAT" or channel == "RAID" or channel == "PARTY" then
				for i = 1, GetNumGroupMembers() do
					local unitGuid = UnitGUID(unitPrefix .. i);
					if unitGuid then
						if indexer == string.sub(unitGuid, 8) then
							groupDB[unitGuid] = entry;
						end
					end
				end
			elseif channel == "GUILD" then
				local time = (((guildDB or {})[indexer] or {}).keystone or {}).timeGenerated or 0;
				if time < keystone.timeGenerated then guildDB[indexer] = entry; end
			elseif channel == "BNET" then
				local characterName, client, realmName = select(2, BNGetGameAccountInfo(sender));
				if client and client == BNET_CLIENT_WOW then
					for i = 1, select(1, BNGetNumFriends()) do
						if select(6, BNGetFriendInfo(i)) == sender then
							entry.battleTag, entry.accountName = select(2, BNGetFriendInfo(i));
							friendsDB[indexer] = entry;
						end
					end
				end
			elseif channel == "WHISPER" then
				friendsDB[indexer] = entry;
			end

			-- Update
			KeystoneList_Update();
			SaveDatabases();
		end
	end);

	-- Queue sync and update
	KeyedLib:QueueSynchronization();
	KeystoneList_Update();
end

eventHandlers["PLAYER_LOGOUT"] = function(self, ...)
	-- Save databases
	SaveDatabases();
end

------------------------------------
-- KeyedFrame_OnLoad(self)
--	Occurs when the frame is loaded.
--		self: The frame.
------------------------------------
function KeyedFrame_OnLoad(self)
	PanelTemplates_SetNumTabs(self, 4)
	PanelTemplates_SetTab(self, 1)
	KeystoneList_Update()
	challengeModeMaps = C_ChallengeMode.GetMapTable();
	SLASH_KEYED1 = "/keyed";
	SlashCmdList.KEYED = function(msg, editBox)
		KeyedFrame_Options(msg);
	end
	tinsert(UISpecialFrames, "KeyedFrame");
end

-------------------------------------------------
-- KeyedFrame_Options(input)
--	Occurs when the player types a slash command.
--		input: The slash command argument(s).
-------------------------------------------------
function KeyedFrame_Options(input)
	if input == "" then	-- no options; just show the GUI
		KeystoneList_Update()
		KeyedFrame:Show()
	else
		-- Get arguments
		local arguments = { strsplit(' ', input) };
		
		-- Check 1st argument (version, clear/wipe)
		if arguments[1] == "help" then
			print(keyedText, KEYED_LOCALE["Commands"]);
			for i,v in pairs(KEYED_LOCALE.commands) do print(v); end
		elseif arguments[1] == "version" then
			local version = GetAddOnMetadata("Keyed", "Version")
			if version then 
				print(keyedText, KEYED_LOCALE["Version"], version);
			end
		elseif arguments[1] == "clear" then
			if arguments[2] == "all" then
				-- Wipe databases...
				table.wipe(guildDB or {});
				table.wipe(friendsDB or {});
				table.wipe(charactersDB or {});
				table.wipe(groupDB or {});
				print(keyedText, KEYED_LOCALE["Database Wiped"]);

				-- Update keystone list
				KeystoneList_Update();
				SaveDatabases();
			end
		elseif arguments[1] == "test" then
			for i, evt in ipairs(KEYED_DEBUG_TABLE) do
				print(i, evt);
			end
		else
			print(keyedText, KEYED_LOCALE["Incorrect Usage"]);
		end
	end
end

---------------------------------------
-- KeyedFrame_OnEvent(self, event, ...)
--	Occurs on event.
--		self: the frame
--		event: the event name
--		...: the event arguments
---------------------------------------
function KeyedFrame_OnEvent(self, event, ...)
	-- Check event
	if event == "GROUP_ROSTER_UPDATE" then
		local guids = {};
		local unitPrefix = IsInGroup() and "party" or "raid";
		for i = 1, GetNumGroupMembers() do
			local guid = UnitGUID(unitPrefix .. i);
			if guid then
				tinsert(guids, guid);
			end
		end
		for guid, entry in pairs(groupDB) do
			local contains = false;
			for i = 1, #guids do
				if guids[i] == guid then
					contains = true;
					break;
				end
				if not contains then
					groupDB[guid] = nil;
				end
			end
		end
		KeystoneList_Update();
	elseif event == "GROUP_LEFT" then
		table.wipe(groupDB);
		KeystoneList_Update();
	elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
		KeyedFrame_Update(self, event, ...)
	end

	-- Check handlers
	for name,handler in pairs(eventHandlers) do
		if event == name and handler then handler(self, ...) end
	end
end

-------------------------------------------------
-- KeyedFramePlayerButton_OnClick(self, keystone)
--	Occurs when a player button is clicked.
--		self: The player button frame.
--		keystone: The player's keystone entry.
-------------------------------------------------
function KeyedFramePlayerButton_OnClick(self, keystone)
	-- TODO: Do something when the player clicks on list item.
end

-------------------------------------------------
-- KeyedFramePlayerButton_OnEnter(self, keystone)
--	Occurs when a player button is entered.
--		self: The player button frame.
--		keystone: The player's keystone entry.
-------------------------------------------------
function KeyedFramePlayerButton_OnEnter(self, keystone)
	local name, realm = strsplit("-", keystone.name, 2)
	local classColor = RAID_CLASS_COLORS[keystone.class]
	local class = LOCALIZED_CLASS_NAMES_MALE[keystone.class]
	local dungeon = C_ChallengeMode.GetMapUIInfo(keystone.keystoneDungeonId)
	local faction = PLAYER_FACTION_GROUP[keystone.faction]
	if keystone.faction then faction = PLAYER_FACTION_GROUP[1] else faction = PLAYER_FACTION_GROUP[2] end

	if not KeyedFrame or not KeyedKeystoneTooltip then return end
	KeyedKeystoneTooltip:SetOwner(KeyedFrame, "ANCHOR_NONE")
	KeyedKeystoneTooltip:SetPoint("LEFT", KeyedFrame:GetName(), "RIGHT", 2, 0)
	KeyedKeystoneTooltip:AddLine(name, classColor.r, classColor.g, classColor.b)
	if(keystone.guildName) then	KeyedKeystoneTooltip:AddLine(keystone.guildName, 1, 1, 1) end
	KeyedKeystoneTooltip:AddLine(strjoin(" ", LEVEL, keystone.level, class), 1, 1, 1)
	KeyedKeystoneTooltip:AddLine(gsub(ITEM_LEVEL, "%%d", keystone.ilvlEquipped .. "/" .. keystone.ilvl), 1, 1, 1)
	KeyedKeystoneTooltip:AddLine(strjoin(" ", faction, realm), 1, 1, 1)
	KeyedKeystoneTooltip:AddLine(" ")
	KeyedKeystoneTooltip:AddLine(KEYED_LOCALE["Current Keystone"])
	KeyedKeystoneTooltip:AddLine("    " .. dungeon .. " +" .. keystone.keystoneLevel, 1, 1, 1)
	KeyedKeystoneTooltip:AddLine(" ")
	KeyedKeystoneTooltip:AddLine(KEYED_LOCALE["Weekly Best"])
	if keystone.bestKeystoneLevel == 0 then
		KeyedKeystoneTooltip:AddLine("    " .. NONE, 0.6, 0.6, 0.6)
	else
		KeyedKeystoneTooltip:AddLine("    " .. C_ChallengeMode.GetMapUIInfo(keystone.bestKeystoneDungeonId) .. " +" .. keystone.bestKeystoneLevel, 1, 1, 1)
	end
	KeyedKeystoneTooltip:Show()
end

-----------------------------------------
-- KeyedFrame_HandleEvent(event, func)
--	Sets an event handler.
--		event: The event string.
--		func: The event handler function.
-----------------------------------------
function KeyedFrame_HandleEvent(event, func)
	if eventHandlers[event] then error("Event " .. event .. " is already being handled by another function.")
		if type(event) == "string" and type(func) == "function" then
			EVENT_HANDLERS[event] = func
		else error("Incorrect usage. KeyedFrame_HandleEvent(event, function)\r\n\tevent: the event string.\r\n\tfunc: the event handler function.") end
	end
end

function KeyedFrame_Update(self, event, ...)
	-- Todo: Add frames showing current week's affixes at top of frame between title bar and list.
end

------------------------------------------------
-- KeystoneListFrame_OnLoad(self)
--	Occurs when the KeystoneListFrame is loaded.
--		self: the frame.
------------------------------------------------
function KeystoneListFrame_OnLoad(self)
	-- Register for events...
	KeyedFrame:RegisterAllEvents()
	
	-- Register KeystoneListFrame for dragging with the left mouse-button.
	KeystoneListFrame:RegisterForDrag("LeftButton")

	-- Create List Items
	for i = 2, KEYSTONES_TO_DISPLAY do
		local button = CreateFrame ("Button", "KeystoneListFrameButton" .. i, KeystoneListFrame, "KeyedFramePlayerButtonTemplate")
		button:SetID (i)
		button:SetPoint ("TOP", _G["KeystoneListFrameButton" .. (i - 1)], "BOTTOM")
	end

	-- Set Version
	local version = GetAddOnMetadata("Keyed", "Version")
	if version then KeyedVersionText:SetText("v" .. version) end
end

-------------------------------------
-- KeystoneList_Update()
--	Updates the active keystone list.
-------------------------------------
function KeystoneList_Update()
	-- Prepare
	local numKeystones, keystoneData = 0, {}
	local name, realm, dungeon, level
	local button, buttonName, buttonDungeon, buttonLevel
	local columnTable
	local keystoneIndex, keystoneEntry
	local showScrollBar = nil;
	local level = ""

	-- Get Database...
	if KEYED_TAB == KEYED_GUILD then
		numKeystones, keystoneData = KeyedFrame_GetKeystoneData(guildDB);
	elseif KEYED_TAB == KEYED_BNET then
		numKeystones, keystoneData = KeyedFrame_GetKeystoneData(friendsDB);
	elseif KEYED_TAB == KEYED_GROUP then
		numKeystones, keystoneData = KeyedFrame_GetKeystoneData(groupDB);
	elseif KEYED_TAB == KEYED_ALTS then 
		numKeystones, keystoneData = KeyedFrame_GetKeystoneData(charactersDB);
	end

	-- Show scrollbar?
	if numKeystones > KEYSTONES_TO_DISPLAY then showScrollBar = 1 end

	-- Prepare functions...
	local SetDepleted = function(fontString) fontString:SetTextColor(0.6, 0.6, 0.6, 1.0) end
	local SetHighlighted = function(fontString) fontString:SetTextColor(GameFontHighlightSmall:GetTextColor()) end
	local SetClass = function(fontString, classTable) fontString:SetTextColor(classTable.r, classTable.g, classTable.b, classTable.a) end
	local SetNormal = function(fontString) fontString:SetTextColor(GameFontNormalSmall:GetTextColor()) end

	-- Loop through each button...
	local keystoneOffset = FauxScrollFrame_GetOffset(KeystoneListScrollFrame)
	for i=1, KEYSTONES_TO_DISPLAY do

		-- Get Button elements
		keystoneIndex = keystoneOffset + i
		button = _G["KeystoneListFrameButton" .. i]
		buttonName = _G["KeystoneListFrameButton" .. i .. "Name"]
		buttonDungeon = _G["KeystoneListFrameButton" .. i .. "Dungeon"]
		buttonLevel = _G["KeystoneListFrameButton" .. i .. "Level"]

		-- Check frames...
		assert(button, "Unable to find button index " .. i)
		assert(buttonName, "Unable to find button name index " .. i)
		assert(buttonDungeon, "Unable to find button dungeon index " .. i)
		assert(buttonLevel, "Unable to find button level index " .. i)

		-- Set index
		button.keystoneIndex = keystoneIndex

		-- Check keystone
		if keystoneIndex <= numKeystones and keystoneData[keystoneIndex].keystoneWeekIndex >= KeyedLib:GetWeeklyIndex() then
			-- Get properties from keystone
			name, realm = strsplit("-",keystoneData[keystoneIndex].name, 2)
			if realm == playerRealm then button.playerName = name else button.playerName = name .. "-" .. realm end
			button.dungeon = C_ChallengeMode.GetMapUIInfo(keystoneData[keystoneIndex].keystoneDungeonId)
			button.classColor = RAID_CLASS_COLORS[keystoneData[keystoneIndex].class]
			button.level = tostring(keystoneData[keystoneIndex].keystoneLevel)
			button.keystone = keystoneData[keystoneIndex]

			-- Set button properties
			buttonName:SetText(button.playerName)
			if button.classColor then SetClass(buttonName, button.classColor) else SetNormal(buttonName) end
			buttonDungeon:SetText (button.dungeon);
			if showScrollBar then buttonDungeon:SetWidth (170)
			else buttonDungeon:SetWidth (185) end
			buttonLevel:SetText (button.level);
			button:Show()
		else button:Hide() end
	end

	-- Set 'Dungeon' column width
	if showScrollBar then KeyedFrameColumn_SetWidth (KeyedFrameColumnHeader2, 175)
	else KeyedFrameColumn_SetWidth (KeyedFrameColumnHeader2, 190) end

	-- Call SharedXML FauxScrollFrame_Update
	FauxScrollFrame_Update(KeystoneListScrollFrame, numKeystones, KEYSTONES_TO_DISPLAY, KEYED_FRAME_PLAYER_HEIGHT);
end

---------------------------------------------
-- KeyedFrameColumn_SetWidth(frame, width)
--		frame: the frame
--		width: the desired width of the frame
---------------------------------------------
function KeyedFrameColumn_SetWidth(frame, width)
	frame:SetWidth (width);
	_G[frame:GetName () .. "Middle"]:SetWidth (width - 9);
end

---------------------------------------------
-- KeyedFrameTab_SetWidth(frame, width)
--		frame: the frame
--		width: the desired width of the frame
---------------------------------------------
function KeyedFrameTab_SetWidth(frame, width)
	frame:SetWidth (width);
	_G[frame:GetName () .. "Middle"]:SetWidth (width - 9);
end

------------------------------------------------------
-- KeyedFrame_GetKeystoneData(db)
--		db: The database to retrieve entries data from
------------------------------------------------------
function KeyedFrame_GetKeystoneData(db)
	local number = 0;
	local data = {};

	-- Loop through database
	if db then
		for guid, entry in pairs(db) do
			if guid and entry and entry.keystone.keystoneLevel > 0 then
				number = number + 1;
				table.insert(data, entry.keystone);
			end
		end
	end

	-- Sort...
	if KEYED_SORT_FUNCTION then
		table.sort(data, KEYED_SORT_FUNCTION);
	else 
		table.sort(data, Keyed_SortByLevel);
	end
	
	-- Return results
	return number, data;
end

------------------------------------------------------------------------------
-- Keyed_SortKeyed(sort)
--		sort: the sort enum (as a string)
--			enum values: KEYED_SORT_NAME, KEYED_SORT_DUNGEON, KEYED_SORT_LEVEL
------------------------------------------------------------------------------
function Keyed_SortKeyed(sort)
	
	-- Ascend or Descend?
	if KEYED_SORT_TYPE == sort then
		KEYED_SORT_ORDER_DESCENDING = not(KEYED_SORT_ORDER_DESCENDING)	-- Toggle...
	else
		KEYED_SORT_ORDER_DESCENDING = false
	end
	
	-- Set...
	KEYED_SORT_TYPE = sort
	if sort == KEYED_SORT_NAME then
		KEYED_SORT_FUNCTION = Keyed_SortByName
	elseif sort == KEYED_SORT_DUNGEON then
		KEYED_SORT_FUNCTION = Keyed_SortByDungeon
	elseif sort == KEYED_SORT_LEVEL then
		KEYED_SORT_FUNCTION = Keyed_SortByLevel
	else error("Unexpected sort type. (sort=\"" .. tostring(sort or "nil") .. "\"") end

	-- Update
	KeystoneList_Update()
end

-------------------------------------------------------------------------
-- Keyed_SwitchTab(tab)
--		tab: the tab type 
--			enum values: KEYED_GUILD, KEYED_PARTY, KEYED_ALTS, KEYED_BNET
-------------------------------------------------------------------------
function Keyed_SwitchTab(tab)
	KEYED_TAB = tab
	KeystoneList_Update()
end

---------------------------
-- Keyed_SortByName(a, b)
--		a: the first entry
--		b: the second entry
---------------------------
function Keyed_SortByName(a, b)
	local result = false;
	if KEYED_SORT_ORDER_DESCENDING then
		result = a.name > b.name;
		if a.name == b.name then
			result = a.keystoneLevel > b.keystoneLevel;
			if a.keystoneLevel == b.keystoneLevel then
				result = a.keystoneDungeonId > b.keystoneDungeonId;
			end
		end
	else
		result = a.name < b.name;
		if a.name == b.name then
			result = a.keystoneLevel < b.keystoneLevel;
			if a.keystoneLevel == b.keystoneLevel then
				result = a.keystoneDungeonId < b.keystoneDungeonId;
			end
		end
	end
	return result;
end

----------------------------
-- Keyed_SortByDungeon(a, b)
--		a: the first entry
--		b: the second entry
----------------------------
function Keyed_SortByDungeon(a, b)
	local result = false;
	if KEYED_SORT_ORDER_DESCENDING then
		result = a.keystoneDungeonId > b.keystoneDungeonId;
		if a.keystoneDungeonId == b.keystoneDungeonId then
			result = a.name > b.name;
			if a.name == b.name then
				result = a.keystoneLevel > b.keystoneLevel;
			end
		end
	else
		result = a.keystoneDungeonId < b.keystoneDungeonId;
		if a.keystoneDungeonId == b.keystoneDungeonId then
			result = a.name < b.name;
			if a.name == b.name then
				result = a.keystoneLevel < b.keystoneLevel;
			end
		end
	end
	return result;
end

---------------------------
-- Keyed_SortByLevel(a, b)
--		a: the first entry
--		b: the second entry
---------------------------
function Keyed_SortByLevel(a, b)
	local result = false;
	if KEYED_SORT_ORDER_DESCENDING then
		result = a.keystoneLevel > b.keystoneLevel;
		if a.keystoneLevel == b.keystoneLevel then
			result = a.name > b.name;
			if a.name == b.name then
				result = a.keystoneDungeonId > b.keystoneDungeonId;
			end
		end
	else
		result = a.keystoneLevel < b.keystoneLevel;
		if a.keystoneLevel == b.keystoneLevel then
			result = a.name < b.name;
			if a.name == b.name then
				result = a.keystoneDungeonId < b.keystoneDungeonId;
			end
		end
	end
	return result;
end

----------------------------------------------
-- KeyedFrame_ToggleMinimap(self, checked)
--		self: the frame
--		checked: the check state of the button
----------------------------------------------
function KeyedFrame_ToggleMinimap(self, checked)
	if checked then
		KeyedDB.icon.hide = false
		KeyedMinimapButton:Show("Keyed")
	else
		KeyedDB.icon.hide = true
		KeyedMinimapButton:Hide("Keyed")
	end
end
