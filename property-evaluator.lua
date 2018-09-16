local modules = game:GetService("ServerScriptService"):WaitForChild("Modules")
local tycoonModule = require(modules.TycoonModule)
local interactionModule = require(modules.InteractionModule)
local componentModule = require(modules.ComponentModule)

local serverStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local displayItemEvent = ReplicatedStorage:WaitForChild("DisplayItemEvent")
local interactionEvent = ReplicatedStorage:WaitForChild("InteractionEvent")
local messageEvent = ReplicatedStorage:WaitForChild("MessageEvent")

local updateGuiEvent = ReplicatedStorage:WaitForChild("UpdateGuiEvent")


local ret = {} -- return functions

function getBuildLocations(tycoon, item)
  local buildLocations = {}
  for _, buildLocation in pairs(tycoon:GetChildren()) do
    if buildLocation.Name == "BuildLocation" then
      if buildLocation.Size == item.BuildLocation.Size and #buildLocation:GetChildren() == 0 then
        buildLocations[#buildLocations + 1] = {buildLocation.Size, buildLocation.CFrame}
      end
    end
  end
  return buildLocations
end

function getNearestBuildLocation(player, item)
  local tycoon = tycoonModule:GetPlayerRole(player).Value
  local nearest = nil
  local torso = player.Character:FindFirstChild("Torso")
  for _, part in pairs(tycoon:GetChildren()) do
    if part.Name == "BuildLocation" and part.Size == item.BuildLocation.Size then
      if #part:GetChildren() == 0 then
        if nearest == nil then
          nearest = part
        end
        if (part.Position - torso.Position).magnitude < (nearest.Position - torso.Position).magnitude then
          nearest = part
        end
      end
    end
  end
  return nearest
end

function giveDisplayItemTracking(player, item)
  --	print(player, interactionOptions, touchPart)
  if player.Character then
    local displayItem = player.Character:FindFirstChild("DisplayItem")
    if not displayItem then
      displayItem = script.DisplayItem:Clone()
      displayItem:FindFirstChildWhichIsA("Script").Disabled = false
      displayItem.Parent = player.Character
    end
    displayItem.Value = item
  end
end

function ret:TrackBuildLocationRange(player, itemValue)
  if itemValue.Value ~= nil and player.Character then
    local interactionOptions = {{}}
    interactionOptions[1] = {" to place ".. itemValue.Value.Name, 1}
    interactionOptions[2] = {" to cancel", 1}

    local humanoidRootPart = player.Character:WaitForChild("HumanoidRootPart")
    local buildLocations = {}
    local tycoon = tycoonModule:GetPlayerRole(player).Value -- returns the tycoon
    if tycoon then
      buildLocations = getBuildLocations(tycoon, itemValue.Value)
    end

    displayItemEvent:FireClient(player, buildLocations, player.Character.Torso.Position)

    local sepDistance = math.sqrt((tycoon.Floor.Size.X / 2)^2 + (tycoon.Floor.Size.Z / 2)^2)

    local lastBuildLocation = nil
    local closestBuildLocation = getNearestBuildLocation(player, itemValue.Value)
    while (closestBuildLocation.CFrame.p - humanoidRootPart.Position).magnitude < sepDistance do
      wait(.1)
      if itemValue.Value == nil then
        tycoonModule:SendPlayerTycoonGui(player, 1) -- player role. Since sending no list it will request current list
        break
      end
      interactionModule:GiveInteractionOptions(player, interactionOptions, closestBuildLocation)
      closestBuildLocation = getNearestBuildLocation(player, itemValue.Value)
      displayItemEvent:FireClient(player, nil, player.Character.Torso.Position) -- sends the buildlocations to the player

      --			if lastBuildLocation ~= closestBuildLocation then
      --				--local parameterizedModel = getBuildItemAtNearestLocation(player, buildLocations, itemValue.Value) -- gets the model at the new location
      --				displayItemEvent:FireClient(player, nil, player.Character.Torso.Position) -- sends the buildlocations to the player
      --				interactionModule:GiveInteractionOptions(player, interactionOptions, closestBuildLocation)
      --				print("Location changed")
      --			end
    end
    interactionModule:GiveInteractionOptions(player)
    if itemValue.Value ~= nil then
      messageEvent:FireClient(player, "warning", "Canceling placement. You are not close enough to a placement area")
    end

    local settings = {}
    settings["ShopGui.Details.Details.BorderSizePixel"] = 0
    settings["ShopGui.Details.LowerButtons.PlacementButton.Text"] = "Select"
    updateGuiEvent:FireClient(player, settings) -- Screen Gui, container(nil will adjust default gui), visiblity

    displayItemEvent:FireClient(player)
    itemValue.Value = nil
  end
end

function ret:ProcessClientDisplayItem(player, itemName)
  if itemName then
    local item = serverStorage:FindFirstChild(itemName, true)
    if item then
      item = item:FindFirstChildWhichIsA("Model")
      local buildLocations = {}
      local role = tycoonModule:GetPlayerRole(player)
      if role.Name == "OwnerOf" then
        local validTransaction = componentModule:ExtractComponentFromPlayer(player, itemName)
        if validTransaction then
          buildLocations = getBuildLocations(role.Value, item)
          messageEvent:FireClient(player, "success", "Ready to place "..string.lower(itemName).. ", get near a placement location in your shop")
          displayItemEvent:FireClient(player, buildLocations, player.Character.Torso.Position)
          giveDisplayItemTracking(player, item)
        else
          messageEvent:FireClient(player, "failure", "Looks like you don't have any ".. string.lower(itemName).. "'s to place")
        end
      end
    end
  else
    displayItemEvent:FireClient(player)
    giveDisplayItemTracking(player)
  end
end

return ret
