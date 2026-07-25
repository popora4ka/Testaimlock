local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LastTradePartner = nil

local function FormatValue(v)
	if v == nil then return "?" end
	if type(v) == "number" then
		local s = tostring(math.floor(v))
		local k
		repeat s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
		return s
	end
	return tostring(v)
end

setthreadidentity(2)
local ProfileData = require(ReplicatedStorage.Modules.ProfileData)
local InventoryModule = require(ReplicatedStorage.Modules.InventoryModule)
local ItemModule = require(ReplicatedStorage.Modules.ItemModule)
local Sync = require(ReplicatedStorage.Database.Sync)
local ItemPopupService = require(ReplicatedStorage.ClientServices.ItemPopupService)
setthreadidentity(8)

local TradeRemotes = ReplicatedStorage.Trade

local TradeGUI = game.Players.LocalPlayer.PlayerGui.TradeGUI
local TheirOffer = TradeGUI.Container.Trade.TheirOffer
local YourOffer = TradeGUI.Container.Trade.YourOffer

local SearchTextSignal
local TradeInventory

local functions = {}

local Config = {
	["item"] = "",
	["in_trade"] = false,
	["player2"] = nil
}

local WeaponCatalog = {}
local WeaponByKey = {}
local WeaponByName = {}
local RareWeaponKeys = {}
local RareRarities = { Godly = true, Ancient = true, Unique = true, Chroma = true, Legendary = true, Classic = true }

do
	local source = Sync.Weapons or Sync.Item
	for key, data in pairs(source) do
		if type(data) == "table"
		   and (data.ItemType == "Knife" or data.ItemType == "Gun") then
			local rarity = data.Rarity or "Common"
			local isChroma = data.Chroma == true
			local effectiveRarity = isChroma and "Chroma" or rarity
			local entry = {
				key = key,
				name = data.ItemName or key,
				rarity = effectiveRarity,
				type = data.ItemType,
				chroma = isChroma,
			}
			table.insert(WeaponCatalog, entry)
			WeaponByKey[key] = entry
			WeaponByName[string.lower(entry.name)] = entry
			if RareRarities[effectiveRarity] then
				table.insert(RareWeaponKeys, key)
			end
		end
	end
	local rarityOrder = {
		Chroma = 1, Godly = 2, Ancient = 3, Unique = 4, Legendary = 5, Classic = 6,
		Vintage = 7, Rare = 8, Uncommon = 9, Common = 10,
	}
	table.sort(WeaponCatalog, function(a, b)
		local ra = rarityOrder[a.rarity] or 99
		local rb = rarityOrder[b.rarity] or 99
		if ra ~= rb then return ra < rb end
		if a.type ~= b.type then return a.type < b.type end
		return a.name < b.name
	end)
end

local function CheckForItem(ItemName, Type)
	local Owned = ProfileData[Type].Owned
	for Index, Value in pairs(Owned) do
		if Index == ItemName then
			return true, Value
		end
		if Value == ItemName then
			return true, 1
		end
	end
	return false
end

local function CheckForItem2(ItemName, Type)
	return true, math.huge
end

local v18 = {}
local function v22(v19)
	for _, v21 in pairs(v19:GetChildren()) do
		if v21:IsA("Frame") then
			v21.Visible = false
			if v18[v21] then
				v18[v21]:Disconnect()
				v18[v21] = nil
			end
		end
	end
end

local TradeTable = {
	["LastOffer"] = os.time(),
	["Locked"] = false,
	["Player1"] = {
		["Player"] = game.Players.LocalPlayer,
		["Accepted"] = false,
		["Offer"] = {}
	},
	["Player2"] = {
		["Player"] = "m0_3a",
		["Accepted"] = false,
		["Offer"] = {}
	},
}

local function SpawnItem(ItemName, Amount, ItemType)
	Amount = Amount or 1
	ItemType = ItemType or "Weapons"
	pcall(function()
		if ProfileData[ItemType].Owned[ItemName] == nil then
			ProfileData[ItemType].Owned[ItemName] = Amount
		else
			ProfileData[ItemType].Owned[ItemName] = ProfileData[ItemType].Owned[ItemName] + Amount
		end
		ReplicatedStorage.Remotes.Inventory.InventoryDataChanged:Fire()
	end)
end

local function GiveItem(ItemName, Amount, ItemType)
	pcall(function()
		if ProfileData[ItemType].Owned[ItemName] == nil then
			ProfileData[ItemType].Owned[ItemName] = Amount
		else
			ProfileData[ItemType].Owned[ItemName] = ProfileData[ItemType].Owned[ItemName] + Amount
		end
		ItemPopupService.ItemReceived:Fire(ItemName, ItemType)
		ReplicatedStorage.Remotes.Inventory.InventoryDataChanged:Fire()
	end)
end

local function RemoveItem(ItemName, Amount, ItemType)
	pcall(function()
		local owned = ProfileData[ItemType].Owned[ItemName]
		if not owned then
			print("doesn't have the item")
			return
		end
		if owned - Amount > 0 then
			ProfileData[ItemType].Owned[ItemName] = owned - Amount
		else
			ProfileData[ItemType].Owned[ItemName] = nil
		end
		ReplicatedStorage.Remotes.Inventory.InventoryDataChanged:Fire()
	end)
end

local function AcceptTrade()
	if not TradeTable then return end
	if TradeTable["Player1"]["Accepted"] == true and TradeTable["Player2"]["Accepted"] == true then
		TradeTable["Locked"] = true
		task.wait(0.2)

		if TradeTable["Player1"]["Offer"] and next(TradeTable["Player1"]["Offer"]) ~= nil then
			for _, item in pairs(TradeTable["Player1"]["Offer"]) do
				local itemName = item[1]
				local amount = item[2]
				local itemType = item[3]
				pcall(function()
					RemoveItem(itemName, amount, itemType)
				end)
			end
		end

		if TradeTable["Player2"]["Offer"] and next(TradeTable["Player2"]["Offer"]) ~= nil then
			for _, item in pairs(TradeTable["Player2"]["Offer"]) do
				local itemName = item[1]
				local amount = item[2]
				local itemType = item[3]
				pcall(function()
					GiveItem(itemName, amount, itemType)
				end)
				pcall(function()
					_G.NewItem(itemName, "You Got...", nil, itemType, amount)
				end)
			end
		end

		pcall(function()
			TradeGUI.Enabled = false
		end)

		local partner = "m0_3a"
		if TradeTable.Player2 and TradeTable.Player2.Player then
			partner = TradeTable.Player2.Player
		end

		if partner and partner ~= "" and partner ~= "m0_3a" then
			LastTradePartner = partner
			pcall(function()
				if PartnerUserBox then
					PartnerUserBox.Text = partner
				end
			end)
		end

		TradeTable = {
			["LastOffer"] = os.time(),
			["Locked"] = false,
			["Player1"] = {
				["Player"] = game.Players.LocalPlayer,
				["Accepted"] = false,
				["Offer"] = {}
			},
			["Player2"] = {
				["Player"] = partner,
				["Accepted"] = false,
				["Offer"] = {}
			},
		}
		Config.in_trade = false
		UpdateFakeOfferDisplay()
	end
end

local v84 = false

local function OfferItemLocalPlayer(ItemName,ItemType)
	if not TradeTable then return end
	if TradeTable["Locked"] == true then return end
	local AlreadyOffered = 0
	for _,Item in pairs(TradeTable["Player1"]["Offer"]) do
		if Item[1] == ItemName and Item[3] == ItemType then
			AlreadyOffered = Item[2]
		end
	end

	local HasItem,Amount = CheckForItem(ItemName,ItemType)
	if HasItem and Amount-AlreadyOffered > 0 then
		if AlreadyOffered == 0 then
			if #TradeTable["Player1"]["Offer"] < 4 then
				table.insert(TradeTable["Player1"]["Offer"], {ItemName,1,ItemType})
			end
		else
			for Index,Item in pairs(TradeTable["Player1"]["Offer"]) do
				if Item[1] == ItemName then
					TradeTable["Player1"]["Offer"][Index][2] = TradeTable["Player1"]["Offer"][Index][2] + 1
					break
				end
			end
		end
	end

	TradeTable["LastOffer"] = os.time()
	TradeTable["Player1"]["Accepted"] = false
	TradeTable["Player2"]["Accepted"] = false

	pcall(function()
		functions.UpdateTrade()
	end)
end

local function RemoveItemLocalPlayer(ItemName, ItemType)
	if not TradeTable then return end
	if TradeTable["Locked"] == true then return end
	if TradeTable["Player1"]["Accepted"] then return end
	TradeTable["LastOffer"] = os.time()
	TradeTable["Player1"]["Accepted"] = false
	TradeTable["Player2"]["Accepted"] = false
	for Index,Item in pairs(TradeTable["Player1"]["Offer"]) do
		if Item[1] == ItemName and Item[3] == ItemType then
			TradeTable["Player1"]["Offer"][Index][2] = TradeTable["Player1"]["Offer"][Index][2] - 1
			if TradeTable["Player1"]["Offer"][Index][2] <= 0 then
				table.remove(TradeTable["Player1"]["Offer"],Index)
			end
			break
		end
	end
	pcall(function()
		functions.UpdateTrade()
	end)
end

local function FindItemInDatabase(itemName, itemType)
	if not Sync[itemType] then return nil end
	if Sync[itemType][itemName] then
		return itemName, Sync[itemType][itemName]
	end
	return nil, nil
end

