--[[
KeyedLib by Click16 and Strucker

Shares keystone and character information across guild, friends, and group.

Required Libraries:
	* LibStub
	* LibRealmInfo
	* ChatThrottleLib

Required libraries must be loaded before this one.

|cffa335ee|Hkeystone:138019:198:3:0:0:0:0|h[Keystone: Darkheart Thicket (3)]|h|r
--]]

local MAJOR, MINOR = "KeyedLib-1.0", 2;
local LibStub = assert(LibStub, MAJOR .. " requires LibStub");
local libRealmInfo = assert(LibStub("LibRealmInfo"), MAJOR .. " requires LibRealmInfo");
local ChatThrottleLib = assert(ChatThrottleLib, MAJOR .. " requires ChatThrottleLib");
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR);
if not lib then	return end
_G.KeyedLib = lib;

local standalone = (...) == MAJOR;
local debugMode = false;	--[[Enabling debug mode will override the default behavior of the debug(...) function.]]

local EVENT_HANDLERS = {};
local MSG_PREFIX = "KeyedLib_2";
local DELAY_LENGTH = 3;
local WEEK_SECONDS = 604800;
local RESET_WEDNESDAY = 1500447600;
local RESET_TUESDAY = 1500390000;
local KEYSTONE_ITEM_ID = 158923;
local ALT_KEYSTONES = {};
local GUILD_KEYSTONES = {};
local LISTENERS = {};
local PLAYER_NAME, PLAYER_REALM, PLAYER_GUILD;
local LAUNCH_TIME;
local PLAYER_GUID;
local delayedRun = 0;

local maps = C_ChallengeMode.GetMapTable();
local guildSynced, groupSynced, friendsSynced = false, false, false;
local playerKeystone = nil;

local function debug(...)
	--@debug@
	if standalone or debugMode then
		print("|cffd9d1ff[".. MAJOR .."]|r", ...);
	end
	--@end-debug@
end

local function scheduleUpdate()
	delayedRun = time() + DELAY_LENGTH;
end

local function GetPlayerRecord()
	local record = {}
	record.guid = PLAYER_GUID;
	record.name = PLAYER_NAME;
	record.level = UnitLevel("player");
	record.faction = UnitFactionGroup("player") == "Alliance";
	record.class = PLAYER_CLASS;
	record.guildName = GetGuildInfo("player");
	local ilvl, ilvlEquipped = GetAverageItemLevel();
	record.ilvl = math.floor(ilvl);
	record.ilvlEquipped = math.floor(ilvlEquipped);
	record.keystoneWeekIndex = lib:GetWeeklyIndex();
	record.bestKeystoneDungeonId = 0;
	record.bestKeystoneLevel = 0;
	local keystoneLink = lib:GetKeystoneLink();
	if keystoneLink then
		local _, dungeonId, level = keystoneLink:gsub('\124', '\124\124'):match(':(%d+):(%d+):(%d+):(%d+):(%d+)');
		record.keystoneDungeonId = tonumber(dungeonId);
		record.keystoneLevel = tonumber(level);
	else
		record.keystoneDungeonId = 0;
		record.keystoneLevel = 0;
	end
	local bestKeystoneDungeonId = 0;
	local bestKeystoneLevel = 0;
	local bestLevel = 0;

	local weeklySortedMaps = {}
	for i = 1, #maps do
		local _, weeklyLevel = C_MythicPlus.GetWeeklyBestForMap(maps[i]);
		weeklyLevel = weeklyLevel or 0;
		tinsert(weeklySortedMaps, { id = maps[i], level = weeklyLevel });
	end
	table.sort(weeklySortedMaps, function(a, b) return a.level > b.level end);
	if #weeklySortedMaps > 0 then
		bestKeystoneLevel = weeklySortedMaps[1].level;
		bestKeystoneDungeonId = weeklySortedMaps[1].id;
	end
	record.bestKeystoneLevel = bestKeystoneLevel;
	record.bestKeystoneDungeonId = bestKeystoneDungeonId;
	record.timeGenerated = GetServerTime();
	return record;
