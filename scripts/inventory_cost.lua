--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

local aDenominations = {}

-- On intialization, script adds handlers to calculate inventory cost and checks the ruleset to add the correct 
-- denominations into the aDenominations table, since not all rulesets include currency names.

function onInit()
	if User.isHost() then
		DB.addHandler(DB.getPath('charsheet.*.inventorylist.*.cost'), 'onUpdate', calculateInvCost)
		DB.addHandler(DB.getPath('charsheet.*.inventorylist.*.count'), 'onUpdate', calculateInvCost)
		DB.addHandler(DB.getPath('charsheet.*.inventorylist.*.isidentified'), 'onUpdate', calculateInvCost)
		DB.addHandler(DB.getPath('charsheet.*.inventorylist'), 'onChildDeleted', calculateInvCost)
	end
	
	local sRuleset = User.getRulesetName()
	-- Set multiplers for different currency denominations.
	if sRuleset == "3.5E" or sRuleset == "PFRPG" or sRuleset == "PFRPG2" then
		aDenominations['pp'] = {['nValue'] = 10}
		aDenominations['gp'] = {['nValue'] = 1}
		aDenominations['sp'] = {['nValue'] = .1}
		aDenominations['cp'] = {['nValue'] = .01}
	elseif sRuleset == "4E" then
		aDenominations['ad'] = {['nValue'] = 10000}
		aDenominations['pp'] = {['nValue'] = 100}
		aDenominations['gp'] = {['nValue'] = 1}
		aDenominations['sp'] = {['nValue'] = .1}
		aDenominations['cp'] = {['nValue'] = .01}
	end
end

---  This function posts a message in the chat window if the item cost contains a hyphen or a slash.
local nAnnounce = 1
local function announceImproperCost(nodeChar, sItemName, bLowestUsed)
	if nAnnounce == 1 and OptionsManager.isOption('WARN_COST', 'on') then
		local sHoldingPc = DB.getValue(nodeChar, 'name', Interface.getString("char_name_unknown"))
		if bLowestUsed then
			ChatManager.SystemMessage(string.format(Interface.getString("item_cost_error_range"), sHoldingPc, sItemName))
		else
			ChatManager.SystemMessage(string.format(Interface.getString("item_cost_error_wrong"), sHoldingPc, sItemName))
		end
	end
end

---	Convert everything to main currency and drop any non-numerical characters. ('300gp' -> 300) ('30pp' -> 300) ('3sp' -> .3).
local function processItemCost(nodeChar, sItemCost, sItemName)
	if not string.match(sItemCost, '%d+') then
		return 0
	elseif string.match(sItemCost, '(%d%s%a+)%/') or string.match(sItemCost, '(%d%s%a+)%-') then
		announceImproperCost(nodeChar, sItemName, true)
		sItemCost = string.match(sItemCost, '%d+%s%a+') -- thanks to FeatherRin on FG Forums for the inspiration
	elseif string.match(sItemCost, '(%d%a+)%/') or string.match(sItemCost, '(%d%s%a+)%-') then
		announceImproperCost(nodeChar, sItemName, true)
		sItemCost = string.match(sItemCost, '%d+%a+') -- thanks to FeatherRin on FG Forums for the inspiration
	elseif string.match(sItemCost, '%-+') then
		announceImproperCost(nodeChar, sItemName)
		return 0
	elseif string.match(sItemCost, '%/+') then
		announceImproperCost(nodeChar, sItemName)
		return 0
	end

	local sTrimmedItemCost = sItemCost:gsub('[^0-9.-]', '')
	if sTrimmedItemCost then
		nTrimmedItemCost = tonumber(sTrimmedItemCost)
		for sDenomination,tDenominationData in pairs(aDenominations) do
			if string.match(sItemCost, sDenomination) then
				return nTrimmedItemCost * tDenominationData['nValue']
			end
		end
	end

	return 0
end

---	This function calculates the total value of every identified item in the player's inventory.
--	It then writes it to the DB for use during net worth calculation.
function calculateInvCost(node)
	local nodeChar = node.getChild('....')
	if node.getParent().getName() == 'charsheet' then nodeChar = node
	elseif node.getName() == 'inventorylist' then nodeChar = node.getParent() end
	local nTotalInvVal = 0
	for _,v in pairs(DB.getChildren(nodeChar, 'inventorylist')) do
		local nItemIDed = DB.getValue(v, 'isidentified', 1)
		local sItemName = DB.getValue(v, 'name', '')
		local sItemCost = DB.getValue(v, 'cost')
		local nItemCount = DB.getValue(v, 'count', 1)

		if sItemCost and nItemIDed ~= 0 then
			local nItemCost = processItemCost(nodeChar, string.lower(sItemCost), string.lower(sItemName))
			nTotalInvVal = nTotalInvVal + (nItemCount * nItemCost)
		end
	end
	
	if OptionsManager.isOption('WARN_COST', 'off') then nAnnounce = 0 end	

	DB.setValue(nodeChar, 'coins.invtotalval', 'number', nTotalInvVal)
end