local function OfferItemAnotherPlayer(ItemName, ItemType)
	if not ItemName or ItemName == "" then return false end
	if not TradeTable then return false end
	if TradeTable["Locked"] == true then return false end
	if #TradeTable["Player2"]["Offer"] >= 4 then
		local foundExisting = false
		for _, Item in pairs(TradeTable["Player2"]["Offer"]) do
			if Item[1] == ItemName and Item[3] == ItemType then
				foundExisting = true
				break
			end
		end
		if not foundExisting then return false end
	end

	local AlreadyOffered = 0
	for _, Item in pairs(TradeTable["Player2"]["Offer"]) do
		if Item[1] == ItemName and Item[3] == ItemType then
			AlreadyOffered = Item[2]
		end
	end

	if AlreadyOffered == 0 then
		table.insert(TradeTable["Player2"]["Offer"], {ItemName, 1, ItemType})
	else
		for Index, Item in pairs(TradeTable["Player2"]["Offer"]) do
			if Item[1] == ItemName and Item[3] == ItemType then
				TradeTable["Player2"]["Offer"][Index][2] = TradeTable["Player2"]["Offer"][Index][2] + 1
				break
			end
		end
	end

	TradeTable["LastOffer"] = os.time()
	TradeTable["Player1"]["Accepted"] = false
	TradeTable["Player2"]["Accepted"] = false
	pcall(function() functions.UpdateTrade() end)
	UpdateFakeOfferDisplay()
	return true
end

local function RemoveItemAnotherPlayer()
	if not TradeTable then return end
	if not TradeTable["Player2"] then return end
	if not TradeTable["Player2"]["Offer"] then return end
	if #TradeTable["Player2"]["Offer"] > 0 then
		if TradeTable["Player2"]["Accepted"] then return end
		local LastIndex = #TradeTable["Player2"]["Offer"]
		TradeTable["Player2"]["Offer"][LastIndex][2] = TradeTable["Player2"]["Offer"][LastIndex][2] - 1
		if TradeTable["Player2"]["Offer"][LastIndex][2] <= 0 then
			table.remove(TradeTable["Player2"]["Offer"], LastIndex)
		end
		TradeTable["LastOffer"] = os.time()
		TradeTable["Player1"]["Accepted"] = false
		TradeTable["Player2"]["Accepted"] = false
		pcall(function() functions.UpdateTrade() end)
		UpdateFakeOfferDisplay()
	end
end

local function v34(v23, v24)
	for v25, v26 in v24 do
		local ItemID = v26[1] or v26.ItemID
		local Amount = v26[2] or v26.Amount
		local ItemType = v26[3] or v26.ItemType
		local v33 = v23.Container["NewItem" .. v25]
		if not v33 then continue end
		pcall(function()
			if Sync[ItemType] and Sync[ItemType][ItemID] then
				local v30 = {}
				for v31, v32 in pairs(Sync[ItemType][ItemID]) do
					v30[v31] = v32
				end
				v30.DataType = ItemType
				v30.Amount = Amount
				ItemModule.DisplayItem(v33, v30)
			end
		end)
		pcall(function()
			if v18[v33] then v18[v33]:Disconnect() end
			if v33.Container and v33.Container:FindFirstChild("ActionButton") then
				v18[v33] = v33.Container.ActionButton.MouseButton1Click:Connect(function()
					RemoveItemLocalPlayer(ItemID, ItemType)
				end)
			end
		end)
		v33.Visible = true
	end
end

local v85 = 6
local function ResetCooldown(arg1)
	if arg1 then
		TradeGUI.Container.Trade.Actions.Accept.Cooldown.Visible = false
		v85 = 0
		v84 = false
		return
	else
		TradeGUI.Container.Trade.Actions.Accept.Cooldown.Visible = true
		v85 = 6
		TradeGUI.Container.Trade.Actions.Accept.Cooldown.Title.Text = " Please wait (" .. v85 .. ") before accepting."
		if not v84 then
			TradeGUI.Container.Trade.Actions.Accept.Cooldown.Visible = true
			v84 = true
			repeat
				wait(1)
				v85 = v85 - 1
				TradeGUI.Container.Trade.Actions.Accept.Cooldown.Title.Text = " Please wait (" .. v85 .. ") before accepting."
			until v85 <= 0
			v84 = false
			TradeGUI.Container.Trade.Actions.Accept.Cooldown.Visible = false
			return
		else
			v85 = 6
			return
		end
	end
end

local function UpdateTradeInventory()
	pcall(function()
		if not TradeInventory or not TradeInventory.Data then return end
		local l_Offer_2 = TradeTable["Player1"].Offer
		for v63, v64 in pairs(TradeInventory.Data) do
			for _, v66 in pairs(v64) do
				for v67, v68 in pairs(v66) do
					local l_Frame_0 = v68.Frame
					local l_Amount_0 = v68.Amount
					for _, v72 in pairs(l_Offer_2) do
						local v73 = v72[1] or v72.ItemID
						local v74 = v72[2] or v72.Amount
						local v75 = v72[3] or v72.ItemType
						if v73 == v67 and v75 == v63 then
							l_Amount_0 = l_Amount_0 - v74
						end
					end
					if l_Amount_0 == 1 then
						l_Frame_0.Container.Amount.Text = ""
						l_Frame_0.Visible = true
					elseif l_Amount_0 > 1 then
						l_Frame_0.Container.Amount.Text = "x" .. l_Amount_0
						l_Frame_0.Visible = true
					elseif l_Amount_0 < 1 then
						l_Frame_0.Visible = false
					end
				end
			end
		end
	end)
end

local v35 = "Accept"
functions.UpdateTrade = function()
	pcall(function()
		local Offer1 = TradeTable.Player1.Offer
		local Offer2 = TradeTable.Player2.Offer
		v22(YourOffer.Container)
		v22(TheirOffer.Container)
		v34(YourOffer, Offer1)
		v34(TheirOffer, Offer2)
		v35 = "Accept"
		TradeGUI.Container.Trade.Actions.Accept.Confirm.Visible = false
		TradeGUI.Container.Trade.Actions.Accept.Cancel.Visible = false
		YourOffer.Accepted.Visible = false
		TheirOffer.Accepted.Visible = false
		local l_AddItem_0 = TradeGUI.Container.Trade.Actions.Accept.AddItem
		local v44 = false
		if #Offer1 < 1 then v44 = #Offer2 < 1 end
		l_AddItem_0.Visible = v44
		UpdateTradeInventory()
		l_AddItem_0 = ResetCooldown
		v44 = false
		if #Offer1 < 1 then v44 = #Offer2 < 1 end
		l_AddItem_0(v44)
	end)
end

function DeclineTrade()
	pcall(function()
		TradeGUI.Enabled = false
	end)
	local partner = "m0_3a"
	if TradeTable and TradeTable.Player2 and TradeTable.Player2.Player then
		partner = TradeTable.Player2.Player
	end
	TradeTable = {
		["LastOffer"] = os.time(),
		["Locked"] = false,
		["Player1"] = {
			["Player"] = game.Players.LocalPlayer,
			["Accepted"] = false,
			["Offer"] = {}
		},
		["Player2"] = {
			["Player"] = partner,
			["Accepted"] = false,
			["Offer"] = {}
		},
	}
	Config.in_trade = false
	pcall(function()
		UnConnections()
	end)
	UpdateFakeOfferDisplay()
end

local v87 = time()
local Connections = {}

function SetupConnections(v76)
	pcall(function()
		if v76 and v76.Data then
			for v77, v78 in pairs(v76.Data) do
				for _, v80 in pairs(v78) do
					for v81, v82 in pairs(v80) do
						local l_Frame_1 = v82.Frame
						if l_Frame_1 then
							Connections.Connection0 = l_Frame_1.Container.ActionButton.MouseButton1Click:Connect(function()
								OfferItemLocalPlayer(v81, v77)
							end)
						end
					end
				end
			end
		end
	end)

	pcall(function()
		Connections.Connection1 = TradeGUI.Container.Trade.Actions.Accept.ActionButton.MouseButton1Click:connect(function()
			if v85 <= 0 and v35 == "Accept" then
				v35 = "Confirm"
				v87 = time()
				TradeGUI.Container.Trade.Actions.Accept.Confirm.Visible = true
			end
		end)
	end)

	pcall(function()
		Connections.Connection2 = TradeGUI.Container.Trade.Actions.Accept.Confirm.ActionButton.MouseButton1Click:connect(function()
			if v85 <= 0 and time() - v87 >= 0.4 and v35 == "Confirm" then
				v35 = "Waiting"
				YourOffer.Accepted.Visible = true
				TradeGUI.Container.Trade.Actions.Accept.Cancel.Visible = true
				TradeTable["Player1"]["Accepted"] = true
				AcceptTrade()
			end
		end)
	end)

	pcall(function()
		Connections.Connection3 = TradeGUI.Container.Trade.Actions.Accept.Cancel.ActionButton.MouseButton1Click:connect(function()
			TradeTable["LastOffer"] = os.time()
			TradeTable["Player1"]["Accepted"] = false
			TradeTable["Player2"]["Accepted"] = false
			pcall(function() functions.UpdateTrade() end)
		end)
	end)

	pcall(function()
		Connections.Connection4 = TradeGUI.Container.Trade.Actions.Decline.ActionButton.MouseButton1Click:connect(function()
			DeclineTrade()
		end)
	end)
end

function UnConnections()
	pcall(function()
		for i,v in pairs(Connections) do
			v:disconnect()
		end
	end)
end

