local addonName = ...

local addon = TaxiListFrame
_G[addonName] = addon
local flightPoints = {}
local taxiFrame
local isInitialized = false
local isWowClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

-------------------------------
function addon:TAXIMAP_OPENED()
-------------------------------
	if not isInitialized then
		self:InitializeFrame()
	end

	self:UpdateFlightPoints()
	self.filterText:SetText("")
	self:UpdateButtons() 
	self:Show()
end

--------------------------------------
function addon:InitializeScrollFrame()
--------------------------------------
	if isWowClassic then
		self:SetPoint("TOPLEFT", taxiFrame, "TOPRIGHT", -34, -14)
		self:SetPoint("BOTTOMLEFT", taxiFrame, "BOTTOMRIGHT", -34, 75)
	end

	local scrollFrame = self.scrollFrame
	scrollFrame.update = function () self:UpdateButtons() end

	HybridScrollFrame_CreateButtons(scrollFrame, "TaxiListButtonTemplate", 0, 0)
	HybridScrollFrame_SetDoNotHideScrollBar(scrollFrame, true)
end

--------------------------------
function addon:InitializeFrame()
--------------------------------
	isInitialized = true

	taxiFrame = FlightMapFrame or TaxiFrame

	self:SetPoint("TOPLEFT", taxiFrame, "TOPRIGHT")
	self:SetHeight(taxiFrame:GetHeight())
	self:SetWidth(262)
	self:SetParent(taxiFrame)

	self.CloseButton:SetScript("OnClick", function(self)
		CloseTaxiMap()
		self:Hide()
	end)

	self.filterText:SetScript("OnTextChanged", function() self:UpdateButtons() end)

	self:InitializeScrollFrame()
end

-----------------------------------
function addon:UpdateFlightPoints()
-----------------------------------
	table.wipe(flightPoints)
	local fp, zn, fullName

	for i = 1, NumTaxiNodes() do
		if TaxiNodeGetType(i) == "REACHABLE" then
			fullName = TaxiNodeName(i):gsub(", ", ",")
			fp, zn = strsplit(",", fullName)
			fp = fp or ""
			zn = zn or ""
			
			GetNumRoutes(i) -- Dummy call, without which the cost is unavailable.

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

-----------------------------------
function addon:GetFilteredResults()
-----------------------------------
	if not self.filterText then
		return flightPoints
	end

	local filterText = strlower(self.filterText:GetText())
	local filteredResults = {}

	for _, flightPoint in ipairs(flightPoints) do
		if strmatch(strlower(flightPoint["sortKey"]), filterText) then
			tinsert(filteredResults, flightPoint)
		end
	end

	return filteredResults
end

------------------------------
function addon:UpdateButtons()
------------------------------
	local scrollFrame = self.scrollFrame
	local buttons = scrollFrame.buttons
	local numButtons = #buttons
	local button, flightPoint, index
	local filteredResults = self:GetFilteredResults()
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

------------------------
function addon:GetGlow()
------------------------
	local glow = self.glow

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

		self.glow = glow

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

----------------------------------------------------
function addon:HighlightFlightMapDestination(button)
----------------------------------------------------
	local glow = self:GetGlow()
	glow.tex.flasher:Stop()
	
	local pinToHighlight = self:GetPinToHighlight(button.fpIdx)

	glow:SetPoint("CENTER", pinToHighlight, "CENTER", 6, -5)
	glow.tex.flasher:Play()
	glow:Show()
end

------------------------------------------------------
function addon:GetPinToHighlight(destinationNodeIndex)
------------------------------------------------------
	if FlightMapFrame then -- For Retail
		for pin, _ in pairs(taxiFrame.pinPools.FlightMap_FlightPointPinTemplate.activeObjects) do
			local taxiNodeSlotIndex = pin.taxiNodeData and pin.taxiNodeData.slotIndex
			if taxiNodeSlotIndex == destinationNodeIndex then 
				return pin
			end
		end

		error("Unknown destination node index: "..destinationNodeIndex)
	end

	return _G["TaxiButton"..destinationNodeIndex] -- For Classic.
	-- For him. For her. Obsession. Calvin Klein!
end

----------------------------------
function addon:TakeTaxiNode(index)
----------------------------------
	TakeTaxiNode(index)
end

--------------------------------------------------
function addon:HighLightTaxiMapDestination(button)
--------------------------------------------------
	local destinationNodeId = button.fpIdx
	local glow = self:GetGlow()
	glow.tex.flasher:Stop()

	for i=1,NumTaxiNodes() do
		if TaxiNodeGetType(i) == "REACHABLE" and i == destinationNodeId then
			local mapIcon = _G["TaxiButton"..i]
			glow:SetPoint("CENTER", mapIcon, "CENTER", 6, -5)
			glow.tex.flasher:Play()
			glow:Show()
			return
		end
	end
end

------------------------------------------------
function addon:UnhighlightFlightMapDestination()
------------------------------------------------
	if not self.glow then return end
	self.glow:Hide()
end

addon:SetScript("OnEvent", function(dum, dee, ...) dum[dee](dum, ...) end)
addon:RegisterEvent("TAXIMAP_OPENED")