end

local function RefreshPlayerKeystone()
	-- Get player record
	record = GetPlayerRecord();

	-- Check if record has changed
	local changed = false;
	if playerKeystone then
		for key, val in pairs(record) do
			if record[key] ~= playerKeystone[key] then
				changed = true;
				break;
			end
		end
	else changed = true end
	
	-- If the keystone changed, send it to the listeners.
	if changed then
		debug("Keystone changed, updating self...");
		for _, listener in ipairs(LISTENERS) do listener(record, nil, sender); end
	end
	
	playerKeystone = record;
	return changed;
end

local function SendKeystone(requestSync, keystone, channel, target)
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
		msgArray[15] = keystone.timeGenerated or "";

		local msg = table.concat(msgArray, ",");
		if channel == "BNET" then
			BNSendGameData(target, MSG_PREFIX, msg);
		else
			ChatThrottleLib:SendAddonMessage("BULK", MSG_PREFIX, msg, channel, target);
		end
	end
end

local function SendAllKeystones(requestSync, channel, target)
	if playerKeystone then
		SendKeystone(requestSync, playerKeystone, channel, target);
	end
	if ALT_KEYSTONES then
		for _, keystone in ipairs(ALT_KEYSTONES) do
			if keystone.guid ~= PLAYER_GUID then
				SendKeystone(0, keystone, channel, target);
			end
		end
	end
	if GUILD_KEYSTONES and channel == "GUILD" then
		for _, keystone in ipairs(GUILD_KEYSTONES) do
			if keystone.guid ~= PLAYER_GUID then
				SendKeystone(0, keystone, channel, target);
			end
		end
	end
end

local function ProcessKeystoneMessage(msgArray, channel, sender)
	local record = {};
	record.guid = msgArray[2];
	record.name = msgArray[3];
	record.level = tonumber(msgArray[4]) or 0;
	record.faction = msgArray[5] == "1";
	record.class = msgArray[6] or "UNKNOWN";
	record.guildName = msgArray[7];
	record.ilvl = tonumber(msgArray[8]) or 0;
	record.ilvlEquipped = tonumber(msgArray[9]) or 0;
	record.keystoneWeekIndex = tonumber(msgArray[10]) or 0;
	record.keystoneDungeonId = tonumber(msgArray[11]) or 0;
	record.keystoneLevel = tonumber(msgArray[12]) or 0;
	record.bestKeystoneDungeonId = tonumber(msgArray[13]) or 0;
	record.bestKeystoneLevel = tonumber(msgArray[14]) or 0;
	record.timeGenerated = tonumber(msgArray[15]) or 0;
	record.altOf = sender;

	if record.keystoneWeekIndex == lib:GetWeeklyIndex() then
		debug("Keystone record update", sender, channel);
		for _, listener in ipairs(LISTENERS) do listener(record, channel, sender); end
	end
end

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

------------------
-- KeyedLib:Debug()
--	Debug. What else do you need?
------------------
function lib:Debug(...)
	debug(...);
end

----------------------------------------
-- KeyedLib:GetPlayerGuild()
--	Gets and returns the player's guild.
----------------------------------------
function lib:GetPlayerGuild()
	return PLAYER_GUILD or "";
end

---------------------------------------------------
-- KeyedLib:GetKeystoneLink()
--	Returns the hyperlink of the player's keystone.
---------------------------------------------------
function lib:GetKeystoneLink()
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

------------------------------------------------------------------------------
-- KeyedLib:AddKeystoneListener(listenerFunc)
--	Adds a listener function to be called whenever a new Keystone is received.
--		listenerFunc: the function to be called when a Keystone is received.
------------------------------------------------------------------------------
function lib:AddKeystoneListener(listenerFunc)
	assert(listenerFunc, "Listener function cannot be nil.");
	assert(type(listenerFunc) == "function", "Function type expected.");
	debug("Added Keystone listener function.");
	tinsert(LISTENERS, listenerFunc);
