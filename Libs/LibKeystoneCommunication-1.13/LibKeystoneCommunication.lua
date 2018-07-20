--
-- Keystone Communication Library by Strucker
--
-- Shares keystone and character information across Guild and Group addon channels, and among friends list members.

-- Required Libraries:
--   * LibStub
--   * LibRealmInfo
--   * ChatThrottleLib
-- 
-- Required libraries must be loaded BEFORE this one.
-- 
-- To receive keystone entries as they are received by the library, add a listener function:
--
--    KCLib:AddKeystoneListener(function(keystoneEntry,channel,sender) 
--       --Your Logic Here
--    end)
-- 
--    Listeners are passed:
--    1. A Keystone Entry (See Sample Below)
--    2. The channel the keystoneEntry was received through. (WHISPER, PARTY, RAID, INSTANCE_CHAT, GUILD, BNET, PLAYER)
--    3. The character who provided the keystoneEntry information, this will not always be the same as the character the keystoneEntry is about.
--
-- To get the player's most recent keystone entry (Player keystone entries will come through the listener function as well):
--
--    KCLib:GetPlayerKeystone()
--
-- To add keystone entries for the player's alts:
--
--    KCLib:AddAltKeystone(keystoneEntry)
--
-- Sample Keystone Entry:
-- {
--    ["guid"] = "4-0A810590",
--			-- Sourced from UnitGuid. Is guaranteed to remain constant from character creation to character deletion, faction change, or server transfer.
--    ["name"] = "Struckor-Kilrogg",
--    ["level"] = 110,
--    ["faction"] = 1,
--			-- 1 for alliance, 0 for horde.
--    ["class"] = "Death Knight",
--			-- Not localized
--    ["guildName"] = "Transcendence",
--    ["ilvl"] = 999,
--    ["ilvlEquipped"] = 998,
--    ["keystoneWeekIndex"] = 100,
--			-- Used to identify which weekly reset the keystone entry was created during.
--    ["keystoneDungeonId"] = 197,
--			-- Use 'C_ChallengeMode.GetMapInfo(keystoneDungeonId)' to get the dungeon name.
--    ["keystoneLevel"] = 19,
--    ["bestKeystoneDungeonId"] = 207,
--			-- Use 'C_ChallengeMode.GetMapInfo(keystoneDungeonId)' to get the dungeon name.
--    ["bestKeystoneLevel"] = 18,
--    ["altOf"] = "Shastrucker-Kilrogg",
--			-- Can be the same as 'name'.
--    ["lastSeen"] = 99999999999 
--			-- The time in seconds that the keystone entry was last received.
-- }
--
-- Embeddable library. Can run as a standalone addon also, but, really, just embed it!
--

local LIBRARY_NAME = "Keystone Communication Library";
local VERSION = 1.13;
local MSG_PREFIX = "KCLib";
local DELAY_LENGTH = 3;
local WEEK_SECONDS = 604800;
local RESET_WEDNESDAY = 1500447600;
local RESET_TUESDAY = 1500390000;
local KEYSTONE_ITEM_ID = 138019;
local ALT_KEYSTONES = {};
local LISTENERS = {};
local PLAYER_NAME,PLAYER_REALM;
local LAUNCH_TIME;
local PLAYER_GUID;
local playerKeystone;

-- Track which chat channels we are fully synced with.
local guildSynced, groupSynced, friendsSynced = false, false, false;

-- Ensure LibStub is setup.
if not LibStub then
	error(LIBRARY_NAME.. " requires LibStub.");
	return ;
end

-- Ensure ChatThrottleLib is setup.
if not ChatThrottleLib then
	error(LIBRARY_NAME.. " requires ChatThrottleLib.");
	return ;
end

-- Ensure another instance of the library isn't already setup.
local KCLib = LibStub:NewLibrary(LIBRARY_NAME,VERSION)
if not KCLib then 
	debug("An identical or newer version of " .. LIBRARY_NAME .. " has already been initialized");
	return;
end

_G.KCLib = KCLib;

------------------------------------------------------------------------------------------------
-- Add a listener function to be called whenever a new keystone record is received.
------------------------------------------------------------------------------------------------
function KCLib:AddKeystoneListener(listener)
	tinsert(LISTENERS,listener);
end