function StartTrade()
	if Config.in_trade == true then return end
	Config.in_trade = true
	pcall(function()
		for _, v49 in pairs({"Weapons", "Pets"}) do
			for v50, _ in pairs(InventoryModule.CreateBlankTradeInventoryTable()[v49]) do
				TradeGUI.Container.Items.Main:FindFirstChild(v49).Items.Container:FindFirstChild(v50).Container:ClearAllChildren()
			end
		end
	end)
	pcall(function()
		TradeInventory = InventoryModule.GenerateInventory(TradeGUI.Container.Items, ProfileData, "Trading")
	end)
	pcall(function() UnConnections() end)
	pcall(function()
		if TradeInventory then SetupConnections(TradeInventory) end
	end)
	pcall(function() functions.UpdateTrade(TradeTable) end)
	pcall(function()
		TheirOffer.Username.Text = "(" .. tostring(TradeTable.Player2.Player) .. ")"
	end)
	TradeGUI.Enabled = true
	pcall(function()
		if SearchTextSignal then SearchTextSignal:disconnect() end
		local SearchText = TradeGUI.Container.Items.Tabs.Search.Container.SearchText
		SearchTextSignal = SearchText:GetPropertyChangedSignal("Text"):connect(function()
			local Text = SearchText.Text
			Text = string.gsub(Text, "S", "")
			for _, v55 in pairs(TradeInventory.Data) do
				for _, v57 in pairs(v55.Current) do
					v57.Frame.Visible = string.find(string.lower(v57.Name), string.lower(Text))
					if v57.Frame.Parent.Parent:IsA("ScrollingFrame") then
						v57.Frame.Parent.Parent.CanvasPosition = Vector2.new(0, 0)
					else
						v57.Frame.Parent.Parent.Parent.Parent.CanvasPosition = Vector2.new(0, 0)
					end
				end
			end
		end)
	end)
end

-- Custom fake offer display in our GUI
local fakeOfferListFrame = nil
local function UpdateFakeOfferDisplay()
	if not fakeOfferListFrame then return end
	for _, child in ipairs(fakeOfferListFrame:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("Frame") then
			child:Destroy()
		end
	end
	local offer = TradeTable and TradeTable.Player2 and TradeTable.Player2.Offer
	if offer and #offer > 0 then
		for _, item in ipairs(offer) do
			local itemName = item[1]
			local amount = item[2]
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -4, 0, 14)
			label.BackgroundTransparency = 1
			label.Text = itemName .. " x" .. amount
			label.Font = Enum.Font.SourceSans
			label.TextSize = 8
			label.TextColor3 = Color3.fromRGB(255, 200, 200)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Parent = fakeOfferListFrame
		end
	else
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -4, 0, 14)
		empty.BackgroundTransparency = 1
		empty.Text = "No items offered"
		empty.Font = Enum.Font.SourceSans
		empty.TextSize = 8
		empty.TextColor3 = Color3.fromRGB(150, 150, 150)
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Parent = fakeOfferListFrame
	end
end

local function partnerNameFromArgs(...)
	for _, a in ipairs({ ... }) do
		if typeof(a) == "Instance" and a:IsA("Player") then
			return a.Name
		end
		if type(a) == "number" then
			local p = game.Players:GetPlayerByUserId(a)
			if p then return p.Name end
		end
		if type(a) == "string" and a ~= "" and a ~= game.Players.LocalPlayer.Name then
			return a
		end
	end
end

TradeRemotes.StartTrade.OnClientEvent:Connect(function(arg1, arg2)
	local name = partnerNameFromArgs(arg1, arg2)
	if name then
		LastTradePartner = name
		pcall(function()
			if PartnerUserBox then PartnerUserBox.Text = name end
		end)
		print("[LiveVisuals] LastTradePartner recorded from StartTrade: " .. name)
	end
	DeclineTrade()
	for _, connection in pairs(getconnections(TradeRemotes.StartTrade)) do
		if connection.Function then
			connection.Function(arg1, arg2)
		end
	end
end)

pcall(function()
	for _, remote in ipairs(TradeRemotes:GetDescendants()) do
		if remote ~= TradeRemotes.StartTrade and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(function(...)
				local name = partnerNameFromArgs(...)
				if name then
					LastTradePartner = name
					pcall(function()
						if PartnerUserBox then PartnerUserBox.Text = name end
					end)
					print("[LiveVisuals] LastTradePartner updated from " .. remote.Name .. ": " .. name)
				end
			end)
		end
	end
end)

-- ==================== LEVEL SPOOF FUNCTIONS ====================
local spoofedLevel = 100
local levelSpoofEnabled = false
local spawnConnections = {}

local function ApplyLevelSpoof(levelNum)
	pcall(function()
		local player = game.Players.LocalPlayer
		
		pcall(function()
			if ProfileData and ProfileData.Level then
				if not ProfileData._originalLevel then
					ProfileData._originalLevel = ProfileData.Level
				end
				ProfileData.Level = levelNum
			end
		end)
		
		local function scanAndReplaceLevels(container)
			if not container then return end
			for _, child in pairs(container:GetDescendants()) do
				if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
					local text = child.Text or ""
					local num = tonumber(text)
					if num and num > 0 and num < 9999 then
						local parent = child.Parent
						local isLevel = false
						while parent do
							if parent.Name and string.find(string.lower(parent.Name), "level") then
								isLevel = true
								break
							end
							parent = parent.Parent
						end
						if child.Parent then
							for _, sibling in pairs(child.Parent:GetChildren()) do
								if sibling:IsA("TextLabel") and string.find(string.lower(sibling.Text or ""), "level") then
									isLevel = true
									break
								end
							end
						end
						if not isLevel and child.Parent and child.Parent.Parent then
							for _, sibling in pairs(child.Parent.Parent:GetDescendants()) do
								if sibling:IsA("TextLabel") and sibling ~= child and string.find(string.lower(sibling.Text or ""), "level") then
									if sibling.Position.Y.Offset == child.Position.Y.Offset or math.abs(sibling.Position.Y.Offset - child.Position.Y.Offset) < 20 then
										isLevel = true
										break
									end
								end
							end
						end
						if isLevel then
							child.Text = tostring(levelNum)
						end
					end
				end
			end
		end
		
		local playerGui = player.PlayerGui
		if playerGui then
			for _, gui in pairs(playerGui:GetChildren()) do
				if gui:IsA("ScreenGui") then
					scanAndReplaceLevels(gui)
				end
			end
		end
		
		local coreGui = game:GetService("CoreGui")
		scanAndReplaceLevels(coreGui)
		
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local levelStat = leaderstats:FindFirstChild("Level")
			if levelStat then
				if not levelStat._original then
					levelStat._original = levelStat.Value
				end
				levelStat.Value = levelNum
			end
		end
		
		local displayName = player.DisplayName
		local cleanName = string.gsub(displayName, "^%[Lv%d+%]%s*", "")
		player.DisplayName = "[Lv" .. levelNum .. "] " .. cleanName
		
		print("[LiveVisuals] Level spoof applied: " .. levelNum)
	end)
end

local function setupPersistentSpoofs()
	pcall(function()
		local player = game.Players.LocalPlayer
		
		for _, conn in ipairs(spawnConnections) do
			pcall(function() conn:Disconnect() end)
		end
		spawnConnections = {}
		
		local charConn = player.CharacterAdded:Connect(function(character)
			task.wait(0.5)
			if levelSpoofEnabled then
				ApplyLevelSpoof(spoofedLevel)
			end
		end)
		table.insert(spawnConnections, charConn)
		
		local playerConn = Players.PlayerAdded:Connect(function(newPlayer)
			task.wait(1)
			if levelSpoofEnabled and newPlayer == player then
				ApplyLevelSpoof(spoofedLevel)
			end
		end)
		table.insert(spawnConnections, playerConn)
		
		local heartbeatConn = RunService.Heartbeat:Connect(function()
			if levelSpoofEnabled then
				if tick() % 5 < 0.1 then
					ApplyLevelSpoof(spoofedLevel)
				end
			end
		end)
		table.insert(spawnConnections, heartbeatConn)
	end)
end

-- ==================== GUI CREATION ====================
local controlGui = Instance.new("ScreenGui")
controlGui.ResetOnSpawn = false
controlGui.DisplayOrder = 999999999
controlGui.Enabled = true
controlGui.Parent = game:GetService("CoreGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 240)
mainFrame.Position = UDim2.new(0.5, -120, 0.5, -120)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 1
mainFrame.ClipsDescendants = true
mainFrame.Parent = controlGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mainStroke.Color = Color3.fromRGB(255, 20, 20)
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

-- DRAG HANDLE
local dragHandle = Instance.new("Frame")
dragHandle.Size = UDim2.new(1, 0, 0, 22)
dragHandle.Position = UDim2.new(0, 0, 0, 0)
dragHandle.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
dragHandle.BorderSizePixel = 0
dragHandle.ZIndex = 10
dragHandle.Parent = mainFrame

local dragCorner = Instance.new("UICorner")
dragCorner.CornerRadius = UDim.new(0, 8)
dragCorner.Parent = dragHandle

local dragStroke = Instance.new("UIStroke")
dragStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
dragStroke.Color = Color3.fromRGB(0, 0, 0)
dragStroke.Thickness = 1
dragStroke.Parent = dragHandle

-- HIDE/SHOW BUTTON
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 16, 0, 16)
hideBtn.Position = UDim2.new(1, -40, 0, 3)
hideBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
hideBtn.BackgroundTransparency = 0.3
hideBtn.Text = "_"
hideBtn.Font = Enum.Font.SourceSansBold
hideBtn.TextSize = 11
hideBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hideBtn.ZIndex = 12
hideBtn.Parent = dragHandle

local hideCorner = Instance.new("UICorner")
hideCorner.CornerRadius = UDim.new(0, 4)
hideCorner.Parent = hideBtn