end

--------------------------------------------------------------------
-- KeyedLib:AddAltKeystone(keystone)
--	Adds an alternate character's keystone record to be broadcasted.
--		keystone: the keystone record to add.
--------------------------------------------------------------------
function lib:AddAltKeystone(keystone)
	assert(keystone, "keystone cannot be nil.");
	tinsert(ALT_KEYSTONES, keystone);
end

---------------------------------------------------
-- KeyedLib:AddGuildKeystone(keystone)
--	Adds a guild keystone record to be broadcasted.
--		keystone: the keystone record to add.
---------------------------------------------------
function lib:AddGuildKeystone(keystone)
	assert(keystone, "keystone cannot be nil.");
	tinsert(GUILD_KEYSTONES, keystone);
end

-----------------------------------------
-- KeyedLib:GetPlayerKeystone()
--	Returns the player's Keystone record.
-----------------------------------------
function lib:GetPlayerKeystone()
	if not playerKeystone then
		RefreshPlayerKeystone();
	end
	return playerKeystone;
end

-------------------------------------------
-- KeyedLib:GetWeeklyIndex()
--	Returns the current Mythic+ week index.
-------------------------------------------
function lib:GetWeeklyIndex()
	if not LAUNCH_TIME then return 0; end	-- If LAUNCH_TIME isn't defined, then return zero.
	return math.floor((GetServerTime() - LAUNCH_TIME) / WEEK_SECONDS);
end

------------------------------------------------------------------------------
-- KeyedLib:QueueSynchronization()
--	Sends trigger for a synchronization of guild, friend, and group Keystones.
------------------------------------------------------------------------------
function lib:QueueSynchronization()
	debug("Synchronization queued.");
	guildSynced, groupSynced, friendsSynced = false, false, false;
	scheduleUpdate();
end

-- Friends list update
EVENT_HANDLERS["FRIENDLIST_UPDATE"] = function()
	friendsSynced = false;
	scheduleUpdate();
end

-- Group update event
EVENT_HANDLERS["GROUP_ROSTER_UPDATE"] = function()
	groupSynced = false;
	scheduleUpdate();
end

-- Group joined event
EVENT_HANDLERS["GROUP_JOINED"] = function()
	groupSynced = false;
	scheduleUpdate();
end

-- Guild update event
EVENT_HANDLERS["PLAYER_GUILD_UPDATE"] = function()
	PLAYER_GUILD = select(1, GetGuildInfo("player"));
	guildSynced = false;
	scheduleUpdate();
end

-- Various potential Keystone update events
EVENT_HANDLERS["BAG_UPDATE"] = scheduleUpdate();
EVENT_HANDLERS["PLAYER_ENTERING_WORLD"] = scheduleUpdate()
EVENT_HANDLERS["CHALLENGE_MODE_RESET"] = scheduleUpdate()
EVENT_HANDLERS["CHALLENGE_MODE_COMPLETED"] = scheduleUpdate()
EVENT_HANDLERS["CHALLENGE_MODE_START"] = scheduleUpdate()

-- AddOn loaded event
EVENT_HANDLERS["ADDON_LOADED"] = function()
end

-- Player Login event
EVENT_HANDLERS["PLAYER_LOGIN"] = function()
	-- Get region info
	local region = libRealmInfo:GetCurrentRegion();
	LAUNCH_TIME = region == "EU" and RESET_WEDNESDAY or RESET_TUESDAY;

	-- Get player info
	local name, realm = UnitFullName("player");
	PLAYER_NAME = name .. "-" .. realm;
	PLAYER_REALM = realm;
	_, PLAYER_CLASS = UnitClass("player");
	PLAYER_GUID = string.sub(UnitGUID("player"), 8);

	-- Register chat prefix
	C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX);

	-- Get Keystone
	lib:GetPlayerKeystone();
