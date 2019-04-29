-- Prepare locale
local locale = {};

-- Setup basic strings
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

-- Setup command list
locale.commands = 
{
	[1] = "|cffd6266c/keyed|r " .. "|cffedd28e" .. "Shows the Keyed UI." .. "|r",
	[2] = "|cffd6266c/keyed|r " .. "help" .. " - " .. "|cffedd28e" .. "Displays command list." .. "|r",
	[3] = "|cffd6266c/keyed|r " .. "version"  .. " - " .. "|cffedd28e" .. "Displays the current version." .. "|r",
	[4] = "|cffd6266c/keyed|r " .. "clear [guild/friends/characters/all]" .. " - " .. "|cffedd28e" .. "Clear the database entries for the selected option." .. "|r",
};

-- Set to enUS locale
Keyed_Localizations["enUS"] = locale;