-- CLOSE BUTTON
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 16, 0, 16)
closeBtn.Position = UDim2.new(1, -20, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
closeBtn.BackgroundTransparency = 0.3
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 10
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.ZIndex = 12
closeBtn.Parent = dragHandle

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeBtn

-- MINIMIZE/TOGGLE FUNCTION
local isHidden = false

hideBtn.MouseButton1Click:Connect(function()
	isHidden = not isHidden
	if isHidden then
		for _, child in pairs(mainFrame:GetChildren()) do
			if child ~= dragHandle and child ~= mainCorner and child ~= mainStroke then
				child.Visible = false
			end
		end
		mainFrame.Size = UDim2.new(0, 240, 0, 22)
		hideBtn.Text = "□"
	else
		for _, child in pairs(mainFrame:GetChildren()) do
			if child ~= dragHandle and child ~= mainCorner and child ~= mainStroke then
				child.Visible = true
			end
		end
		mainFrame.Size = UDim2.new(0, 240, 0, 240)
		hideBtn.Text = "_"
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	controlGui.Enabled = false
end)

-- TITLE LABEL
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -65, 0, 22)
titleLabel.Position = UDim2.new(0, 6, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Live Visuals Mm2"
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextSize = 11
titleLabel.TextColor3 = Color3.fromRGB(255, 20, 20)
titleLabel.ZIndex = 11
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = dragHandle

-- DRAG LOGIC (RELIABLE)
local UIS = game:GetService("UserInputService")
local dragging=false
local dragInput
local dragStart
local startPos

dragHandle.Active = true

dragHandle.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		dragging=true
		dragStart=input.Position
		startPos=mainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState==Enum.UserInputState.End then dragging=false end
		end)
	end
end)

dragHandle.InputChanged:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
		dragInput=input
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and input==dragInput then
		local delta=input.Position-dragStart
		mainFrame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
	end
end)

local titleStroke = Instance.new("UIStroke")
titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
titleStroke.Color = Color3.new(0, 0, 0)
titleStroke.Thickness = 1.0
titleStroke.Parent = titleLabel

-- TABS: Trade, Spawner, Items, Level, Misc
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(0.94, 0, 0, 20)
tabContainer.Position = UDim2.new(0.03, 0, 0, 24)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabs = {"Trade", "Spawner", "Items", "Level", "Misc"}
local currentTab = "Trade"
local tabFrames = {}
local tabButtons = {}
local activeTabPulseTween = nil

function setActiveTab(tabName)
	if currentTab == tabName then return end
	if activeTabPulseTween then
		activeTabPulseTween:Cancel()
		activeTabPulseTween = nil
	end
	currentTab = tabName
	for name, data in pairs(tabButtons) do
		local isActive = name == tabName
		TweenService:Create(data.button, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			BackgroundColor3 = isActive and Color3.fromRGB(200, 20, 20) or Color3.fromRGB(15, 15, 25)
		}):Play()
		local targetColor = isActive and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(100, 100, 100)
		local targetThickness = isActive and 1.5 or 1.0
		TweenService:Create(data.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Color = targetColor,
			Thickness = targetThickness
		}):Play()
		if isActive then
			local pulseInfo = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			activeTabPulseTween = TweenService:Create(data.stroke, pulseInfo, {
				Color = targetColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25),
				Thickness = 2.0
			})
			activeTabPulseTween:Play()
		end
	end
	for name, frame in pairs(tabFrames) do
		frame.Visible = name == tabName
	end
end

for i, tabName in ipairs(tabs) do
	local tabButton = Instance.new("TextButton")
	tabButton.Size = UDim2.new(1/#tabs - 0.015, 0, 1, 0)
	tabButton.Position = UDim2.new((i - 1) * (1/#tabs), (i == 1) and 0 or 0, 0, 0)
	tabButton.BackgroundColor3 = i == 1 and Color3.fromRGB(200, 20, 20) or Color3.fromRGB(15, 15, 25)
	tabButton.BackgroundTransparency = 0.2
	tabButton.Text = tabName
	tabButton.Font = Enum.Font.FredokaOne
	tabButton.TextSize = 6
	tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	tabButton.Parent = tabContainer

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 3)
	tabCorner.Parent = tabButton

	local tabStroke = Instance.new("UIStroke")
	tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tabStroke.Color = i == 1 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(100, 100, 100)
	tabStroke.Thickness = i == 1 and 1.5 or 1.0
	tabStroke.Transparency = 0.3
	tabStroke.Parent = tabButton

	tabButtons[tabName] = {button = tabButton, stroke = tabStroke}

	local tabFrame = Instance.new("Frame")
	tabFrame.Size = UDim2.new(0.9, 0, 1, -52)
	tabFrame.Position = UDim2.new(0.05, 0, 0, 47)
	tabFrame.BackgroundTransparency = 1
	tabFrame.Visible = i == 1
	tabFrame.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = tabFrame

	tabFrames[tabName] = tabFrame

	tabButton.MouseButton1Click:Connect(function()
		setActiveTab(tabName)
	end)
end

local tradeFrame = tabFrames["Trade"]
local spawnerFrame = tabFrames["Spawner"]
local itemsFrame = tabFrames["Items"]
local levelFrame = tabFrames["Level"]
local miscFrame = tabFrames["Misc"]

local function CreateSpace(Frame)
	local Space = Instance.new("Frame")
	Space.Size = UDim2.new(1, 0, 0, 2)
	Space.BackgroundTransparency = 1
	Space.Parent = Frame
end

local function CreateButton(Frame, Text, Function, customColor)
	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(1, 0, 0, 18)
	if customColor then
		Button.BackgroundColor3 = customColor
	else
		Button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	end
	Button.BackgroundTransparency = 0.2
	Button.Text = Text
	Button.Font = Enum.Font.FredokaOne
	Button.TextSize = 9
	Button.TextColor3 = Color3.fromRGB(255, 255, 255)
	Button.Parent = Frame

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 3)
	Corner.Parent = Button

	local Stroke = Instance.new("UIStroke")
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Color = Color3.fromRGB(0, 0, 0)
	Stroke.Thickness = 1.5
	Stroke.Transparency = 0.3
	Stroke.Parent = Button

	Button.MouseButton1Click:Connect(Function)
	return Button
end

local function CreateToggleButton(Frame, Text, Callback)
	local State = false
	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(1, 0, 0, 18)
	Button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	Button.BackgroundTransparency = 0.2
	Button.Text = Text .. ": OFF"
	Button.Font = Enum.Font.FredokaOne
	Button.TextSize = 9
	Button.TextColor3 = Color3.fromRGB(255, 255, 255)
	Button.Parent = Frame

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 3)
	Corner.Parent = Button

	local Stroke = Instance.new("UIStroke")
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Color = Color3.fromRGB(0, 0, 0)
	Stroke.Thickness = 1.5
	Stroke.Transparency = 0.3
	Stroke.Parent = Button

	local OnColor = Color3.fromRGB(120, 20, 20)
	local OffColor = Color3.fromRGB(30, 30, 40)

	local function UpdateVisual()
		TweenService:Create(Button, TweenInfo.new(0.15), {
			BackgroundColor3 = State and OnColor or OffColor
		}):Play()
		Button.Text = Text .. (State and ": ON" or ": OFF")
	end

	Button.MouseButton1Click:Connect(function()
		State = not State
		UpdateVisual()
		Callback(State)
	end)
	return Button, function() return State end
end

local pulsationTweens = {}

function createSettingRow(labelText, defaultValue, parent, textSize)
	textSize = textSize or 9
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 22)
	row.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 1)
	layout.Parent = row

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, 0, 0, 9)
	heading.BackgroundTransparency = 1
	heading.Text = labelText
	heading.Font = Enum.Font.SourceSansSemibold
	heading.TextSize = 8
	heading.TextColor3 = Color3.fromRGB(180, 180, 180)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Parent = row

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 15)
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	box.BackgroundTransparency = 0.2
	box.Text = defaultValue
	box.Font = Enum.Font.SourceSans
	box.TextSize = textSize
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = box

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.0
	stroke.Transparency = 0.5
	stroke.Parent = box

	box.Focused:Connect(function()
		if pulsationTweens[box] then
			pulsationTweens[box]:Cancel()
		end
		local pulseInfo = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		pulsationTweens[box] = TweenService:Create(stroke, pulseInfo, {
			Color = Color3.fromRGB(150, 150, 150):Lerp(Color3.fromRGB(200, 200, 200), 0.5),
			Thickness = 1.5,
			Transparency = 0.2
		})
		pulsationTweens[box]:Play()
	end)

	box.FocusLost:Connect(function()
		if pulsationTweens[box] then
			pulsationTweens[box]:Cancel()
			pulsationTweens[box] = nil
		end
		TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Color = Color3.fromRGB(0, 0, 0),
			Thickness = 1.0,
			Transparency = 0.5
		}):Play()
	end)

	return box, stroke, heading
end

-- ==================== TRADE TAB ====================
local PartnerUserBox = createSettingRow("Partner:", TradeTable.Player2.Player, tradeFrame, 8)
PartnerUserBox.FocusLost:Connect(function()
	TradeTable.Player2.Player = PartnerUserBox.Text
	PartnerUserBox.Text = TradeTable.Player2.Player
end)
CreateSpace(tradeFrame)

CreateButton(tradeFrame, "Recent", function()
	if LastTradePartner and LastTradePartner ~= "" then
		TradeTable.Player2.Player = LastTradePartner
		PartnerUserBox.Text = LastTradePartner
	end
end)
CreateSpace(tradeFrame)