end

-- Refresh the player Keystone.
EVENT_HANDLERS["CHALLENGE_MODE_MAPS_UPDATE"] = function(...)
	local isNew = RefreshPlayerKeystone();

	-- Syncronize with guild?
	if GetGuildInfo("player") then
		debug("Guild sync...")
		if not(guildSynced) then
			SendAllKeystones(1, "GUILD");
		elseif isNew then
			SendKeystone(0, playerKeystone, "GUILD");
		end
		guildSynced = true;
	end

	-- Syncronize with group?
	local groupChatChannel = GetGroupChatChannel();
	if groupChatChannel then
		debug("Group sync...")
		if not(groupSynced) then
			SendAllKeystones(1, groupChatChannel);
		elseif isNew then
			SendKeystone(0, playerKeystone, groupChatChannel);
		end
		groupSynced = true;
	end

	-- Syncronize with friends?
	if isNew or not(friendsSynced) then
		debug("Friends sync...")
		for i = 1, select(2, GetNumFriends()) do
			local fullName = select(1, GetFriendInfo(i));
			if not(string.match(fullName, "-")) then
				fullName = fullName .. "-" .. PLAYER_REALM;
			end

			if friendsSynced then
				SendKeystone(1, "WHISPER", fullName);
			else
				SendAllKeystones(1, "WHISPER", fullName);
			end
		end

		if BNConnected() then
			for i = 1, select(1, BNGetNumFriends()) do
				local bnetIDGameAccount, client = select(6, BNGetFriendInfo(i));
				if bnetIDGameAccount and client == BNET_CLIENT_WOW and CanCooperateWithGameAccount(bnetIDGameAccount) then
					local presenceID select(16, BNGetGameAccountInfo(bnetIDGameAccount));
					if friendsSynced then
						SendKeystone(1, playerKeystone, "BNET", bnetIDGameAccount);
					else
						SendAllKeystones(1, "BNET", bnetIDGameAccount);
					end
				end
			end
		end

		friendsSynced = true;
	end
end

-- Process incoming AddOn messages and extract keystones
EVENT_HANDLERS["CHAT_MSG_ADDON"] = function(prefix, msg, channel, sender)
	if prefix == MSG_PREFIX then
		local msgParts = { strsplit(",", msg) };
		if msgParts[1] == "1" then
			SendAllKeystones(0, channel, sender);
		end
		ProcessKeystoneMessage(msgParts, channel, sender);
	end
end

-- Process incoming Battle.net AddOn messages and extract keystones
EVENT_HANDLERS["BN_CHAT_MSG_ADDON"] = function(prefix, msg, channel, sender)
	if prefix == MSG_PREFIX and sender ~= PLAYER_NAME then
		local msgParts = { strsplit(",", msg) };
		local characterName, _, realm = BNGetGameAccountInfo(sender);
		if msgParts[1] == "1" then
			SendAllKeystones(0, "BNET", sender);
		end
		ProcessKeystoneMessage(msgParts, "BNET", sender);
	end
end

-- Create frame to handle events.
local eventHandlerFrame = CreateFrame("Frame", nil, WorldFrame);

-- Trigger keystone updates
eventHandlerFrame:SetScript("OnUpdate", function()
	if delayedRun and delayedRun > 0 and delayedRun < time() then
		delayedRun = 0;
		C_MythicPlus.RequestMapInfo();
		C_MythicPlus.RequestRewards();
	end
end);

-- Handle events...
eventHandlerFrame:SetScript("OnEvent", function(self, event, ...)
	if EVENT_HANDLERS[event] then
		EVENT_HANDLERS[event](...);
	end
end);

-- Register events in the EVENT_HANDLERS table
for event, handler in pairs(EVENT_HANDLERS) do
	eventHandlerFrame:RegisterEvent(event);
end