------------------------------------------------------------------------------------------------
-- Fetch the latest player keystone entry.
--    Use the listener to be informed of updates to the player keystone entry.
------------------------------------------------------------------------------------------------
function KCLib:GetPlayerKeystone()
	if not playerKeystone then
		RefreshPlayerKeystone();
	end
	return playerKeystone;
end

------------------------------------------------------------------------------------------------
-- Add keystone entries for the player's alternate characters.
--    Alt keystone entries will be shared across chat channels along with the player's keystone.
------------------------------------------------------------------------------------------------
function KCLib:AddAltKeystone(keystone)
	tinsert(ALT_KEYSTONES,keystone);
end

-------------------------------------------------------------------------------------
-- Global how many weeks into the mythic+ affix schedule are we?
-------------------------------------------------------------------------------------
function KCLib:GetWeeklyIndex()
	return math.floor((GetServerTime() - LAUNCH_TIME) / WEEK_SECONDS);
end

-------------------------------------------------------------------------------------
-- How many weeks into the mythic+ affix schedule are we?
-------------------------------------------------------------------------------------
local function GetWeeklyIndex() 
	return math.floor((GetServerTime() - LAUNCH_TIME)/ WEEK_SECONDS);
end

-------------------------------------------------------------------------------------
-- Find the link for the player's current keystone by searching through their bag slots.
-------------------------------------------------------------------------------------
local function GetKeystoneLink()
	for bag = 0, NUM_BAG_SLOTS do
		local bagSize = GetContainerNumSlots(bag);
		if bagSize > 0 then
			for i = 1, bagSize do
				if GetContainerItemID(bag, i) == KEYSTONE_ITEM_ID then
					return GetContainerItemLink(bag, i);
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------------
-- Build a new keystone record for the player.
--   If this is the first build of the session or the keystone entry has changed,
--   the new keystone entry will be forwarded to listeners.
------------------------------------------------------------------------------------------------
local function RefreshPlayerKeystone()
	local keystone = {};
	
	keystone.guid = PLAYER_GUID;
	keystone.name = PLAYER_NAME;
	keystone.level = UnitLevel("player");
	keystone.faction = UnitFactionGroup("player") == "Alliance";
	keystone.class = PLAYER_CLASS
	keystone.guildName = GetGuildInfo("player");
	
	local ilvl, ilvlEquipped = GetAverageItemLevel();
	keystone.ilvl = math.floor(ilvl) ;
	keystone.ilvlEquipped = math.floor(ilvlEquipped);
	keystone.keystoneWeekIndex = GetWeeklyIndex();
	keystone.bestKeystoneDungeonId = 0;
	keystone.bestKeystoneLevel = 0;

	-- Include the keystone dungeon and level.
	local keystoneLink = GetKeystoneLink();
	if keystoneLink then
		local dungeonId, level = keystoneLink:gsub('\124', '\124\124'):match(':(%d+):(%d+):(%d+):(%d+):(%d+)');
		keystone.keystoneDungeonId = tonumber(dungeonId);
		keystone.keystoneLevel = tonumber(level);
	else
		keystone.keystoneDungeonId = 0;
		keystone.keystoneLevel = 0;
	end
	
	-- Find the best run of the week.
	local bestKeystoneDungeonId = 0;
	local bestKeystoneLevel = 0;
	local bestLevel, bestDungeon = 0, 0;
	for i, dungeonId in pairs(C_ChallengeMode.GetMapTable()) do
		local _, weeklyBestTime, weeklyBestLevel = C_ChallengeMode.GetMapPlayerStats(dungeonId);
		if weeklyBestLevel and weeklyBestLevel > bestLevel then
			bestKeystoneLevel = weeklyBestLevel;
			bestKeystoneDungeonId = dungeonId;
		end
	end
	keystone.bestKeystoneLevel = bestKeystoneLevel;
	keystone.bestKeystoneDungeonId = bestKeystoneDungeonId;

	-- Check if the keystone entry has changed.
	local changed = false;
	if playerKeystone then
		for key,val in pairs(keystone) do
			if keystone[key] ~= playerKeystone[key] then
				changed = true;
				break;
			end
		end
	else
		changed = true;
	end
	
	-- If the keystone changed, send it to the listeners.
	if changed then
		for _,listener in ipairs(LISTENERS) do
			listener(keystone,"PLAYER",PLAYER_NAME);
		end
	end
	
	playerKeystone = keystone;
	return changed;
end