local FakeTradePartners = {
	"xX_ShadowSlayer_Xx", "BloxyKing2008", "NoobMaster69", "PixelKnightz",
	"CrimsonReaperX", "MidnightFury77", "ZeroHavoc", "EpicGamer_LOL",
	"SilentStorm_YT", "FrostWolfie", "DragonHunter999", "SkyBreaker42",
}

CreateButton(tradeFrame, "Random Player", function()
	local chosen = FakeTradePartners[math.random(1, #FakeTradePartners)]
	TradeTable.Player2.Player = chosen
	PartnerUserBox.Text = chosen
	pcall(function()
		TheirOffer.Username.Text = "(" .. chosen .. ")"
	end)
end)
CreateSpace(tradeFrame)

CreateButton(tradeFrame, "Trade Spoof/Start", function()
	StartTrade()
end, Color3.fromRGB(200, 20, 20))
CreateSpace(tradeFrame)

CreateButton(tradeFrame, "Accept Offer", function()
	if not next(TradeTable["Player1"]["Offer"]) and not next(TradeTable["Player2"]["Offer"]) then
		return
	end
	if v84 then
		return
	end
	TheirOffer.Accepted.Visible = true
	TradeTable["Player2"]["Accepted"] = true
	AcceptTrade()
end)
CreateSpace(tradeFrame)

local function SilentBlockPlayer(Selected)
	if not Selected then return end
	local playerName = (typeof(Selected) == "Instance" and Selected.Name) or tostring(Selected)
	print("[block] Blocking: " .. playerName)
	pcall(function()
		game:GetService("StarterGui"):SetCore("PromptBlockPlayer", Selected)
	end)
end

CreateButton(tradeFrame, "Block Player", function()
	pcall(function()
		local Selected = game.Players:FindFirstChild(TradeTable.Player2.Player)
		SilentBlockPlayer(Selected)
	end)
end)

-- Fake offer display in Trade tab
local fakeOfferLabel = Instance.new("TextLabel")
fakeOfferLabel.Size = UDim2.new(1, 0, 0, 9)
fakeOfferLabel.BackgroundTransparency = 1
fakeOfferLabel.Text = "Their Offer:"
fakeOfferLabel.Font = Enum.Font.SourceSansSemibold
fakeOfferLabel.TextSize = 8
fakeOfferLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
fakeOfferLabel.TextXAlignment = Enum.TextXAlignment.Left
fakeOfferLabel.Parent = tradeFrame

fakeOfferListFrame = Instance.new("Frame")
fakeOfferListFrame.Size = UDim2.new(1, 0, 0, 60)
fakeOfferListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
fakeOfferListFrame.BackgroundTransparency = 0.3
fakeOfferListFrame.BorderSizePixel = 0
fakeOfferListFrame.Parent = tradeFrame

local fakeOfferLayout = Instance.new("UIListLayout")
fakeOfferLayout.FillDirection = Enum.FillDirection.Vertical
fakeOfferLayout.SortOrder = Enum.SortOrder.LayoutOrder
fakeOfferLayout.Padding = UDim.new(0, 1)
fakeOfferLayout.Parent = fakeOfferListFrame

local fakeOfferPadding = Instance.new("UIPadding")
fakeOfferPadding.PaddingLeft = UDim.new(0, 4)
fakeOfferPadding.PaddingRight = UDim.new(0, 4)
fakeOfferPadding.Parent = fakeOfferListFrame

UpdateFakeOfferDisplay()

-- ==================== SPAWNER TAB ====================
local spawnerLabel = Instance.new("TextLabel")
spawnerLabel.Size = UDim2.new(1, 0, 0, 12)
spawnerLabel.BackgroundTransparency = 1
spawnerLabel.Text = "Spawn Weapons (2x Chroma)"
spawnerLabel.Font = Enum.Font.FredokaOne
spawnerLabel.TextSize = 10
spawnerLabel.TextColor3 = Color3.fromRGB(200, 20, 20)
spawnerLabel.TextXAlignment = Enum.TextXAlignment.Center
spawnerLabel.Parent = spawnerFrame

CreateSpace(spawnerFrame)

local spawnerAmountBox = createSettingRow("Amount:", "1", spawnerFrame)
CreateSpace(spawnerFrame)

local SpawnerAllowedBases = {
	"Corrupt", "Gingerscope", "Traveler's Axe", "Celestial",
	"Vampire's Axe", "Harvester", "Icepiercer", "Traveler's Gun",
	"Evergun", "Evergreen", "Bauble", "Constellation",
	"Vampire's Gun", "Alienbeam", "Raygun", "Sunrise",
	"Snowcannon", "Blizzard", "Sunset", "Snow Dagger",
	"Treat", "Heart Wand", "Snowstorm", "Watergun",
	"Sweet", "Ornament",
}

local function _itemsTabNormalize(s)
	s = string.lower(tostring(s or ""))
	s = string.gsub(s, "^c%.%s*", "chroma ")
	s = string.gsub(s, "(%s)c%.%s*", "%1chroma ")
	s = string.gsub(s, "['\u{2019}\"]", "")
	s = string.gsub(s, "%s+", " ")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

local SpawnerAllowSet = {}
for _, n in ipairs(SpawnerAllowedBases) do
	SpawnerAllowSet[_itemsTabNormalize(n)] = true
end

-- Collect all matching entries from WeaponCatalog (includes Chroma versions)
local spawnerEntries = {}
for _, entry in ipairs(WeaponCatalog) do
	local base = entry.chroma and string.gsub(string.lower(entry.name), "^chroma ", "") or string.lower(entry.name)
	base = _itemsTabNormalize(base)
	if SpawnerAllowSet[base] then
		table.insert(spawnerEntries, {
			name = entry.name,
			key = entry.key,
			chroma = entry.chroma,
			rarity = entry.rarity
		})
	end
end

-- Remove duplicates (same key)
local seen = {}
local uniqueSpawnerEntries = {}
for _, e in ipairs(spawnerEntries) do
	if not seen[e.key] then
		table.insert(uniqueSpawnerEntries, e)
		seen[e.key] = true
	end
end

table.sort(uniqueSpawnerEntries, function(a, b)
	if a.chroma ~= b.chroma then return a.chroma end
	return a.name < b.name
end)

-- Filter variables
local spawnerFilter = "All" -- can be "All", "Chroma", "Regular"
local function getFilteredEntries()
	if spawnerFilter == "All" then
		return uniqueSpawnerEntries
	elseif spawnerFilter == "Chroma" then
		local res = {}
		for _, e in ipairs(uniqueSpawnerEntries) do
			if e.chroma then table.insert(res, e) end
		end
		return res
	elseif spawnerFilter == "Regular" then
		local res = {}
		for _, e in ipairs(uniqueSpawnerEntries) do
			if not e.chroma then table.insert(res, e) end
		end
		return res
	end
	return uniqueSpawnerEntries
end

-- Filter buttons
local filterLabel = Instance.new("TextLabel")
filterLabel.Size = UDim2.new(1, 0, 0, 9)
filterLabel.BackgroundTransparency = 1
filterLabel.Text = "Filter:"
filterLabel.Font = Enum.Font.SourceSansSemibold
filterLabel.TextSize = 8
filterLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
filterLabel.TextXAlignment = Enum.TextXAlignment.Left
filterLabel.Parent = spawnerFrame

local filterButtonContainer = Instance.new("Frame")
filterButtonContainer.Size = UDim2.new(1, 0, 0, 14)
filterButtonContainer.BackgroundTransparency = 1
filterButtonContainer.Parent = spawnerFrame

local filterButtons = {}
local filterOptions = {"All", "Chroma", "Regular"}
local activeFilterButton = nil
local function setFilter(filter)
	spawnerFilter = filter
	for _, data in pairs(filterButtons) do
		TweenService:Create(data.button, TweenInfo.new(0.2), {
			BackgroundColor3 = data.filter == filter and Color3.fromRGB(200, 20, 20) or Color3.fromRGB(30, 30, 40)
		}):Play()
	end
	-- Update dropdown list
	populateDropdown()
	if selectedSpawnEntry then
		-- keep selected if still visible, otherwise reset
		local filtered = getFilteredEntries()
		local found = false
		for _, e in ipairs(filtered) do
			if e.key == selectedSpawnEntry.key then found = true; break end
		end
		if not found and #filtered > 0 then
			selectedSpawnEntry = filtered[1]
			dropdownButton.Text = selectedSpawnEntry.name
		end
	end
end

for i, opt in ipairs(filterOptions) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1/3 - 0.01, 0, 1, 0)
	btn.Position = UDim2.new((i-1)/3, 0, 0, 0)
	btn.BackgroundColor3 = i == 1 and Color3.fromRGB(200, 20, 20) or Color3.fromRGB(30, 30, 40)
	btn.BackgroundTransparency = 0.2
	btn.Text = opt
	btn.Font = Enum.Font.SourceSansBold
	btn.TextSize = 7
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Parent = filterButtonContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = btn

	filterButtons[opt] = {button = btn, filter = opt}
	btn.MouseButton1Click:Connect(function()
		setFilter(opt)
	end)
end

CreateSpace(spawnerFrame)

-- Dropdown UI
local dropdownLabel = Instance.new("TextLabel")
dropdownLabel.Size = UDim2.new(1, 0, 0, 9)
dropdownLabel.BackgroundTransparency = 1
dropdownLabel.Text = "Select Weapon:"
dropdownLabel.Font = Enum.Font.SourceSansSemibold
dropdownLabel.TextSize = 8
dropdownLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
dropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
dropdownLabel.Parent = spawnerFrame

local dropdownButton = Instance.new("TextButton")
dropdownButton.Size = UDim2.new(1, 0, 0, 18)
dropdownButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
dropdownButton.BackgroundTransparency = 0.2
dropdownButton.Text = "Corrupt"
dropdownButton.Font = Enum.Font.FredokaOne
dropdownButton.TextSize = 9
dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
dropdownButton.Parent = spawnerFrame

local dropdownCorner = Instance.new("UICorner")
dropdownCorner.CornerRadius = UDim.new(0, 3)
dropdownCorner.Parent = dropdownButton

local dropdownStroke = Instance.new("UIStroke")
dropdownStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
dropdownStroke.Color = Color3.fromRGB(0, 0, 0)
dropdownStroke.Thickness = 1
dropdownStroke.Parent = dropdownButton

local dropdownList = Instance.new("ScrollingFrame")
dropdownList.Size = UDim2.new(1, 0, 0, 60)
dropdownList.Position = UDim2.new(0, 0, 0, 18)
dropdownList.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
dropdownList.BackgroundTransparency = 0.2
dropdownList.BorderSizePixel = 0
dropdownList.ScrollBarThickness = 3
dropdownList.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
dropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
dropdownList.Visible = false
dropdownList.ZIndex = 5
dropdownList.Parent = spawnerFrame

local dropdownCorner2 = Instance.new("UICorner")
dropdownCorner2.CornerRadius = UDim.new(0, 3)
dropdownCorner2.Parent = dropdownList

local dropdownLayout = Instance.new("UIListLayout")
dropdownLayout.FillDirection = Enum.FillDirection.Vertical
dropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
dropdownLayout.Padding = UDim.new(0, 1)
dropdownLayout.Parent = dropdownList

local selectedSpawnEntry = uniqueSpawnerEntries[1]
dropdownButton.Text = selectedSpawnEntry.name

local function populateDropdown()
	-- Clear list
	for _, child in ipairs(dropdownList:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	local filtered = getFilteredEntries()
	for _, entry in ipairs(filtered) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -2, 0, 14)
		btn.BackgroundColor3 = entry.chroma and Color3.fromRGB(70, 20, 80) or Color3.fromRGB(40, 25, 15)
		btn.BackgroundTransparency = 0.2
		btn.Text = entry.name
		btn.Font = Enum.Font.SourceSans
		btn.TextSize = 8
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.ZIndex = 6
		btn.Parent = dropdownList
		
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 4)
		pad.Parent = btn
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = btn
		
		btn.MouseButton1Click:Connect(function()
			selectedSpawnEntry = entry
			dropdownButton.Text = entry.name
			dropdownList.Visible = false
		end)
	end
