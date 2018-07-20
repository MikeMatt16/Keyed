--[[
KeyedLib by Click16

Shares keystone and character information across guild, friends, and group.

Required Libraries:
	* LibStub
	* LibRealmInfo
	* ChatThrottleLib

Required libraries must be loaded before this one.
--]]

local MAJOR, MINOR = "KeyedLib-1.0", 1;
local LibStub = assert(LibStub, MAJOR .. " requires LibStub");
local libRealmInfo = assert(LibStub("LibRealmInfo"), MAJOR .. " requires LibRealmInfo");
local ChatThrottleLib = assert(ChatThrottleLib, MAJOR .. " requires ChatThrottleLib");
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR);
if not lib then	return end

local standalone = (...) == MAJOR;
local debugMode = true;	--[[Enabling debug mode will override the default behavior of the debug(...) function.]]

local function debug(...)
	if standalone and not(debugMode) then
		print("|cffd9d1ff[".. MAJOR .."]|r", ...);
	end
end

local MSG_PREFIX = "KeyedLib";
local DELAY_LENGTH = 3;
local WEEK_SECONDS = 604800;
local RESET_WEDNESDAY = 1500447600;
local RESET_TUESDAY = 1500390000;
local KEYSTONE_ITEM_ID = 138019;
local LISTENERS = {};

local playerKeystone = nil;

------------------------------------------------------------------------------
-- KeyedLib:AddKeystoneListener(listenerFunc)
--	Adds a listener function to be called whenever a new Keystone is received.
--		listenerFunc: the function to be called when a Keystone is received.
------------------------------------------------------------------------------
function lib:AddKeystoneListener(listenerFunc)
	tinsert(LISTENERS, listenerFunc);
end

-- Load message
debug("Keyed Lib loaded. :)");

_G.KeyedLib = lib;
