KEYED_TUESDAY = 345600
KEYED_WEEK = 604800
KEYED_DEPLETED_MASK = 4194304
KEYED_FRAME_PLAYER_HEIGHT = 16
KEYSTONES_TO_DISPLAY = 19
KEYED_SORT_ORDER_DESCENDING = false
KEYED_SORT_FUNCTION = Keyed_SortByLevel
KEYED_SORT_TYPE = "level"
INSTANCE_NAMES = {
	-- Raids
	["1520"] = "The Emerald Nightmare",
	["1530"] = "The Nighthold",

	-- Dungeons
	["1501"] = "Black Rook Hold",
	["1571"] = "Court of Stars",
	["1466"] = "Darkheart Thicket",
	["1456"] = "Eye of Azshara",
	["1477"] = "Halls of Valor",
	["1492"] = "Maw of Souls",
	["1458"] = "Neltharion's Lair",
	["1516"] = "The Arcway",
	["1493"] = "Vault of the Wardens",
	["1544"] = "Violet Hold",
}

function KeyedFrame_OnShow (self)
	-- Get Keystones...
	Keyed:BroadcastKeystoneRequest(true)
end

function KeystoneListFrame_OnLoad (self)
	-- Register for events...
	KeyedFrame:RegisterAllEvents()

	-- Create List Items
	for i = 2, KEYSTONES_TO_DISPLAY do
		local button = CreateFrame ("Button", "KeystoneListFrameButton" .. i, KeystoneListFrame, "KeyedFramePlayerButtonTemplate")
		button:SetID (i)
		button:SetPoint ("TOP", _G["KeystoneListFrameButton" .. (i - 1)], "BOTTOM")
	end

	-- Set Version
	local version = GetAddOnMetadata("Keyed", "Version")
	if version then KeyedVersionText:SetText("v" .. version) end

	-- Get Keystones...
	Keyed:BroadcastKeystoneRequest(true)
end

function KeyedFrameGetKeystonesButton_OnClick()
	-- Request...
	if Keyed then
		Keyed:BroadcastKeystoneRequest()
	end
end

function KeystoneList_Update ()
	local numKeystones, keystoneData = GetKeystoneData()
	local name, dungeon, level
	local button, buttonText
	local columnTable
	local keystoneOffset = FauxScrollFrame_GetOffset (KeystoneListScrollFrame)
	local keystoneIndex
	local showScrollBar = nil;
	if numKeystones > KEYSTONES_TO_DISPLAY then
		showScrollBar = 1
	end

	local SetDepleted = function(fontString)
		fontString:SetTextColor(0.6, 0.6, 0.6, 1.0)
	end
	local SetHighlighted = function(fontString)
		fontString:SetTextColor(GameFontHighlightSmall:GetTextColor())
	end
	local SetNormal = function(fontString)
		fontString:SetTextColor(GameFontNormalSmall:GetTextColor())
	end

	for i=1, KEYSTONES_TO_DISPLAY, 1 do
		keystoneIndex = keystoneOffset + i
		button = _G["KeystoneListFrameButton" .. i]
		button.keystoneIndex = keystoneIndex
		button.link = nil
		if keystoneIndex < #keystoneData then
			button.link = keystoneData[keystoneIndex].link
			button.depleted = keystoneData[keystoneIndex].depleted
			buttonText = _G["KeystoneListFrameButton" .. i .. "Name"];
			buttonText:SetText (keystoneData[keystoneIndex].name);
			if button.depleted then SetDepleted(buttonText) else SetNormal(buttonText) end
			buttonText = _G["KeystoneListFrameButton" .. i .. "Dungeon"];
			buttonText:SetText (keystoneData[keystoneIndex].dungeon);
			if button.depleted then SetDepleted(buttonText) else SetHighlighted(buttonText) end
			if showScrollBar then
				buttonText:SetWidth (170)
			else
				buttonText:SetWidth (185)
			end
			buttonText = _G["KeystoneListFrameButton" .. i .. "Level"];
			buttonText:SetText (keystoneData[keystoneIndex].level);
			if button.depleted then SetDepleted(buttonText) else SetHighlighted(buttonText) end
			button:Show()
		else
			button:Hide()
		end
	end

	if showScrollBar then
		KeyedFrameColumn_SetWidth (KeyedFrameColumnHeader2, 175);
	else
		KeyedFrameColumn_SetWidth (KeyedFrameColumnHeader2, 190);
	end

	FauxScrollFrame_Update (KeystoneListScrollFrame, numKeystones, KEYSTONES_TO_DISPLAY, KEYED_FRAME_PLAYER_HEIGHT);