------------------------------------------------------------------------------------------------
-- Share the given keystone over the given chat channel.
------------------------------------------------------------------------------------------------
local function SendKeystone(requestSync,keystone,channel,target)
	if keystone then
		local msgArray = {};
		msgArray[1] = requestSync;
		msgArray[2] = keystone.guid or "";
		msgArray[3] = keystone.name or "";
		msgArray[4] = keystone.level or "";
		msgArray[5] = keystone.faction and "1" or "0";
		msgArray[6] = keystone.class or "";
		msgArray[7] = keystone.guildName or "";
		msgArray[8] = keystone.ilvl or "";
		msgArray[9] = keystone.ilvlEquipped or "";
		msgArray[10] = keystone.keystoneWeekIndex or "";
		msgArray[11] = keystone.keystoneDungeonId or "";
		msgArray[12] = keystone.keystoneLevel or "";
		msgArray[13] = keystone.bestKeystoneDungeonId or "";
		msgArray[14] = keystone.bestKeystoneLevel or "";

		local msg = table.concat(msgArray, ",") 
		if channel == "BNET" then
			ChatThrottleLib:BNSendGameData("BULK",MSG_PREFIX, msg, target);
		else
			ChatThrottleLib:SendAddonMessage("BULK",MSG_PREFIX, msg, channel, target);
		end
	end
end

------------------------------------------------------------------------------------------------
-- Share the player keystone and all alt keystones to the given channel.
------------------------------------------------------------------------------------------------
local function SendAllKeystones(requestSync,channel,target)
	if playerKeystone then
		SendKeystone(requestSync,playerKeystone,channel,target);
	end
	if ALT_KEYSTONES then
		for _,keystone in ipairs(ALT_KEYSTONES) do
			SendKeystone(0,keystone,channel,target);
		end
	end
end

------------------------------------------------------------------------------------------------
-- Build a keystone out of the incoming message and send it to all listeners.
------------------------------------------------------------------------------------------------
local function ProcessKeystoneMessage(msgArray,channel,sender)
	local keystone = {}	;
	keystone.guid = msgArray[2];
	keystone.name = msgArray[3];
	keystone.level = tonumber(msgArray[4]) or 0;
	keystone.faction = msgArray[5] == "1";
	keystone.class = msgArray[6] or "UNKNOWN";
	keystone.guildName = msgArray[7];
	keystone.ilvl = tonumber(msgArray[8]) or 0;
	keystone.ilvlEquipped = tonumber(msgArray[9]) or 0;
	keystone.keystoneWeekIndex = tonumber(msgArray[10]) or 0;
	keystone.keystoneDungeonId = tonumber(msgArray[11]) or 0;
	keystone.keystoneLevel = tonumber(msgArray[12]) or 0;
	keystone.bestKeystoneDungeonId = tonumber(msgArray[13]) or 0;
	keystone.bestKeystoneLevel = tonumber(msgArray[14]) or 0;
	keystone.altOf = sender;
	keystone.lastSeen = GetServerTime();
	
	-- Insure the keystone is not outdated.
	if keystone.keystoneWeekIndex == GetWeeklyIndex() then
		-- Send to all listeners.
		for _,listener in ipairs(LISTENERS) do
			listener(keystone,channel,sender);
		end
	end
end

------------------------------------------------------------------------------------------------
-- Get the player's current group chat channel.
------------------------------------------------------------------------------------------------
function GetGroupChatChannel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT";
	elseif UnitInRaid("player") then
		return "RAID";
	elseif IsInGroup() then
		return "PARTY";
	end
	return nil;
end

local EventCallables = {}

-- On login, regist addon prefix, check player name, realm, class, and GUID
EventCallables["PLAYER_LOGIN"] = function()
	local region = LibStub('LibRealmInfo'):GetCurrentRegion();
	LAUNCH_TIME = region == "EU" and RESET_WEDNESDAY or RESET_TUESDAY;
	
	local name,realm = UnitFullName("player");
	PLAYER_NAME = name .."-" .. realm;
	PLAYER_REALM = realm;
	_, PLAYER_CLASS = UnitClass("player")
	PLAYER_GUID = string.sub(UnitGUID("player"),8);
	
	RegisterAddonMessagePrefix(MSG_PREFIX);
end

-- When joining a guild mark the guild chat unsynced.
EventCallables["PLAYER_GUILD_UPDATE"] = function()
	guildSynced = false;
	delayedRun = time() + DELAY_LENGTH;