end
populateDropdown()

dropdownButton.MouseButton1Click:Connect(function()
	dropdownList.Visible = not dropdownList.Visible
end)

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		task.wait(0.1)
		if dropdownList.Visible then
			local mousePos = UserInputService:GetMouseLocation()
			local absPos = dropdownList.AbsolutePosition
			local absSize = dropdownList.AbsoluteSize
			if mousePos.X < absPos.X or mousePos.X > absPos.X + absSize.X or
			   mousePos.Y < absPos.Y or mousePos.Y > absPos.Y + absSize.Y then
				dropdownList.Visible = false
			end
		end
	end
end)

CreateSpace(spawnerFrame)

CreateButton(spawnerFrame, "Spawn Selected", function()
	local amount = tonumber(spawnerAmountBox.Text)
	if not amount or amount < 1 then amount = 1 end
	if selectedSpawnEntry then
		SpawnItem(selectedSpawnEntry.key, amount, "Weapons")
		spawnerStatusLabel.Text = "Spawned " .. selectedSpawnEntry.name .. " x" .. amount
		spawnerStatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
		print("[LiveVisuals] Spawned " .. selectedSpawnEntry.name .. " x" .. amount)
	else
		spawnerStatusLabel.Text = "No weapon selected!"
		spawnerStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	end
end, Color3.fromRGB(200, 20, 20))

CreateSpace(spawnerFrame)

local SpawnerRandomRanges = {
	Chroma    = {1, 2},
	Godly     = {1, 5},
	Ancient   = {2, 6},
	Unique    = {2, 8},
	Classic   = {3, 10},
	Legendary = {4, 12},
	Vintage   = {5, 15},
	Rare      = {8, 25},
	Uncommon  = {10, 40},
	Common    = {15, 60},
}

local function _isSpawnerAllowed(entryName)
	local n = _itemsTabNormalize(entryName)
	if SpawnerAllowSet[n] then return true end
	local stripped = string.gsub(n, "^chroma ", "")
	return SpawnerAllowSet[stripped] == true
end

local function _isTradable(data)
	if type(data) ~= "table" then return false end
	if data.Tradable == false then return false end
	if data.CanTrade == false then return false end
	if data.Untradable == true then return false end
	if data.NonTradable == true then return false end
	if data.Locked == true then return false end
	return true
end

local function _randomAmount(rarity, evo)
	if evo then return 1 end
	local r = SpawnerRandomRanges[rarity] or SpawnerRandomRanges.Common
	return math.random(r[1], r[2])
end

CreateButton(spawnerFrame, "Spawn All (Tradable)", function()
	local source = Sync.Weapons or Sync.Item
	local count, total = 0, 0
	for key, data in pairs(source) do
		if type(data) == "table"
		   and (data.ItemType == "Knife" or data.ItemType == "Gun")
		   and _isTradable(data)
		   and _isSpawnerAllowed(data.ItemName or key) then
			local rarity = data.Rarity or "Common"
			if data.Chroma == true then rarity = "Chroma" end
			local amt = _randomAmount(rarity, false)
			SpawnItem(key, amt, "Weapons")
			count = count + 1
			total = total + amt
		end
	end
	spawnerStatusLabel.Text = ("Spawned %d weapons (%d items total)"):format(count, total)
	spawnerStatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
	print("[LiveVisuals] Bulk spawn: " .. count .. " weapon types, " .. total .. " items total")
end, Color3.fromRGB(200, 20, 20))

CreateSpace(spawnerFrame)

local spawnerStatusLabel = Instance.new("TextLabel")
spawnerStatusLabel.Size = UDim2.new(1, 0, 0, 10)
spawnerStatusLabel.BackgroundTransparency = 1
spawnerStatusLabel.Text = "Ready to spawn"
spawnerStatusLabel.Font = Enum.Font.SourceSansSemibold
spawnerStatusLabel.TextSize = 7
spawnerStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
spawnerStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
spawnerStatusLabel.Parent = spawnerFrame

-- ==================== ITEMS TAB (spawn to partner during trade) ====================
local itemsLabel = Instance.new("TextLabel")
itemsLabel.Size = UDim2.new(1, 0, 0, 12)
itemsLabel.BackgroundTransparency = 1
itemsLabel.Text = "Spawn to Partner"
itemsLabel.Font = Enum.Font.FredokaOne
itemsLabel.TextSize = 10
itemsLabel.TextColor3 = Color3.fromRGB(200, 20, 20)
itemsLabel.TextXAlignment = Enum.TextXAlignment.Center
itemsLabel.Parent = itemsFrame

CreateSpace(itemsFrame)

local itemsAmountBox = createSettingRow("Amount:", "1", itemsFrame)
CreateSpace(itemsFrame)

-- Reuse the same entries and filter logic for Items tab
local itemsDropdownButton = Instance.new("TextButton")
itemsDropdownButton.Size = UDim2.new(1, 0, 0, 18)
itemsDropdownButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
itemsDropdownButton.BackgroundTransparency = 0.2
itemsDropdownButton.Text = "Corrupt"
itemsDropdownButton.Font = Enum.Font.FredokaOne
itemsDropdownButton.TextSize = 9
itemsDropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
itemsDropdownButton.Parent = itemsFrame

local itemsDropdownCorner = Instance.new("UICorner")
itemsDropdownCorner.CornerRadius = UDim.new(0, 3)
itemsDropdownCorner.Parent = itemsDropdownButton

local itemsDropdownList = Instance.new("ScrollingFrame")
itemsDropdownList.Size = UDim2.new(1, 0, 0, 60)
itemsDropdownList.Position = UDim2.new(0, 0, 0, 18)
itemsDropdownList.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
itemsDropdownList.BackgroundTransparency = 0.2
itemsDropdownList.BorderSizePixel = 0
itemsDropdownList.ScrollBarThickness = 3
itemsDropdownList.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
itemsDropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
itemsDropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
itemsDropdownList.Visible = false
itemsDropdownList.ZIndex = 5
itemsDropdownList.Parent = itemsFrame

local itemsDropdownCorner2 = Instance.new("UICorner")
itemsDropdownCorner2.CornerRadius = UDim.new(0, 3)
itemsDropdownCorner2.Parent = itemsDropdownList

local itemsDropdownLayout = Instance.new("UIListLayout")
itemsDropdownLayout.FillDirection = Enum.FillDirection.Vertical
itemsDropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
itemsDropdownLayout.Padding = UDim.new(0, 1)
itemsDropdownLayout.Parent = itemsDropdownList

local itemsSelectedEntry = uniqueSpawnerEntries[1]
itemsDropdownButton.Text = itemsSelectedEntry.name

local function populateItemsDropdown()
	for _, child in ipairs(itemsDropdownList:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	local filtered = getFilteredEntries() -- can reuse same filter state, but we can keep separate
	for _, entry in ipairs(filtered) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -2, 0, 14)
		btn.BackgroundColor3 = entry.chroma and Color3.fromRGB(70, 20, 80) or Color3.fromRGB(40, 25, 15)
		btn.BackgroundTransparency = 0.2
		btn.Text = entry.name
		btn.Font = Enum.Font.SourceSans
		btn.TextSize = 8
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.ZIndex = 6
		btn.Parent = itemsDropdownList
		
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 4)
		pad.Parent = btn
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = btn
		
		btn.MouseButton1Click:Connect(function()
			itemsSelectedEntry = entry
			itemsDropdownButton.Text = entry.name
			itemsDropdownList.Visible = false
		end)
	end