end

function KeyedFrameColumn_SetWidth (frame, width)
	frame:SetWidth (width);
	_G[frame:GetName () .. "Middle"]:SetWidth (width - 9);
end

function GetKeystoneData ()
	-- Prepare
	local tuesdays = math.floor((GetServerTime() + KEYED_TUESDAY) / KEYED_WEEK)
	local name, dungeon, level, id, affexes
	local number = 0
	local data = {}

	-- Loop through database
	if Keyed and Keyed.db.factionrealm then
		for uid, entry in pairs (Keyed.db.factionrealm) do
			if entry.uid and entry.name and entry.name ~= "" and entry.keystones and (#entry.keystones > 0) then
				name, dungeon, level, id, affexes = ExtractKeystoneData (entry.keystones[1])
				if math.floor((entry.time + KEYED_TUESDAY) / KEYED_WEEK) == tuesdays then
					number = number + 1
					table.insert (data, {
						name = entry.name,
						dungeon = dungeon,
						dungeonId = tonumber(id),
						level = tonumber(level),
						depleted = (bit.band(affexes, KEYED_DEPLETED_MASK) ~= KEYED_DEPLETED_MASK),
						link = entry.keystones[1]
					})
				end
			end
		end
	end

	-- Sort...
	if KEYED_SORT_FUNCTION then
		table.sort (data, KEYED_SORT_FUNCTION)
	else
		table.sort(data, Keyed_SortByLevel)
	end
	
	-- Return results
	return number, data
end

function ExtractKeystoneData (hyperlink)
	-- |cffa335ee|Hitem:138019::::::::110:63:6160384:::1466:7:5:4:1:::|h[Mythic Keystone]|h|r
	local _, color, string, name, _, _ = strsplit ("|", hyperlink, 6)
	local Hitem, id, _, _, _, _, _, _, _, reqLevel, _, affexes, _, _, instMapId, plus, _, _, _, _, _ = strsplit(':', string, 21)
	-- Return Tom foolery for now...
	local instanceName = "Unknown (" .. instMapId .. ")"
	if INSTANCE_NAMES[tostring(instMapId)] then instanceName = INSTANCE_NAMES[tostring(instMapId)] end
	return name, instanceName, plus, instMapId, affexes
end

function Keyed_SortKeyed (sort)
	
	-- Ascend or Descend?
	if KEYED_SORT_TYPE == sort then
		KEYED_SORT_ORDER_DESCENDING = not(KEYED_SORT_ORDER_DESCENDING)	-- Toggle...
	else
		KEYED_SORT_ORDER_DESCENDING = false
	end
	
	-- Set...
	KEYED_SORT_TYPE = sort
	if sort == "name" then
		KEYED_SORT_FUNCTION = Keyed_SortByName
	elseif sort == "dungeon" then
		KEYED_SORT_FUNCTION = Keyed_SortByDungeon
	elseif sort == "level" then
		KEYED_SORT_FUNCTION = Keyed_SortByLevel
	end

	-- Update
	KeystoneList_Update()
end

function Keyed_SortByName (a, b)
	if KEYED_SORT_ORDER_DESCENDING then
		return a.name > b.name
	else
		return a.name < b.name
	end
end

function Keyed_SortByDungeon (a, b)
	if KEYED_SORT_ORDER_DESCENDING then
		return a.dungeon > b.dungeon
	else
		return a.dungeon < b.dungeon
	end
end

function Keyed_SortByLevel (a, b)
	if KEYED_SORT_ORDER_DESCENDING then
		return a.level < b.level
	else
		return a.level > b.level
	end
end

function KeyedFrame_ToggleMinimap(self, checked)
	if checked then
		Keyed.db.profile.minimap.hide = false
		KeyedMinimapButton:Show("Keyed")
	else
		Keyed.db.profile.minimap.hide = true
		KeyedMinimapButton:Hide("Keyed")
	end
end