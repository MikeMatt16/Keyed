-- Prepare locale
local locale = {};

-- Check locale
locale["Commands"] = "Commands";
locale["Version"] = "Version";
locale["Database Wiped"] = "Wiped database...";
locale["Wiped"] = "Wiped";
locale["Incorrect Usage"] = "Incorrect usage...";
locale["Alts"] = "Characters";
locale["Show Minimap Button"] = "Show Minimap Button";
locale["MinimapLine1"] = "Left Click to toggle Keyed Interface";
locale["MinimapLine2"] = "Right click to link your Keystone";
locale["Current Keystone"] = "Current Keystone";
locale["Weekly Best"] = "Weekly Best";

-- Help
locale.commands = 
{
	[" "] = "|cffd6266c/keyed|r " .. "|cffedd28e" .. "Shows the Keyed UI." .. "|r",
	help = "|cffd6266c/keyed|r " .. "help" .. " - " .. "|cffedd28e" .. "Displays command list." .. "|r",
	version = "|cffd6266c/keyed|r " .. "version"  .. " - " .. "|cffedd28e" .. "Displays the current version." .. "|r",
	wipe = "|cffd6266c/keyed|r " .. "clear db" .. " - " .. "|cffedd28e" .. "Displays command list." .. "|r",
};

-- Set to enUS locale
Keyed_Localizations["enUS"] = locale;