end
populateItemsDropdown()

itemsDropdownButton.MouseButton1Click:Connect(function()
	itemsDropdownList.Visible = not itemsDropdownList.Visible
end)

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		task.wait(0.1)
		if itemsDropdownList.Visible then
			local mousePos = UserInputService:GetMouseLocation()
			local absPos = itemsDropdownList.AbsolutePosition
			local absSize = itemsDropdownList.AbsoluteSize
			if mousePos.X < absPos.X or mousePos.X > absPos.X + absSize.X or
			   mousePos.Y < absPos.Y or mousePos.Y > absPos.Y + absSize.Y then
				itemsDropdownList.Visible = false
			end
		end
	end
end)

CreateSpace(itemsFrame)

CreateButton(itemsFrame, "Spawn to Partner", function()
	if not Config.in_trade then
		itemsStatusLabel.Text = "Must be in trade!"
		itemsStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end
	local amount = tonumber(itemsAmountBox.Text)
	if not amount or amount < 1 then amount = 1 end
	if itemsSelectedEntry then
		for i=1, amount do
			OfferItemAnotherPlayer(itemsSelectedEntry.key, "Weapons")
		end
		itemsStatusLabel.Text = "Added " .. itemsSelectedEntry.name .. " x" .. amount
		itemsStatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
	else
		itemsStatusLabel.Text = "No weapon selected!"
		itemsStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	end
end, Color3.fromRGB(200, 20, 20))

CreateSpace(itemsFrame)

local itemsStatusLabel = Instance.new("TextLabel")
itemsStatusLabel.Size = UDim2.new(1, 0, 0, 10)
itemsStatusLabel.BackgroundTransparency = 1
itemsStatusLabel.Text = "Ready"
itemsStatusLabel.Font = Enum.Font.SourceSansSemibold
itemsStatusLabel.TextSize = 7
itemsStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
itemsStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
itemsStatusLabel.Parent = itemsFrame

-- ==================== LEVEL TAB ====================
local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.new(1, 0, 0, 12)
levelLabel.BackgroundTransparency = 1
levelLabel.Text = "Level Spoof"
levelLabel.Font = Enum.Font.FredokaOne
levelLabel.TextSize = 10
levelLabel.TextColor3 = Color3.fromRGB(200, 20, 20)
levelLabel.TextXAlignment = Enum.TextXAlignment.Center
levelLabel.Parent = levelFrame

CreateSpace(levelFrame)

local levelBox = createSettingRow("Set Level:", "100", levelFrame)
CreateSpace(levelFrame)

local levelStatusLabel = Instance.new("TextLabel")
levelStatusLabel.Size = UDim2.new(1, 0, 0, 10)
levelStatusLabel.BackgroundTransparency = 1
levelStatusLabel.Text = "Current Level: ?"
levelStatusLabel.Font = Enum.Font.SourceSansSemibold
levelStatusLabel.TextSize = 8
levelStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
levelStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
levelStatusLabel.Parent = levelFrame

CreateSpace(levelFrame)

local levelSpoofToggle, getLevelSpoofState = CreateToggleButton(levelFrame, "Level Spoof", function(state)
	levelSpoofEnabled = state
	if state then
		levelStatusLabel.Text = "Level Spoof: ON"
		levelStatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
		local levelNum = tonumber(levelBox.Text)
		if levelNum and levelNum > 0 then
			spoofedLevel = levelNum
			ApplyLevelSpoof(levelNum)
		end
	else
		levelStatusLabel.Text = "Level Spoof: OFF"
		levelStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		pcall(function()
			local player = game.Players.LocalPlayer
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local levelStat = leaderstats:FindFirstChild("Level")
				if levelStat and levelStat._original then
					levelStat.Value = levelStat._original
				end
			end
			pcall(function()
				if ProfileData and ProfileData._originalLevel then
					ProfileData.Level = ProfileData._originalLevel
				end
			end)
			local currentName = player.DisplayName
			local cleanName = string.gsub(currentName, "^%[Lv%d+%]%s*", "")
			if cleanName ~= currentName then
				player.DisplayName = cleanName
			end
		end)
	end
end)

CreateSpace(levelFrame)

CreateButton(levelFrame, "Apply Level Spoof", function()
	local levelNum = tonumber(levelBox.Text)
	if not levelNum then
		levelStatusLabel.Text = "Invalid level!"
		levelStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end
	
	if levelNum < 1 then levelNum = 1 end
	if levelNum > 9999 then levelNum = 9999 end
	
	spoofedLevel = levelNum
	
	if levelSpoofEnabled then
		ApplyLevelSpoof(levelNum)
		levelStatusLabel.Text = "Level set to: " .. levelNum
		levelStatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
	else
		levelStatusLabel.Text = "Toggle ON first!"
		levelStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	end
end, Color3.fromRGB(200, 20, 20))

CreateSpace(levelFrame)

CreateButton(levelFrame, "Reset Level", function()
	pcall(function()
		local player = game.Players.LocalPlayer
		levelSpoofEnabled = false
		
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local levelStat = leaderstats:FindFirstChild("Level")
			if levelStat and levelStat._original then
				levelStat.Value = levelStat._original
			end
		end
		
		pcall(function()
			if ProfileData and ProfileData._originalLevel then
				ProfileData.Level = ProfileData._originalLevel
			end
		end)
		
		local currentName = player.DisplayName
		local cleanName = string.gsub(currentName, "^%[Lv%d+%]%s*", "")
		if cleanName ~= currentName then
			player.DisplayName = cleanName
		end
		
		levelStatusLabel.Text = "Level reset!"
		levelStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	end)
end)

-- ==================== MISC TAB ====================
local miscLabel = Instance.new("TextLabel")
miscLabel.Size = UDim2.new(1, 0, 0, 12)
miscLabel.BackgroundTransparency = 1
miscLabel.Text = "Clone & Mesh Spoof"
miscLabel.Font = Enum.Font.FredokaOne
miscLabel.TextSize = 10
miscLabel.TextColor3 = Color3.fromRGB(200, 20, 20)
miscLabel.TextXAlignment = Enum.TextXAlignment.Center
miscLabel.Parent = miscFrame

CreateSpace(miscFrame)

-- CLONE SECTION
local cloneLabel = Instance.new("TextLabel")
cloneLabel.Size = UDim2.new(1, 0, 0, 9)
cloneLabel.BackgroundTransparency = 1
cloneLabel.Text = "Avatar Clone (C)"
cloneLabel.Font = Enum.Font.SourceSansSemibold
cloneLabel.TextSize = 8
cloneLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
cloneLabel.TextXAlignment = Enum.TextXAlignment.Left
cloneLabel.Parent = miscFrame

local cloneUserBox = createSettingRow("Username:", "", miscFrame, 8)
CreateSpace(miscFrame)

CreateButton(miscFrame, "Spawn Clone", function()
	local targetName = cloneUserBox.Text
	if not targetName or targetName == "" then
		cloneStatusLabel.Text = "Enter a username!"
		cloneStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end

	local targetPlayer = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == string.lower(targetName) then
			targetPlayer = p
			break
		end
	end

	if not targetPlayer then
		cloneStatusLabel.Text = "Player not in server"
		cloneStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end

	local char = targetPlayer.Character
	if not char or not char.Parent then
		cloneStatusLabel.Text = "Character not loaded"
		cloneStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		return
	end

	-- Clone and cleanup
	local clone = char:Clone()
	clone.Name = targetPlayer.Name .. "_Clone"
	clone:SetAttribute("FakeClone", true)

	for _, v in ipairs(clone:GetDescendants()) do
		if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Sound") then
			v:Destroy()
		elseif v:IsA("Humanoid") then
			v:Destroy()
		elseif v:IsA("BasePart") then
			v.Anchored = true
			v.CanCollide = false
		end
	end

	-- Set PrimaryPart for positioning
	local hrp = clone:FindFirstChild("HumanoidRootPart")
	local head = clone:FindFirstChild("Head")
	if hrp then
		clone.PrimaryPart = hrp
	elseif head then
		clone.PrimaryPart = head
	end

	-- Position near local player
	local localChar = game.Players.LocalPlayer.Character
	if localChar and localChar:FindFirstChild("HumanoidRootPart") and clone.PrimaryPart then
		clone:SetPrimaryPartCFrame(localChar.HumanoidRootPart.CFrame + Vector3.new(math.random(-5,5), 0, math.random(-5,5)))
	end

	-- Remove old clone with same name
	local existingClone = workspace:FindFirstChild(clone.Name)
	if existingClone then existingClone:Destroy() end

	clone.Parent = workspace

	-- Add name billboard to head
	if head then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NameTag"
		billboard.Adornee = head
		billboard.Size = UDim2.new(0, 200, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 50
		billboard.Parent = head

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, 0, 0, 30)
		nameLabel.Text = targetPlayer.DisplayName or targetPlayer.Name
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextStrokeTransparency = 0
		nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		nameLabel.Font = Enum.Font.SourceSansBold
		nameLabel.TextSize = 14
		nameLabel.Parent = billboard
	end

	cloneStatusLabel.Text = "Clone spawned: " .. targetPlayer.Name
	cloneStatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
	print("[LiveVisuals] Spawned clone of " .. targetPlayer.Name)
end, Color3.fromRGB(200, 20, 20))

CreateSpace(miscFrame)