end

-- When joining a group mark the group chat unsynced.
EventCallables["GROUP_JOINED"] = function()
	groupSynced = false;
	delayedRun = time() + DELAY_LENGTH;
end

-- Schedule a check of the player keystone.
EventCallables["BAG_UPDATE"] = function()
	delayedRun = time() + DELAY_LENGTH;
end
EventCallables["PLAYER_ENTERING_WORLD"] = EventCallables["BAG_UPDATE"]
EventCallables["CHALLENGE_MODE_RESET"] = EventCallables["BAG_UPDATE"]
EventCallables["CHALLENGE_MODE_COMPLETED"] = EventCallables["BAG_UPDATE"]
EventCallables["CHALLENGE_MODE_START"] = EventCallables["BAG_UPDATE"]

-- Refresh the player keystone.
EventCallables["CHALLENGE_MODE_MAPS_UPDATE"] = function(...)
	local isNew = RefreshPlayerKeystone();
	
	-- Send keystone changes to guild and resync if needed.
	if GetGuildInfo("player") then
		if not guildSynced then
			SendAllKeystones(1,"GUILD");
		elseif isNew then
			SendKeystone(0, playerKeystone, "GUILD");
		end
		guildSynced = true;
	end
	
	-- Send keystone changes to group and resync if needed
	local groupChatChannel = GetGroupChatChannel();
	if groupChatChannel then
		if not groupSynced then
			SendAllKeystones(1,groupChatChannel);
		elseif isNew then
			SendKeystone(0, playerKeystone, groupChatChannel);
		end
		groupSynced = true;
	end
	
	-- Send keystone changes to friends and resync if needed
	if isNew or not friendsSynced then
		for i = 1, select(2, GetNumFriends()) do
			local fullName = GetFriendInfo(i);
			if not string.match(fullName, "-") then
				fullName = fullName .. "-" .. PLAYER_REALM;
			end
			
			if friendsSynced then
				SendKeystone(0, playerKeystone, "WHISPER",fullName);
			else
				SendAllKeystones(1,"WHISPER",fullName);
			end
		end
		
		if BNConnected() then
			for i = 1, BNGetNumFriends() do
				local characterName, bnetIDGameAccount, client = select(5,BNGetFriendInfo(i))
				if bnetIDGameAccount and characterName and client == "WoW" then
					if friendsSynced then
						SendKeystone(0, playerKeystone, "BNET", bnetIDGameAccount);
					else
						SendAllKeystones(1, "BNET", bnetIDGameAccount);
					end
				end
			end
		end
		friendsSynced = true;
	end
end

-- Process incoming addon messages and extract keystones.
EventCallables["CHAT_MSG_ADDON"] = function(prefix, msg, channel, sender)
	if prefix == MSG_PREFIX and sender ~= PLAYER_NAME then
		local msgParts = {strsplit(",", msg)};
		if msgParts[1] == "1" then
			SendAllKeystones(0, channel, sender);
		end
		ProcessKeystoneMessage(msgParts,channel,sender);
	end
end

-- Process incoming addon messages and extract keystones.
EventCallables["BN_CHAT_MSG_ADDON"] = function(prefix, msg, channel, sender)
	if prefix == MSG_PREFIX and sender ~= PLAYER_NAME then
		local msgParts = {strsplit(",", msg)};
		if msgParts[1] == "1" then
			SendAllKeystones(0,"BNET", sender);
		end
		
		local characterName, _, realm = select(2,BNGetGameAccountInfo(sender));
		ProcessKeystoneMessage(msgParts,"BNET",characterName .. "-" .. realm);
	end
end

-- A frame for managing events.
local eventHandler = CreateFrame("Frame", nil, WorldFrame);

-- Trigger keystone updates after the delay has expired.
eventHandler:SetScript("OnUpdate", function()  
	if delayedRun and delayedRun > 0 and delayedRun < time() then
		delayedRun = 0;
		C_MythicPlus.RequestMapInfo();
		C_MythicPlus.RequestRewards();
	end
end)

-- Pass events onto the correct function in 'EventCallables'.
eventHandler:SetScript("OnEvent", function (self, event, ...)
	EventCallables[event](...);
end)

-- Register all events in the 'EventCallables' table.
for event in pairs(EventCallables) do
	eventHandler:RegisterEvent(event);
end