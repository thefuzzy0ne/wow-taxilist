local addonName, shared = ...

local addon = {}
local frame = TaxiListFrame
local flightPoints = {}
local isSetup = false
local taxiFrame


addon.debug = true -- Enables debug messages and makes the addon global.

frame:SetScript("OnEvent", function(this, event, ...) this[event](this, ...) end)
frame:RegisterEvent("TAXIMAP_OPENED")

-------------------------------
function frame:TAXIMAP_OPENED()
-------------------------------
	addon.UpdateFlightPoints()
	frame.filterText:SetText("")

	if not isSetup then 
		addon.DoSetup()
	else
		-- This gets called during setup.
		addon.UpdateButtons() 
	end

	frame:Show()
end

---------------------
function addon.DoSetup()
---------------------
	if isSetup then return end

	isSetup = true
	taxiFrame = FlightMapFrame

	if addon.debug then
		_G[addonName] = addon
		addon.frame = frame
	end

	addon.InitializeFrame()
	addon.InitializeScrollFrame()
end

--------------------------------
function addon.InitializeFrame()
--------------------------------
	frame:SetPoint("TOPLEFT", taxiFrame, "TOPRIGHT")
	frame:SetHeight(taxiFrame:GetHeight())
	frame:SetWidth(262)
	frame:SetParent(taxiFrame)

	frame.CloseButton:SetScript("OnClick", function()
		taxiFrame.BorderFrame.CloseButton:Click()
		frame:Hide()
	end)

	frame.filterText:SetScript("OnTextChanged", addon.UpdateButtons)
end

--------------------------------------
function addon.InitializeScrollFrame()
--------------------------------------
	local scrollFrame = frame.scrollFrame
	scrollFrame.update = addon.UpdateButtons

	HybridScrollFrame_CreateButtons(scrollFrame, "TaxiListButtonTemplate", 0, 0)
	HybridScrollFrame_SetDoNotHideScrollBar(scrollFrame, true)
end

------------------------------------
function addon.UpdateFlightPoints()
------------------------------------
	local numNodes = NumTaxiNodes();
	table.wipe(flightPoints)
	local fp, zn, fullName
	for i = 1, numNodes do
		if TaxiNodeGetType(i) == "REACHABLE" then
			fullName = TaxiNodeName(i):gsub(", ", ",")
			fp, zn = strsplit(",", fullName)
			fp = fp or ""
			zn = zn or ""
			
			tinsert(flightPoints, {
				["fpIdx"] = i,
				["zone"] = zn,
				["name"] = fp,
				["sortKey"] = zn..", "..fp,
				["cost"] = TaxiNodeCost(i),
			})
		end
	end
	table.sort(flightPoints, function(a, b) return a["sortKey"]<b["sortKey"] end)
end

--------------------------------------------------------
function addon.GetFilteredResults()
--------------------------------------------------------
	if not frame.filterText then
		return flightPoints
	end

	local filterText = strlower(frame.filterText:GetText())
	local filteredResults = {}

	for _, flightPoint in ipairs(flightPoints) do
		if strmatch(strlower(flightPoint["sortKey"]), filterText) then
			tinsert(filteredResults, flightPoint)
		end
	end

	return filteredResults
end

-------------------------------------
function addon.UpdateButtons()
-------------------------------------
	local scrollFrame = frame.scrollFrame
	local buttons = scrollFrame.buttons
	local numButtons = #buttons
	local button, flightPoint, index
	local filteredResults = addon.GetFilteredResults()
	local displayedHeight = 0
	local offset = HybridScrollFrame_GetOffset(scrollFrame)
	local zoneName

	for i = 1, numButtons do
		index = i + offset
		button = buttons[i]
		flightPoint = filteredResults[index]
		if flightPoint then
			zoneName = ""
			if flightPoint["zone"] ~= "" then
				zoneName = "- "..flightPoint["zone"]
			end

			MoneyFrame_Update(_G[button:GetName().."MoneyFrame"], flightPoint["cost"])

			button.fpName:SetText(flightPoint["name"])
			button.zoneName:SetText(zoneName)
			button.fpIdx = flightPoint.fpIdx
			button:Show()
		else
			button:Hide()
		end
	end
	local buttonHeight = buttons[1]:GetHeight()
	local totalHeight = #filteredResults * buttonHeight
	local displayedHeight = numButtons * buttonHeight

	HybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight)
end

function addon.GetGlow()
	local glow = addon.glow

	if not glow then
		glow = CreateFrame("Frame", nil, taxiFrame)
		glow:SetSize(48,48)
		glow:SetFrameLevel(5)

		glow.tex = glow:CreateTexture(nil, "ARTWORK")
		glow.tex:SetTexture("Interface/SPELLBOOK/UI-GlyphFrame-Glow")
		glow.tex:SetBlendMode("ADD")
		glow.tex:SetSize(48,48)
		glow.tex:SetAlpha(0.5)
		glow.tex:SetAllPoints()

		addon.glow = glow

		local flasher = glow.tex:CreateAnimationGroup()
		local fade1 = flasher:CreateAnimation("Alpha")
		fade1:SetDuration(0.5)
		fade1:SetToAlpha(0.7)
		fade1:SetOrder(1)

		local fade2 = flasher:CreateAnimation("Alpha")
		fade2:SetDuration(0.5)
		fade2:SetToAlpha(0)
		fade2:SetOrder(2) 

		glow.tex.flasher = flasher
	end

	return glow
end

function addon:HighlightFlightMapDestination(button)
	local destinationNodeId = button.fpIdx
	local glow = addon.GetGlow()
	glow.tex.flasher:Stop()
	
	local mapicon,pin
	for pin,_ in pairs(taxiFrame.pinPools.FlightMap_FlightPointPinTemplate.activeObjects) do
		local taxiNodeId = pin.taxiNodeData and pin.taxiNodeData.slotIndex
		if taxiNodeId == destinationNodeId then 
			mapicon = pin

			glow:SetPoint("CENTER", mapicon, "CENTER", 6, -5)
			glow.tex.flasher:Play()
			glow:Show()
			return
		end
	end
end

function addon.UnhighlightFlightMapDestination()
	if not addon.glow then return end
	addon.glow:Hide()
end