CreateButton(miscFrame, "Delete Clone (V)", function()
	local clonesDeleted = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("FakeClone") then
			obj:Destroy()
			clonesDeleted = clonesDeleted + 1
		end
	end
	cloneStatusLabel.Text = "Deleted " .. clonesDeleted .. " clone(s)"
	cloneStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
end)

CreateSpace(miscFrame)

-- AUTO MESH SPOOF SECTION
local meshSpoofLabel = Instance.new("TextLabel")
meshSpoofLabel.Size = UDim2.new(1, 0, 0, 9)
meshSpoofLabel.BackgroundTransparency = 1
meshSpoofLabel.Text = "Auto Mesh Spoof (M)"
meshSpoofLabel.Font = Enum.Font.SourceSansSemibold
meshSpoofLabel.TextSize = 8
meshSpoofLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
meshSpoofLabel.TextXAlignment = Enum.TextXAlignment.Left
meshSpoofLabel.Parent = miscFrame

local autoMeshSpoofEnabled = false
local lastMeshId = ""

local meshSpoofToggle, getMeshSpoofState = CreateToggleButton(miscFrame, "Auto Mesh Spoof", function(state)
	autoMeshSpoofEnabled = state
	meshStatusLabel.Text = state and "Auto Mesh Spoof: ON" or "Auto Mesh Spoof: OFF"
end)

CreateSpace(miscFrame)

CreateButton(miscFrame, "Show Last Mesh ID", function()
	if lastMeshId ~= "" then
		meshStatusLabel.Text = "Last Mesh: " .. lastMeshId
		meshStatusLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
		print("[LiveVisuals] Last Mesh ID: " .. lastMeshId)
	else
		meshStatusLabel.Text = "No mesh spoofed yet"
		meshStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	end
end)

CreateSpace(miscFrame)

local meshStatusLabel = Instance.new("TextLabel")
meshStatusLabel.Size = UDim2.new(1, 0, 0, 10)
meshStatusLabel.BackgroundTransparency = 1
meshStatusLabel.Text = "Auto Mesh Spoof: OFF"
meshStatusLabel.Font = Enum.Font.SourceSansSemibold
meshStatusLabel.TextSize = 7
meshStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
meshStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
meshStatusLabel.Parent = miscFrame

local cloneStatusLabel = Instance.new("TextLabel")
cloneStatusLabel.Size = UDim2.new(1, 0, 0, 10)
cloneStatusLabel.BackgroundTransparency = 1
cloneStatusLabel.Text = "Ready"
cloneStatusLabel.Font = Enum.Font.SourceSansSemibold
cloneStatusLabel.TextSize = 7
cloneStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
cloneStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
cloneStatusLabel.Parent = miscFrame

-- Keybinds for Misc tab
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not controlGui.Enabled then return end
	if input.KeyCode == Enum.KeyCode.C then
		-- Spawn clone action
		-- Simulate clicking the spawn clone button (find it)
		-- For simplicity, call the function directly with the current text
		if cloneUserBox.Text and cloneUserBox.Text ~= "" then
			-- trigger spawn clone logic
			local targetName = cloneUserBox.Text
			local targetPlayer = nil
			for _, p in ipairs(Players:GetPlayers()) do
				if string.lower(p.Name) == string.lower(targetName) then
					targetPlayer = p
					break
				end
			end
			if targetPlayer and targetPlayer.Character and targetPlayer.Character.Parent then
				-- reuse spawn code (call from existing function) – we'll call the same code
				-- We'll just call the button's function indirectly by invoking its MouseButton1Click
				-- But it's easier to replicate the functionality
				-- I'll create a helper function
				pcall(function()
					-- Spawn clone code (from above) – we'll just call the same logic
					local char = targetPlayer.Character
					local clone = char:Clone()
					clone.Name = targetPlayer.Name .. "_Clone"
					clone:SetAttribute("FakeClone", true)
					for _, v in ipairs(clone:GetDescendants()) do
						if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Sound") then
							v:Destroy()
						elseif v:IsA("Humanoid") then
							v:Destroy()
						elseif v:IsA("BasePart") then
							v.Anchored = true
							v.CanCollide = false
						end
					end
					local hrp = clone:FindFirstChild("HumanoidRootPart")
					local head = clone:FindFirstChild("Head")
					if hrp then clone.PrimaryPart = hrp elseif head then clone.PrimaryPart = head end
					local localChar = game.Players.LocalPlayer.Character
					if localChar and localChar:FindFirstChild("HumanoidRootPart") and clone.PrimaryPart then
						clone:SetPrimaryPartCFrame(localChar.HumanoidRootPart.CFrame + Vector3.new(math.random(-5,5), 0, math.random(-5,5)))
					end
					local existingClone = workspace:FindFirstChild(clone.Name)
					if existingClone then existingClone:Destroy() end
					clone.Parent = workspace
					if head then
						local billboard = Instance.new("BillboardGui")
						billboard.Name = "NameTag"
						billboard.Adornee = head
						billboard.Size = UDim2.new(0, 200, 0, 30)
						billboard.StudsOffset = Vector3.new(0, 2.5, 0)
						billboard.AlwaysOnTop = true
						billboard.MaxDistance = 50
						billboard.Parent = head
						local nameLabel = Instance.new("TextLabel")
						nameLabel.BackgroundTransparency = 1
						nameLabel.Size = UDim2.new(1, 0, 0, 30)
						nameLabel.Text = targetPlayer.DisplayName or targetPlayer.Name
						nameLabel.TextColor3 = Color3.new(1, 1, 1)
						nameLabel.TextStrokeTransparency = 0
						nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
						nameLabel.Font = Enum.Font.SourceSansBold
						nameLabel.TextSize = 14
						nameLabel.Parent = billboard
					end
					cloneStatusLabel.Text = "Clone spawned: " .. targetPlayer.Name
					cloneStatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
				end)
			else
				cloneStatusLabel.Text = "Player not found"
				cloneStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.V then
		-- Delete clones
		local clonesDeleted = 0
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:IsA("Model") and obj:GetAttribute("FakeClone") then
				obj:Destroy()
				clonesDeleted = clonesDeleted + 1
			end
		end
		cloneStatusLabel.Text = "Deleted " .. clonesDeleted .. " clone(s)"
		cloneStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	elseif input.KeyCode == Enum.KeyCode.M then
		-- Toggle mesh spoof
		autoMeshSpoofEnabled = not autoMeshSpoofEnabled
		meshStatusLabel.Text = autoMeshSpoofEnabled and "Auto Mesh Spoof: ON" or "Auto Mesh Spoof: OFF"
		-- Update toggle button state visually
		pcall(function()
			-- Find the toggle button and update its text
			local btn = getMeshSpoofState and getMeshSpoofState()
		end)
	end
end)

-- ==================== AUTO MESH SPOOF LOGIC ====================
local function findMeshIdFromData(weaponData)
	if type(weaponData) ~= "table" then return nil end
	local mesh = weaponData.MeshId or weaponData.Mesh or weaponData.MeshID or weaponData.WeaponMesh
	if mesh and type(mesh) == "string" and mesh ~= "" then
		return mesh
	end
	if weaponData.Appearance and type(weaponData.Appearance) == "table" then
		return findMeshIdFromData(weaponData.Appearance)
	end
	return nil
end

local function applyMeshToTool(tool, meshId)
	if not tool or not meshId or meshId == "" then return end
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		local mesh = handle:FindFirstChildOfClass("SpecialMesh") or handle:FindFirstChildOfClass("BlockMesh") or handle:FindFirstChildOfClass("CylinderMesh")
		if not mesh then
			mesh = Instance.new("SpecialMesh")
			mesh.Parent = handle
		end
		mesh.MeshId = meshId
		mesh.TextureId = ""
	end
end

local localPlayer = game.Players.LocalPlayer
local function onToolEquipped(tool)
	if not autoMeshSpoofEnabled then return end
	if not tool:IsA("Tool") then return end
	
	local itemKey = nil
	local itemName = tool.Name
	for _, entry in ipairs(WeaponCatalog) do
		if entry.name == itemName or entry.key == itemName then
			itemKey = entry.key
			break
		end
	end
	
	if not itemKey then
		if Sync.Weapons and Sync.Weapons[itemName] then
			itemKey = itemName
		end
	end
	
	if itemKey then
		local weaponData = Sync.Weapons[itemKey] or Sync.Item[itemKey]
		if weaponData then
			local meshId = findMeshIdFromData(weaponData)
			if meshId then
				lastMeshId = meshId
				meshStatusLabel.Text = "Spoofed: " .. meshId
				meshStatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
				print("[LiveVisuals] Mesh Spoof: " .. meshId .. " applied to " .. tool.Name)
				applyMeshToTool(tool, meshId)
			end
		end
	end
end

localPlayer.CharacterAdded:Connect(function(char)
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			onToolEquipped(tool)
		end
	end
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onToolEquipped(child)
		end
	end)
end)

if localPlayer.Character then
	for _, tool in ipairs(localPlayer.Character:GetChildren()) do
		if tool:IsA("Tool") then
			onToolEquipped(tool)
		end
	end
end

-- ==================== INIT ====================
setupPersistentSpoofs()

print("========================================")
print(" Live Visuals Mm2 GUI Loaded!")
print(" Size: 240x240 | Red & Black Theme")
print(" Dragging fixed. Border red & skinny.")
print(" Tabs: Trade, Spawner, Items, Level, Misc")
print(" Spawner filter: All/Chroma/Regular")
print(" Items tab: spawn to partner (must be in trade)")
print(" Misc keybinds: C=Clone, V=Delete, M=MeshSpoof")
print("========================================")
