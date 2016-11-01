KEYSTONE_LIST_HEIGHT = 384
KEYSTONE_LIST_COUNT = 16
KEYSTONE_DATA = {}

function KeyedFrame_OnLoad (self)
	-- Setup...
	for i = 2, KEYSTONE_LIST_COUNT, 1 do
		local button = CreateFrame ("Button", "KeystoneFrameButton" .. i, KeyedFrame, "KeystoneButtonTemplate")
		button:SetPoint ("TOP", _G["KeystoneFrameButton" .. (i - 1)], "BOTTOM")
		button:SetID (i)
	end
end

function KeyedFrameKeystoneList_Update (self)

	-- Load Data from Database...
	KEYSTONE_DATA = KEYSTONE_DATA or {}
	table.wipe(KEYSTONE_DATA)
	for name, entry in pairs(Keyed.db.factionrealm) do
		if name and entry.name ~= "" then table.insert(KEYSTONE_DATA, entry) end
	end
	
	local offset = FauxScrollFrame_GetOffset(self)
	local num_entries = #KEYSTONE_DATA
	local name, index, entry, entryText, keystone
	local count = num_entries
	if num_entries > KEYSTONE_LIST_COUNT then
		count = KEYSTONE_LIST_COUNT
	end
	for n = 1, KEYSTONE_LIST_COUNT, 1 do
		index = offset + n
		entry = _G["KeystoneFrameButton" .. n]
		entry.entryIndex = index
		if KEYSTONE_DATA[index] then
			entryText = _G["KeystoneFrameButton" .. n .. "Name"]
			keystone = _G["KeystoneFrameButton" .. n .. "Keystone"]
			name = KEYSTONE_DATA[index].name
			entryText:SetText(name)
			if #KEYSTONE_DATA[index].keystones > 0 then
				keystone.link = KEYSTONE_DATA[index].keystones[1]
				keystone:Show()
			else
				keystone:Hide()
			end
			entry:Show()
		else
			entry:Hide()
		end
	end
	
	FauxScrollFrame_Update(KeyedFrameKeystoneList, num_entries, KEYSTONE_LIST_COUNT, KEYSTONE_LIST_HEIGHT)
end

function KeystoneButton_OnEnter(self, link)
	if link then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end
end

function KeyedMinimapButtonReposition()
	KeyedMinimapButton:SetPoint("TOPLEFT","Minimap","TOPLEFT",52-(80*cos(Keyed.db.profile.MinimapPos)),(80*sin(Keyed.db.profile.MinimapPos))-52)
end

-- Only while the button is dragged this is called every frame
function KeyedMinimapButtonDraggingFrameOnUpdate()

	local xpos,ypos = GetCursorPosition()
	local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom()

	xpos = xmin-xpos/UIParent:GetScale()+70 -- get coordinates as differences from the center of the minimap
	ypos = ypos/UIParent:GetScale()-ymin-70

	Keyed.db.profile.MinimapPos = math.deg(math.atan2(ypos,xpos)) -- save the degrees we are relative to the minimap center
	KeyedMinimapButtonReposition() -- move the button
end

-- Put your code that you want on a minimap button click here.  arg1="LeftButton", "RightButton", etc
function KeyedMinimapButtonOnClick()
	KeyedFrameKeystoneList_Update(KeyedFrameKeystoneList)
	KeyedFrame:Show()
end