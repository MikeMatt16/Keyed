KEYED_FRAME_PLAYER_HEIGHT = 16
KEYSTONES_TO_DISPLAY = 19
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

function KeystoneListFrame_OnLoad (self)
	-- Create List Items
	for i = 2, KEYSTONES_TO_DISPLAY do
		local button = CreateFrame ("Button", "KeystoneListFrameButton" .. i, KeystoneListFrame, "KeyedFramePlayerButtonTemplate")
		button:SetID (i)
		button:SetPoint ("TOP", _G["KeystoneListFrameButton" .. (i - 1)], "BOTTOM")
	end
end

function KeyedFrameGetKeystonesButton_OnClick()
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

	for i=1, KEYSTONES_TO_DISPLAY, 1 do
		keystoneIndex = keystoneOffset + i
		button = _G["KeystoneListFrameButton" .. i]
		button.keystoneIndex = keystoneIndex
		button.link = nil
		if keystoneIndex < #keystoneData then
			button.link = keystoneData[keystoneIndex].link
			buttonText = _G["KeystoneListFrameButton" .. i .. "Name"];
			buttonText:SetText (keystoneData[keystoneIndex].name);
			buttonText = _G["KeystoneListFrameButton" .. i .. "Dungeon"];
			buttonText:SetText (keystoneData[keystoneIndex].dungeon);
			if showScrollBar then
				buttonText:SetWidth (170)
			else
				buttonText:SetWidth (185)
			end
			buttonText = _G["KeystoneListFrameButton" .. i .. "Level"];
			buttonText:SetText (keystoneData[keystoneIndex].level);
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
	local name, dungeon, level
	local number = 0
	local data = {}
	local sortedData = {}

	-- Loop through database
	if Keyed and Keyed.db.factionrealm then
		for uid, entry in pairs (Keyed.db.factionrealm) do
			if entry.uid and entry.name and entry.name ~= "" and entry.keystones and (#entry.keystones > 0) then
				name, dungeon, level = ExtractKeystoneData (entry.keystones[1])
				number = number + 1
				table.insert (data, {
					name = entry.name,
					dungeon = dungeon,
					level = level,
					link = entry.keystones[1]
			})
			end
		end
	end

	-- Return results
	return number, data
end

function ExtractKeystoneData (hyperlink)
	-- |cffa335ee|Hitem:138019::::::::110:63:6160384:::1466:7:5:4:1:::|h[Mythic Keystone]|h|r
	local _, color, string, name, _, _ = strsplit ("|", hyperlink, 6)
	local Hitem, id, _, _, _, _, _, _, _, reqLevel, _, _, _, _, instMapId, plus, _, _, _, _, _ = strsplit(':', string, 21)
	-- Return Tom foolery for now...
	local instanceName = "Unknown (" .. instMapId .. ")"
	if INSTANCE_NAMES[tostring(instMapId)] then instanceName = INSTANCE_NAMES[tostring(instMapId)] end
	return name, instanceName, plus
end

function Keyed_SortKeyed (sort)

end