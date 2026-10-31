local startupActive=true
local startupSlice=os.clock()
local function startupYield()
 if not startupActive or os.clock()-startupSlice<0.004 then return end
 if coroutine.isyieldable and not coroutine.isyieldable() then return end
 task.wait()
 startupSlice=os.clock()
end
local function finishStartup() startupActive=false end
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local CoreGui = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
local gethui = gethui or function() return CoreGui end
local LocalPlayer = Players.LocalPlayer
local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local isMobileDevice = UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or viewportSize.X <= 900)
local library = {
  flags = {},
  connections = {},
  currentPopup = nil,
  keybindEntries = {},
  keybindGui = nil,
  notificationGui = nil,
  notificationAnchor = nil,
  notificationStack = nil,
  notificationEntries = {},
  notificationCounter = 0,
  options = {},
  configFolder = "Violet/Configs",
  autoloadPath = "Violet/autoload.txt",
  lastSavedConfig = {},
  accent = Color3.fromRGB(0, 174, 255),
  visible = true,
}
local theme = {
  background = Color3.fromRGB(12, 12, 15),
  backgroundTop = Color3.fromRGB(15, 15, 19),
  tabBar = Color3.fromRGB(13, 13, 16),
  section = Color3.fromRGB(17, 17, 21),
  sectionHeader = Color3.fromRGB(20, 20, 25),
  control = Color3.fromRGB(27, 28, 33),
  controlTop = Color3.fromRGB(34, 35, 41),
  controlBottom = Color3.fromRGB(22, 23, 28),
  controlHover = Color3.fromRGB(32, 33, 39),
  controlPressed = Color3.fromRGB(18, 19, 23),
  outline = Color3.fromRGB(46, 47, 55),
  outlineDark = Color3.fromRGB(5, 5, 7),
  outlineSoft = Color3.fromRGB(37, 38, 45),
  text = Color3.fromRGB(241, 241, 244),
  textMuted = Color3.fromRGB(145, 146, 156),
  textDark = Color3.fromRGB(88, 89, 99),
  disabled = Color3.fromRGB(58, 59, 66),
  risky = Color3.fromRGB(255, 84, 94),
  white = Color3.fromRGB(255, 255, 255),
  black = Color3.fromRGB(0, 0, 0),
}
local KEYBIND_MODES = {"Always", "Hold", "Toggle"}
local activeTweens = setmetatable({}, {__mode = "k"})

local function create(className, properties)
 startupYield()
  local object = Instance.new(className)
  if properties then
    for property, value in pairs(properties) do
      object[property] = value
    end
  end
  return object
end

local function corner(parent, radius)
  return create("UICorner", {
    Parent = parent,
    CornerRadius = UDim.new(0, radius or 5),
  })
end

local function stroke(parent, color, transparency, thickness)
  return create("UIStroke", {
    Parent = parent,
    Color = color or theme.outline,
    Transparency = transparency or 0,
    Thickness = thickness or 1,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
  })
end

local function padding(parent, left, right, top, bottom)
  return create("UIPadding", {
    Parent = parent,
    PaddingLeft = UDim.new(0, left or 0),
    PaddingRight = UDim.new(0, right or 0),
    PaddingTop = UDim.new(0, top or 0),
    PaddingBottom = UDim.new(0, bottom or 0),
  })
end

local function tween(object, properties, duration, style, direction)
  if not object or not object.Parent or type(properties) ~= "table" then
    return nil
  end
  local previous = activeTweens[object]
  if previous and type(previous) == "userdata" then
    pcall(function()
      previous:Cancel()
    end)
  end
  local ok, animation = pcall(function()
    return TweenService:Create(
      object,
      TweenInfo.new(
        duration or 0.12,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
      ),
      properties
    )
  end)
  if not ok or typeof(animation) ~= "Instance" or not animation:IsA("Tween") then
    for property, value in pairs(properties) do
      pcall(function()
        object[property] = value
      end)
    end
    activeTweens[object] = nil
    return nil
  end
  activeTweens[object] = animation
  animation.Completed:Connect(function()
    if activeTweens[object] == animation then
      activeTweens[object] = nil
    end
  end)
  animation:Play()
  return animation
end

local function fire(callback, ...)
  if type(callback) ~= "function" then
    return
  end
  local arguments = table.pack(...)
  task.spawn(function()
    pcall(callback, table.unpack(arguments, 1, arguments.n))
  end)
end

local function connect(signal, callback)
  local connection = signal:Connect(callback)
  local connections = library.connections
  connections[#connections + 1] = connection
  return connection
end

local function lighten(color, amount)
  return color:Lerp(theme.white, math.clamp(amount or 0, 0, 1))
end

local function darken(color, amount)
  return color:Lerp(theme.black, math.clamp(amount or 0, 0, 1))
end

local function parseHexColor(text)
  local hex = tostring(text or ""):gsub("#", ""):gsub("%s+", "")
  if #hex == 3 then
    hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
  end
  if #hex ~= 6 or not hex:match("^[%da-fA-F]+$") then
    return nil
  end
  return Color3.fromRGB(
    tonumber(hex:sub(1, 2), 16),
    tonumber(hex:sub(3, 4), 16),
    tonumber(hex:sub(5, 6), 16)
  )
end

local function colorRGBText(color)
  return string.format(
    "rgb(%d, %d, %d)",
    math.floor(color.R * 255 + 0.5),
    math.floor(color.G * 255 + 0.5),
    math.floor(color.B * 255 + 0.5)
  )
end

local function parseRGBColor(text)
  local values = {}
  for value in tostring(text or ""):gmatch("%d+") do
    values[#values + 1] = tonumber(value)
  end
  if #values ~= 3 then
    return nil
  end
  for index = 1, 3 do
    if values[index] < 0 or values[index] > 255 then
      return nil
    end
  end
  return Color3.fromRGB(values[1], values[2], values[3])
end

local function accentSequence(color)
  return ColorSequence.new({
    ColorSequenceKeypoint.new(0, lighten(color, 0.34)),
    ColorSequenceKeypoint.new(0.48, lighten(color, 0.08)),
    ColorSequenceKeypoint.new(1, darken(color, 0.24)),
  })
end

local function darkButtonSequence()
  return ColorSequence.new({
    ColorSequenceKeypoint.new(0, theme.controlTop),
    ColorSequenceKeypoint.new(0.52, theme.control),
    ColorSequenceKeypoint.new(1, theme.controlBottom),
  })
end

local function subtleControlSequence()
  return ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 35, 41)),
    ColorSequenceKeypoint.new(0.52, Color3.fromRGB(31, 32, 38)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 29, 34)),
  })
end

local function subtleAccentSequence(color)
  return ColorSequence.new({
    ColorSequenceKeypoint.new(0, lighten(color, 0.18)),
    ColorSequenceKeypoint.new(0.52, lighten(color, 0.05)),
    ColorSequenceKeypoint.new(1, darken(color, 0.10)),
  })
end

local function guiParent()
  local parent = CoreGui
  if type(gethui) == "function" then
    local success, result = pcall(gethui)
    if success and result then
      parent = result
    end
  end
  return parent
end

local function setGuiParent(screenGui)
  screenGui.Parent = guiParent()
end

local function normalizeKey(input)
  if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
    return input.KeyCode
  end
  if input.UserInputType == Enum.UserInputType.MouseButton1 then
    return Enum.UserInputType.MouseButton1
  elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
    return Enum.UserInputType.MouseButton2
  elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
    return Enum.UserInputType.MouseButton3
  end
  return nil
end
local keyNames = {
  [Enum.KeyCode.Insert] = "INSERT",
  [Enum.KeyCode.LeftShift] = "LSHIFT",
  [Enum.KeyCode.RightShift] = "RSHIFT",
  [Enum.KeyCode.LeftControl] = "LCTRL",
  [Enum.KeyCode.RightControl] = "RCTRL",
  [Enum.KeyCode.LeftAlt] = "LALT",
  [Enum.KeyCode.RightAlt] = "RALT",
  [Enum.KeyCode.Return] = "ENTER",
  [Enum.KeyCode.Backspace] = "BACKSPACE",
  [Enum.KeyCode.Space] = "SPACE",
  [Enum.KeyCode.CapsLock] = "CAPS",
  [Enum.UserInputType.MouseButton1] = "MB1",
  [Enum.UserInputType.MouseButton2] = "MB2",
  [Enum.UserInputType.MouseButton3] = "MB3",
}

local function coerceKey(key)
  if key == nil then
    return nil
  end
  local kind = typeof(key)
  if kind == "EnumItem" then
    local enumType = key.EnumType
    if enumType == Enum.KeyCode or enumType == Enum.UserInputType then
      return key
    end
    return nil
  end
  if kind == "table" then
    return coerceKey(key.Key or key.key or key.Value or key.value or key.Name or key.name or key[1])
  end
  local text = tostring(key):gsub("^%s+", ""):gsub("%s+$", "")
  text = text:gsub("^Enum%.KeyCode%.", ""):gsub("^Enum%.UserInputType%.", "")
  if text == "" then
    return nil
  end
  local upper = string.upper(text)
  if upper == "NONE" or upper == "NIL" then
    return nil
  elseif upper == "MB1" or upper == "MOUSEBUTTON1" then
    return Enum.UserInputType.MouseButton1
  elseif upper == "MB2" or upper == "MOUSEBUTTON2" then
    return Enum.UserInputType.MouseButton2
  elseif upper == "MB3" or upper == "MOUSEBUTTON3" then
    return Enum.UserInputType.MouseButton3
  end
  local keyCodeItems = Enum.KeyCode:GetEnumItems()
  for index = 1, #keyCodeItems do
    local item = keyCodeItems[index]
    if string.upper(item.Name) == upper then
      return item
    end
  end
  local inputItems = Enum.UserInputType:GetEnumItems()
  for index = 1, #inputItems do
    local item = inputItems[index]
    if string.upper(item.Name) == upper then
      return item
    end
  end
  return nil
end

local function keyName(key)
  key = coerceKey(key)
  if not key then
    return "NONE"
  end
  if keyNames[key] then
    return keyNames[key]
  end
  return string.upper(tostring(key):gsub("Enum%.KeyCode%.", ""):gsub("Enum%.UserInputType%.", ""))
end

local function normalizeBindMode(mode)
  local value = string.lower(tostring(mode or "Toggle"))
  if value == "always" or value == "always on" then
    return "Always"
  elseif value == "hold" then
    return "Hold"
  end
  return "Toggle"
end

local function keybindWidth(text, textSize, minimum, maximum)
  local value = tostring(text or "NONE")
  local bounds = TextService:GetTextSize(
    value,
    textSize or 11,
    Enum.Font.ArialBold,
    Vector2.new(240, 24)
  )
  return math.clamp(math.ceil(bounds.X) + 14, minimum or 24, maximum or 100)
end

local function pointInside(position, object)
  if not object or not object.Parent or not object.Visible then
    return false
  end
  local topLeft = object.AbsolutePosition
  local size = object.AbsoluteSize
  return position.X >= topLeft.X
    and position.X <= topLeft.X + size.X
    and position.Y >= topLeft.Y
    and position.Y <= topLeft.Y + size.Y
end

local function popupPosition(anchor, width, height, gap)
  local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
  local inset = GuiService:GetGuiInset()
  local anchorPosition = anchor.AbsolutePosition
  local anchorSize = anchor.AbsoluteSize
  local margin = 7
  local x = anchorPosition.X + anchorSize.X - width
  local y = anchorPosition.Y + anchorSize.Y + (gap or 5)
  if x + width > viewport.X - margin then
    x = viewport.X - width - margin
  end
  if x < margin then
    x = margin
  end
  if y + height > viewport.Y - margin then
    y = anchorPosition.Y - height - (gap or 5)
  end
  y = math.clamp(y, margin + inset.Y, math.max(margin + inset.Y, viewport.Y - height - margin))
  return UDim2.fromOffset(x, y)
end

local function createRainbowController(section, anchor, baseFlag, setColor)
  local enabled = false
  local speed = 1
  local suppressActivationUntil = 0
  local touchHoldSerial = 0
  local activeTouch = nil
  local touchStartPosition = nil
  local rainbowFlag = baseFlag and (baseFlag .. "_rainbow") or nil
  local speedFlag = baseFlag and (baseFlag .. "_rainbow_speed") or nil

  local function setEnabled(value)
    enabled = value == true
    if rainbowFlag then
      section.library.flags[rainbowFlag] = enabled
    end
  end

  local function setSpeed(value)
    speed = math.clamp(tonumber(value) or 1, 0.1, 5)
    if speedFlag then
      section.library.flags[speedFlag] = speed
    end
  end
  setEnabled(false)
  setSpeed(1)
  local lastRainbowUpdate = 0
  connect(RunService.RenderStepped, function()
    local now = os.clock()
    if enabled and anchor.Parent and now - lastRainbowUpdate >= 1 / 30 then
      lastRainbowUpdate = now
      setColor(Color3.fromHSV((now * speed * 0.15) % 1, 1, 1), true)
    end
  end)

  local function openMenu()
    section.library:ClosePopup()
    local popupWidth = isMobileDevice and 220 or 184
    local collapsedHeight = isMobileDevice and 46 or 36
    local expandedHeight = isMobileDevice and 108 or 90
    local rowHeight = isMobileDevice and 36 or 26
    local expanded = false
    local popupFrame = create("CanvasGroup", {
      Parent = section.window.Gui,
      Name = "RainbowColorMenu",
      Position = popupPosition(anchor, popupWidth, collapsedHeight, 5),
      Size = UDim2.fromOffset(popupWidth, collapsedHeight),
      BackgroundColor3 = Color3.fromRGB(28, 29, 35),
      BorderSizePixel = 0,
      GroupTransparency = 1,
      ZIndex = 820,
    })
    corner(popupFrame, 4)
    stroke(popupFrame, theme.outline, 0, 1)
    local popupScale = create("UIScale", {
      Parent = popupFrame,
      Scale = 0.97,
    })
    local rainbowRow = create("TextButton", {
      Parent = popupFrame,
      Position = UDim2.fromOffset(5, 5),
      Size = UDim2.new(1, -10, 0, rowHeight),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = "",
      AutoButtonColor = false,
      ZIndex = 822,
    })
    create("TextLabel", {
      Parent = rainbowRow,
      Position = UDim2.fromOffset(27, 0),
      Size = UDim2.new(1, -54, 1, 0),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = "Rainbow",
      TextColor3 = theme.text,
      TextSize = 12,
      Font = Enum.Font.ArialBold,
      TextXAlignment = Enum.TextXAlignment.Right,
      ZIndex = 823,
    })
    local toggleBox = create("Frame", {
      Parent = rainbowRow,
      AnchorPoint = Vector2.new(0, 0.5),
      Position = UDim2.new(0, 3, 0.5, 0),
      Size = UDim2.fromOffset(isMobileDevice and 20 or 17, isMobileDevice and 20 or 17),
      BackgroundColor3 = theme.control,
      BorderSizePixel = 0,
      ZIndex = 823,
    })
    corner(toggleBox, 2)
    local toggleStroke = stroke(toggleBox, theme.outline, 0, 1)
    local checkmark = create("ImageLabel", {
      Parent = toggleBox,
      AnchorPoint = Vector2.new(0.5, 0.5),
      Position = UDim2.fromScale(0.5, 0.5),
      Size = UDim2.fromOffset(14, 14),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Image = "rbxassetid://86817768619372",
      ImageColor3 = theme.black,
      ZIndex = 824,
    })
    local settingsButton = create("ImageButton", {
      Parent = rainbowRow,
      AnchorPoint = Vector2.new(1, 0.5),
      Position = UDim2.new(1, -2, 0.5, 0),
      Size = UDim2.fromOffset(isMobileDevice and 30 or 19, isMobileDevice and 30 or 19),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Image = "rbxassetid://106205298246017",
      ImageColor3 = theme.textMuted,
      ZIndex = 825,
    })
    local settings = create("Frame", {
      Parent = popupFrame,
      Position = UDim2.fromOffset(8, collapsedHeight),
      Size = UDim2.new(1, -16, 0, isMobileDevice and 56 or 48),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Visible = false,
      ZIndex = 822,
    })
    local speedLabel = create("TextLabel", {
      Parent = settings,
      Size = UDim2.new(1, 0, 0, 18),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      TextColor3 = theme.textMuted,
      TextSize = 11,
      Font = Enum.Font.ArialBold,
      TextXAlignment = Enum.TextXAlignment.Left,
      ZIndex = 823,
    })
    local speedInput = create("TextButton", {
      Parent = settings,
      Position = UDim2.fromOffset(0, isMobileDevice and 24 or 23),
      Size = UDim2.new(1, 0, 0, isMobileDevice and 26 or 18),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = "",
      AutoButtonColor = false,
      ZIndex = 824,
    })
    local speedTrack = create("Frame", {
      Parent = speedInput,
      AnchorPoint = Vector2.new(0, 0.5),
      Position = UDim2.fromScale(0, 0.5),
      Size = UDim2.new(1, 0, 0, 8),
      BackgroundColor3 = theme.controlBottom,
      BorderSizePixel = 0,
      ZIndex = 824,
    })
    corner(speedTrack, 999)
    local speedFill = create("Frame", {
      Parent = speedTrack,
      Size = UDim2.fromScale(0, 1),
      BackgroundColor3 = section.library.accent,
      BorderSizePixel = 0,
      ZIndex = 825,
    })
    corner(speedFill, 999)

    local function refresh()
      toggleBox.BackgroundColor3 = enabled and section.library.accent or theme.control
      toggleStroke.Color = enabled and darken(section.library.accent, 0.34) or theme.outline
      checkmark.ImageTransparency = enabled and 0 or 1
      speedLabel.Text = string.format("Speed  %.1fx", speed)
      speedFill.Size = UDim2.fromScale((speed - 0.1) / 4.9, 1)
    end
    local dragging = false
    local activeInput
    local lastSettingsClick = 0

    local function updateSpeed(input)
      local ratio = math.clamp((input.Position.X - speedTrack.AbsolutePosition.X) / math.max(speedTrack.AbsoluteSize.X, 1), 0, 1)
      setSpeed(math.floor((0.1 + ratio * 4.9) * 10 + 0.5) / 10)
      refresh()
    end
    rainbowRow.Activated:Connect(function()
      if os.clock() - lastSettingsClick < 0.12 then
        return
      end
      setEnabled(not enabled)
      refresh()
    end)
    settingsButton.Activated:Connect(function()
      lastSettingsClick = os.clock()
      expanded = not expanded
      settings.Visible = expanded
      settingsButton.Rotation = expanded and 90 or 0
      local height = expanded and expandedHeight or collapsedHeight
      popupFrame.Size = UDim2.fromOffset(popupWidth, height)
      popupFrame.Position = popupPosition(anchor, popupWidth, height, 5)
    end)
    speedInput.InputBegan:Connect(function(input)
      if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
      dragging = true
      activeInput = input
      updateSpeed(input)
    end)
    local moveConnection = UserInputService.InputChanged:Connect(function(input)
      if not dragging then return end
      if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
      if activeInput and activeInput.UserInputType == Enum.UserInputType.Touch and input ~= activeInput then return end
      updateSpeed(input)
    end)
    local endConnection = UserInputService.InputEnded:Connect(function(input)
      if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
        activeInput = nil
      end
    end)
    local popup = {Frame = popupFrame, Anchor = anchor}
    function popup:Close()
      moveConnection:Disconnect()
      endConnection:Disconnect()
      if popupFrame.Parent then
        tween(popupFrame, {GroupTransparency = 1}, 0.10, Enum.EasingStyle.Quad)
        tween(popupScale, {Scale = 0.97}, 0.10, Enum.EasingStyle.Quad)
        task.delay(0.105, function()
          if popupFrame.Parent then popupFrame:Destroy() end
        end)
      end
    end
    section.library.currentPopup = popup
    refresh()
    tween(popupFrame, {GroupTransparency = 0}, 0.14, Enum.EasingStyle.Quad)
    tween(popupScale, {Scale = 1}, 0.16, Enum.EasingStyle.Back)
  end
  anchor.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
      openMenu()
    elseif input.UserInputType == Enum.UserInputType.Touch then
      touchHoldSerial = touchHoldSerial + 1
      local serial = touchHoldSerial
      activeTouch = input
      touchStartPosition = input.Position
      task.delay(0.42, function()
        if serial ~= touchHoldSerial or activeTouch ~= input or not anchor.Parent then
          return
        end
        suppressActivationUntil = os.clock() + 0.6
        openMenu()
      end)
    end
  end)
  anchor.InputChanged:Connect(function(input)
    if input ~= activeTouch or input.UserInputType ~= Enum.UserInputType.Touch or not touchStartPosition then
      return
    end
    if (input.Position - touchStartPosition).Magnitude > 12 then
      touchHoldSerial = touchHoldSerial + 1
      activeTouch = nil
      touchStartPosition = nil
    end
  end)
  anchor.InputEnded:Connect(function(input)
    if input == activeTouch then
      touchHoldSerial = touchHoldSerial + 1
      activeTouch = nil
      touchStartPosition = nil
    end
  end)
  if rainbowFlag then
    section.library:RegisterOption(rainbowFlag, {Get = function() return enabled end, Set = function(_, value) setEnabled(value) end})
  end
  if speedFlag then
    section.library:RegisterOption(speedFlag, {Get = function() return speed end, Set = function(_, value) setSpeed(value) end})
  end
  return {
    SetEnabled = setEnabled,
    GetEnabled = function() return enabled end,
    ConsumeActivation = function()
      if os.clock() <= suppressActivationUntil then
        suppressActivationUntil = 0
        return true
      end
      return false
    end,
  }
end

function library:ClosePopup()
  local popup = self.currentPopup
  if not popup then
    return
  end
  self.currentPopup = nil
  if popup.Close then
    popup:Close()
  elseif popup.Frame and popup.Frame.Parent then
    popup.Frame:Destroy()
  end
end

function library:ForceRefreshAccent()
  if type(self.window) == "table" and type(self.window.RefreshAccent) == "function" then
    self.window:RefreshAccent()
  end
end

function library:SetAccent(color)
  if typeof(color) ~= "Color3" then
    return
  end
  self.accent = color
  if self._accentRefreshQueued then
    return
  end
  self._accentRefreshQueued = true
  local now = os.clock()
  local waitTime = math.max(0, 0.045 - (now - (self._accentLastRefresh or 0)))
  task.delay(waitTime, function()
    self._accentRefreshQueued = false
    self._accentLastRefresh = os.clock()
    self:ForceRefreshAccent()
  end)
end

local function ensureFolder(path)
  if type(makefolder) ~= "function" then
    return false
  end
  if type(isfolder) == "function" then
    local ok, exists = pcall(isfolder, path)
    if ok and exists then
      return true
    end
  end
  return pcall(makefolder, path)
end

local function sanitizeConfigName(name)
  name = tostring(name or ""):gsub("[^%w%-%_ ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    return nil
  end
  return name:sub(1, 48)
end

local function encodeConfigValue(value)
  local valueType = typeof(value)
  if valueType == "Color3" then
    return {__type = "Color3", value = value:ToHex()}
  elseif valueType == "EnumItem" then
    return {
      __type = "EnumItem",
      enum = tostring(value.EnumType):gsub("Enum%.", ""),
      name = value.Name,
    }
  elseif valueType == "table" then
    local result = {}
    for key, item in pairs(value) do
      result[key] = encodeConfigValue(item)
    end
    return result
  end
  return value
end

local function decodeConfigValue(value)
  if typeof(value) ~= "table" then
    return value
  end
  if value.__type == "Color3" and type(value.value) == "string" then
    local ok, color = pcall(Color3.fromHex, value.value)
    return ok and color or Color3.new(1, 1, 1)
  elseif value.__type == "EnumItem" and type(value.enum) == "string" and type(value.name) == "string" then
    local enumType = Enum[value.enum]
    return enumType and enumType[value.name] or nil
  end
  local result = {}
  for key, item in pairs(value) do
    result[key] = decodeConfigValue(item)
  end
  return result
end

function library:RegisterOption(flag, control)
  if flag and type(control) == "table" then
    self.options[flag] = control
  end
  return control
end

function library:_EnsureConfigFolders()
  ensureFolder("Violet")
  return ensureFolder(self.configFolder)
end

function library:ListConfigs()
  local names = {}
  if type(listfiles) ~= "function" then
    return names
  end
  self:_EnsureConfigFolders()
  local ok, files = pcall(listfiles, self.configFolder)
  if not ok or typeof(files) ~= "table" then
    return names
  end
  for index = 1, #files do
    local filePath = files[index]
    local name = tostring(filePath):match("([^/\\]+)%.json$")
    if name then
      names[#names + 1] = name
    end
  end
  table.sort(names, function(a, b)
    return string.lower(a) < string.lower(b)
  end)
  return names
end

function library:SaveConfig(name, silent)
  name = sanitizeConfigName(name)
  if not name then
    if not silent then self:Notify({Title = "Config", Text = "Enter a profile name first.", Type = "Error"}) end
    return false
  end
  if type(writefile) ~= "function" then
    if not silent then self:Notify({Title = "Config", Text = "File saving is not supported here.", Type = "Error"}) end
    return false
  end
  self:_EnsureConfigFolders()
  local values = {}
  local excluded = {
    profile_name = true,
    selected_profile = true,
    auto_load = true,
    auto_save = true,
  }
  for flag, control in pairs(self.options) do
    if not excluded[flag] and type(control.Get) == "function" then
      local ok, value = pcall(control.Get, control)
      if ok then
        values[flag] = encodeConfigValue(value)
      end
    end
  end
  local payload = {
    version = 2,
    name = name,
    values = values,
  }
  local okEncode, json = pcall(HttpService.JSONEncode, HttpService, payload)
  if not okEncode then
    if not silent then self:Notify({Title = "Config", Text = "Failed to encode the profile.", Type = "Error"}) end
    return false
  end
  if self.lastSavedConfig[name] == json then
    return true
  end
  local path = self.configFolder .. "/" .. name .. ".json"
  local okWrite = pcall(writefile, path, json)
  if okWrite then
    self.lastSavedConfig[name] = json
    if not silent then self:Notify({Title = "Config", Text = "Saved " .. name .. ".", Type = "Success"}) end
  elseif not silent then
    self:Notify({Title = "Config", Text = "Failed to save " .. name .. ".", Type = "Error"})
  end
  return okWrite
end

function library:LoadConfig(name, silent)
  name = sanitizeConfigName(name)
  if not name or type(readfile) ~= "function" or type(isfile) ~= "function" then
    if not silent then self:Notify({Title = "Config", Text = "That profile could not be loaded.", Type = "Error"}) end
    return false
  end
  local path = self.configFolder .. "/" .. name .. ".json"
  local okExists, exists = pcall(isfile, path)
  if not okExists or not exists then
    if not silent then self:Notify({Title = "Config", Text = name .. " does not exist.", Type = "Error"}) end
    return false
  end
  local okRead, raw = pcall(readfile, path)
  if not okRead then
    if not silent then self:Notify({Title = "Config", Text = "Failed to read " .. name .. ".", Type = "Error"}) end
    return false
  end
  local okDecode, payload = pcall(HttpService.JSONDecode, HttpService, raw)
  if not okDecode or typeof(payload) ~= "table" then
    if not silent then self:Notify({Title = "Config", Text = name .. " is invalid.", Type = "Error"}) end
    return false
  end
  local values = payload.values or payload
  local decodedValues = {}
  for flag, encodedValue in pairs(values) do
    decodedValues[flag] = decodeConfigValue(encodedValue)
  end
  local loadedAccent = decodedValues.accent_color
  local loadedHeaderLeft = decodedValues.header_gradient_left
  local loadedHeaderRight = decodedValues.header_gradient_right
  if typeof(loadedAccent) == "Color3" then
    self:SetAccent(loadedAccent)
  end
  if type(self.window) == "table" and type(self.window.SetHeaderGradient) == "function" then
    self.window:SetHeaderGradient(
      typeof(loadedHeaderLeft) == "Color3" and loadedHeaderLeft or nil,
      typeof(loadedHeaderRight) == "Color3" and loadedHeaderRight or nil
    )
  end
  local priorityFlags = {
    "accent_color",
    "header_gradient_left",
    "header_gradient_right",
    "ui_scale",
  }
  local applied = {}

  local function applyFlag(flag)
    if applied[flag] or decodedValues[flag] == nil then
      return
    end
    applied[flag] = true
    local value = decodedValues[flag]
    local control = self.options[flag]
    if control and type(control.Set) == "function" then
      pcall(control.Set, control, value)
    else
      self.flags[flag] = value
    end
  end
  for index = 1, #priorityFlags do
    applyFlag(priorityFlags[index])
  end
  for flag in pairs(decodedValues) do
    applyFlag(flag)
  end
  if typeof(loadedAccent) == "Color3" then
    self:SetAccent(loadedAccent)
    task.delay(0.28, function()
      if self.accent == loadedAccent then
        self:SetAccent(loadedAccent)
      end
    end)
  end
  if type(self.window) == "table" and type(self.window.SetHeaderGradient) == "function" then
    self.window:SetHeaderGradient(
      typeof(loadedHeaderLeft) == "Color3" and loadedHeaderLeft or nil,
      typeof(loadedHeaderRight) == "Color3" and loadedHeaderRight or nil
    )
  end
  local function refreshLoadedKeybinds()
    for _, control in pairs(self.options) do
      if control and type(control.RefreshKeybindWidth) == "function" then
        pcall(control.RefreshKeybindWidth, control)
      end
    end
    if type(self.window) == "table" and type(self.window.RefreshKeybindList) == "function" then
      self.window:RefreshKeybindList()
    end
  end
  task.defer(refreshLoadedKeybinds)
  task.delay(0.08, refreshLoadedKeybinds)
  task.delay(0.22, refreshLoadedKeybinds)
  self.lastSavedConfig[name] = raw
  if not silent then self:Notify({Title = "Config", Text = "Loaded " .. name .. ".", Type = "Success"}) end
  return true
end

function library:DeleteConfig(name)
  name = sanitizeConfigName(name)
  if not name or type(delfile) ~= "function" or type(isfile) ~= "function" then
    self:Notify({Title = "Config", Text = "That profile could not be deleted.", Type = "Error"})
    return false
  end
  local path = self.configFolder .. "/" .. name .. ".json"
  local okExists, exists = pcall(isfile, path)
  if not okExists or not exists then
    self:Notify({Title = "Config", Text = name .. " does not exist.", Type = "Error"})
    return false
  end
  local okDelete = pcall(delfile, path)
  if okDelete then
    self.lastSavedConfig[name] = nil
    if self:GetAutoload() == name then
      self:SetAutoload(nil)
    end
    self:Notify({Title = "Config", Text = "Deleted " .. name .. ".", Type = "Success"})
  else
    self:Notify({Title = "Config", Text = "Failed to delete " .. name .. ".", Type = "Error"})
  end
  return okDelete
end

function library:SetAutoload(name)
  if type(writefile) ~= "function" then
    return false
  end
  self:_EnsureConfigFolders()
  name = sanitizeConfigName(name)
  if not name then
    if type(delfile) == "function" and type(isfile) == "function" then
      local okExists, exists = pcall(isfile, self.autoloadPath)
      if okExists and exists then pcall(delfile, self.autoloadPath) end
    end
    return true
  end
  return pcall(writefile, self.autoloadPath, name)
end

function library:GetAutoload()
  if type(readfile) ~= "function" or type(isfile) ~= "function" then
    return nil
  end
  local okExists, exists = pcall(isfile, self.autoloadPath)
  if not okExists or not exists then
    return nil
  end
  local okRead, name = pcall(readfile, self.autoloadPath)
  return okRead and sanitizeConfigName(name) or nil
end

function library:Notify(data)
  data = typeof(data) == "table" and data or {Text = tostring(data or "Notification")}
  if self.flags.notifications == false then
    return nil
  end
  local stack = self.notificationStack
  if not stack or not stack.Parent then
    return nil
  end
  local duration = tonumber(data.Duration or data.duration or self.flags.notification_duration) or 4
  duration = math.clamp(duration, 1, 15)
  local titleText = tostring(data.Title or data.title or "violet.lol")
  local bodyText = tostring(data.Text or data.text or data.Message or data.message or "Notification")
  local typeName = string.lower(tostring(data.Type or data.type or "Info"))
  local lineColor = self.accent
  if typeName == "error" then
    lineColor = theme.risky
  elseif typeName == "success" then
    lineColor = Color3.fromRGB(105, 220, 140)
  end
  self.notificationCounter = self.notificationCounter + 1
  local order = self.notificationCounter
  local height = isMobileDevice and 58 or 50
  local card = create("CanvasGroup", {
    Parent = stack,
    Name = "Notification_" .. order,
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = theme.section,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    ClipsDescendants = true,
    LayoutOrder = order,
    ZIndex = 22,
  })
  corner(card, 2)
  stroke(card, theme.outlineSoft, 0.46, 1)
  local formattedTitle = titleText
  if string.lower(titleText) == "violet.lol" then
    formattedTitle = string.format(
      'violet<font color="#%s">.lol</font>',
      self.accent:ToHex()
    )
  end
  create("TextLabel", {
    Parent = card,
    Position = UDim2.fromOffset(8, 5),
    Size = UDim2.new(1, -16, 0, 17),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    RichText = true,
    Text = formattedTitle,
    TextColor3 = theme.text,
    TextSize = isMobileDevice and 13 or 12,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 24,
  })
  create("TextLabel", {
    Parent = card,
    Position = UDim2.fromOffset(8, 22),
    Size = UDim2.new(1, -16, 1, -28),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = bodyText,
    TextColor3 = theme.textMuted,
    TextSize = isMobileDevice and 12 or 11,
    Font = Enum.Font.ArialBold,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 24,
  })
  local durationTrack = create("Frame", {
    Parent = card,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = theme.controlBottom,
    BackgroundTransparency = 0.20,
    BorderSizePixel = 0,
    ZIndex = 24,
  })
  local durationLine = create("Frame", {
    Parent = durationTrack,
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = lineColor,
    BorderSizePixel = 0,
    ZIndex = 25,
  })
  self.notificationEntries[card] = true
  tween(card, {Size = UDim2.new(1, 0, 0, height), GroupTransparency = 0}, 0.18, Enum.EasingStyle.Quad)
  tween(durationLine, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)
  task.delay(duration, function()
    if not card.Parent then return end
    tween(card, {Size = UDim2.new(1, 0, 0, 0), GroupTransparency = 1}, 0.16, Enum.EasingStyle.Quad)
    task.delay(0.17, function()
      self.notificationEntries[card] = nil
      if card.Parent then card:Destroy() end
    end)
  end)
  return card
end

function library:Unload()
  self:ClosePopup()
  local connections = self.connections
  for index = #connections, 1, -1 do
    local connection = connections[index]
    pcall(connection.Disconnect, connection)
  end
  table.clear(self.connections)
  if self.gui then
    self.gui:Destroy()
  end
  if self.keybindGui then
    self.keybindGui:Destroy()
  end
  if self.notificationGui then
    self.notificationGui:Destroy()
  end
  table.clear(self.keybindEntries)
  table.clear(self.notificationEntries)
  table.clear(self.options)
  self.gui = nil
  self.keybindGui = nil
  self.notificationGui = nil
  self.notificationAnchor = nil
  self.notificationStack = nil
  self.window = nil
end

function library:Window(options)
  options = options or {}
  local windowAccent = options.AccentColor or options.accentColor or options.Accent or options.accent
  if typeof(windowAccent) == "Color3" then
    self.accent = windowAccent
    self.flags.accent_color = windowAccent
  end
  self:Unload()
  local guiName = options.GuiName or "Violetss"
  local existing
  pcall(function()
    existing = guiParent():FindFirstChild(guiName)
  end)
  if existing then
    existing:Destroy()
  end
  local screenGui = create("ScreenGui", {
    Name = guiName,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 100000,
  })
  setGuiParent(screenGui)
  self.gui = screenGui
  local keybindGuiName = guiName .. "_Keybinds"
  local existingKeybindGui
  pcall(function()
    existingKeybindGui = guiParent():FindFirstChild(keybindGuiName)
  end)
  if existingKeybindGui then
    existingKeybindGui:Destroy()
  end
  local keybindScreenGui = create("ScreenGui", {
    Name = keybindGuiName,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 100001,
  })
  setGuiParent(keybindScreenGui)
  self.keybindGui = keybindScreenGui
  local notificationGuiName = guiName .. "_Notifications"
  local existingNotificationGui
  pcall(function()
    existingNotificationGui = guiParent():FindFirstChild(notificationGuiName)
  end)
  if existingNotificationGui then
    existingNotificationGui:Destroy()
  end
  local notificationScreenGui = create("ScreenGui", {
    Name = notificationGuiName,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 100002,
  })
  setGuiParent(notificationScreenGui)
  self.notificationGui = notificationScreenGui
  local notificationWidth = isMobileDevice and 218 or 238
  local notificationAnchor = create("TextButton", {
    Parent = notificationScreenGui,
    Name = "NotificationAnchor",
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(1, -(notificationWidth + 12), 0, isMobileDevice and 58 or 72),
    Size = UDim2.fromOffset(notificationWidth, isMobileDevice and 32 or 28),
    BackgroundColor3 = theme.sectionHeader,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "Notifications will appear here",
    TextColor3 = theme.textMuted,
    TextSize = isMobileDevice and 12 or 11,
    Font = Enum.Font.ArialBold,
    Active = true,
    ZIndex = 20,
  })
  corner(notificationAnchor, 2)
  stroke(notificationAnchor, theme.outlineSoft, 0.42, 1)
  local notificationAccentLine = nil
  local notificationStack = create("Frame", {
    Parent = notificationAnchor,
    Name = "NotificationStack",
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 0, 1, 5),
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(48, 50, 61),
    BorderSizePixel = 0,
    ClipsDescendants = false,
    ZIndex = 20,
  })
  create("UIListLayout", {
    Parent = notificationStack,
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 5),
  })
  self.notificationAnchor = notificationAnchor
  self.notificationStack = notificationStack
  local notificationDragging = false
  local notificationDragInput
  local notificationDragOffset

  local function syncNotificationStack()
    if not notificationAnchor.Parent or not notificationStack.Parent then return end
    notificationStack.AnchorPoint = Vector2.new(0, 0)
    notificationStack.Position = UDim2.new(0, 0, 1, 5)
    notificationStack.Size = UDim2.new(1, 0, 0, 0)
  end
  notificationAnchor.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    local pointer = Vector2.new(input.Position.X, input.Position.Y)
    local absolute = notificationAnchor.AbsolutePosition
    notificationDragging = true
    notificationDragInput = input
    notificationDragOffset = pointer - absolute
    notificationAnchor.AnchorPoint = Vector2.new(0, 0)
    notificationAnchor.Position = UDim2.fromOffset(absolute.X, absolute.Y)
  end)
  connect(UserInputService.InputChanged, function(input)
    if not notificationDragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if notificationDragInput and notificationDragInput.UserInputType == Enum.UserInputType.Touch and input ~= notificationDragInput then return end
    local pointer = Vector2.new(input.Position.X, input.Position.Y)
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local width = notificationAnchor.AbsoluteSize.X
    local height = notificationAnchor.AbsoluteSize.Y
    local offset = notificationDragOffset or Vector2.zero
    local x = math.clamp(pointer.X - offset.X, 4, math.max(4, viewport.X - width - 4))
    local y = math.clamp(pointer.Y - offset.Y, 4, math.max(4, viewport.Y - height - 4))
    notificationAnchor.Position = UDim2.fromOffset(x, y)
    syncNotificationStack()
  end)
  connect(UserInputService.InputEnded, function(input)
    if input == notificationDragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
      notificationDragging = false
      notificationDragInput = nil
      notificationDragOffset = nil
    end
  end)
  notificationAnchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncNotificationStack)
  notificationAnchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncNotificationStack)
  task.defer(syncNotificationStack)
  local keyboardIconId = "rbxassetid://121978468376124"
  local keybindListWidth = isMobileDevice and 184 or 198
  local keybindFrame = create("Frame", {
    Parent = keybindScreenGui,
    Name = "KeybindList",
    Position = UDim2.fromOffset(12, isMobileDevice and 58 or 72),
    Size = UDim2.fromOffset(keybindListWidth, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = Color3.fromRGB(10, 10, 13),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    Active = true,
    Visible = options.KeybindListVisible ~= false,
    ZIndex = 10,
  })
  corner(keybindFrame, 3)
  stroke(keybindFrame, theme.outlineSoft, 0.46, 1)
  create("UIListLayout", {
    Parent = keybindFrame,
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
  })
  local keybindHeader = create("TextButton", {
    Parent = keybindFrame,
    Name = "Header",
    Size = UDim2.new(1, 0, 0, isMobileDevice and 31 or 27),
    BackgroundColor3 = Color3.fromRGB(15, 15, 19),
    BackgroundTransparency = 0.10,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    Active = true,
    LayoutOrder = 1,
    ZIndex = 11,
  })
  local keybindIcon = create("ImageLabel", {
    Parent = keybindHeader,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 8, 0.5, 0),
    Size = UDim2.fromOffset(isMobileDevice and 15 or 13, isMobileDevice and 15 or 13),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = keyboardIconId,
    ImageColor3 = self.accent,
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 13,
  })
  local keybindTitle = create("TextLabel", {
    Parent = keybindHeader,
    Position = UDim2.fromOffset(isMobileDevice and 29 or 26, 0),
    Size = UDim2.new(1, -(isMobileDevice and 36 or 33), 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Keybind List (0)",
    TextColor3 = theme.text,
    TextSize = isMobileDevice and 13 or 11,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 12,
  })
  local keybindCount = create("TextLabel", {
    Parent = keybindHeader,
    Size = UDim2.fromOffset(0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "0",
    Visible = false,
    ZIndex = 12,
  })
  local keybindHeaderLine = create("Frame", {
    Parent = keybindHeader,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = theme.outlineSoft,
    BackgroundTransparency = 0.52,
    BorderSizePixel = 0,
    ZIndex = 12,
  })
  local keybindContent = create("Frame", {
    Parent = keybindFrame,
    Name = "Content",
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    LayoutOrder = 2,
    ZIndex = 11,
  })
  create("UIListLayout", {
    Parent = keybindContent,
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
  })
  padding(keybindContent, 7, 7, 4, 5)
  local popupLayer = create("Frame", {
    Parent = screenGui,
    Name = "PopupLayer",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = false,
    ZIndex = 1900,
  })
  local window = {
    library = self,
    tabs = {},
    accentCallbacks = {},
    activeTab = nil,
    menuKey = options.MenuKey or Enum.KeyCode.Insert,
    minimumSize = isMobileDevice and Vector2.new(300, 300) or Vector2.new(590, 430),
    maximumSize = Vector2.new(920, 720),
    mobileLayout = false,
  }
  local size = options.Size or UDim2.fromOffset(680, 525)
  local shadow = create("Frame", {
    Parent = screenGui,
    Name = "Shadow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = options.Position or UDim2.fromScale(0.5, 0.5),
    Size = size,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = true,
    ZIndex = 0,
  })
  create("ImageLabel", {
    Parent = shadow,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 34, 1, 34),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://18245826428",
    ImageColor3 = theme.black,
    ImageTransparency = 0.32,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(21, 21, 79, 79),
    ZIndex = 0,
  })
  local root = create("CanvasGroup", {
    Parent = screenGui,
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = options.Position or UDim2.fromScale(0.5, 0.5),
    Size = size,
    BackgroundColor3 = theme.background,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    ClipsDescendants = true,
    GroupTransparency = 0,
    ZIndex = 1,
  })
  local windowCornerRadius = 6
  corner(root, windowCornerRadius)
  stroke(root, theme.outlineSoft, 0.18, 1)
  local scale = create("UIScale", {
    Parent = root,
    Scale = 1,
  })
  local headerGradientLeft = options.HeaderGradientLeft or options.headerGradientLeft or options.LeftGradientHeader or options.leftGradientHeader or options.HeaderLeftColor or options.headerLeftColor or Color3.fromRGB(128, 183, 255)
  local headerGradientRight = options.HeaderGradientRight or options.headerGradientRight or options.RightGradientHeader or options.rightGradientHeader or options.HeaderRightColor or options.headerRightColor or Color3.fromRGB(136, 121, 254)
  local headerHeight = 36
  local header = create("TextButton", {
    Parent = root,
    Name = "Header",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 0, headerHeight),
    BackgroundColor3 = theme.white,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    Active = true,
    ClipsDescendants = true,
    ZIndex = 2,
  })
  corner(header, windowCornerRadius)
  local gradientStrip = header
  local headerGradient = create("UIGradient", {
    Parent = header,
    Rotation = 0,
    Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, headerGradientLeft),
      ColorSequenceKeypoint.new(1, headerGradientRight),
    }),
  })
  local headerBottomMask = create("Frame", {
    Parent = root,
    Name = "HeaderBottomMask",
    Position = UDim2.fromOffset(0, headerHeight - windowCornerRadius),
    Size = UDim2.new(1, 0, 0, windowCornerRadius),
    BackgroundColor3 = theme.white,
    BorderSizePixel = 0,
    ZIndex = 2,
  })
  local headerBottomGradient = create("UIGradient", {
    Parent = headerBottomMask,
    Rotation = 0,
    Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, headerGradientLeft),
      ColorSequenceKeypoint.new(1, headerGradientRight),
    }),
  })
  local starLayer = create("Frame", {
    Parent = header,
    Name = "Stars",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 3,
  })
  local starSpec = {
    {X = 0.20, Y = 10, Size = 18, Trans = 0.10, Rot = -12},
    {X = 0.24, Y = 26, Size = 22, Trans = 0.20, Rot = 94},
    {X = 0.28, Y = 9, Size = 17, Trans = 0.08, Rot = -82},
    {X = 0.33, Y = 21, Size = 21, Trans = 0.16, Rot = 8},
    {X = 0.38, Y = 9, Size = 18, Trans = 0.08, Rot = -78},
    {X = 0.43, Y = 26, Size = 24, Trans = 0.22, Rot = 93},
    {X = 0.48, Y = 11, Size = 18, Trans = 0.09, Rot = -82},
    {X = 0.53, Y = 24, Size = 23, Trans = 0.15, Rot = 98},
    {X = 0.58, Y = 9, Size = 18, Trans = 0.21, Rot = 91},
    {X = 0.63, Y = 25, Size = 22, Trans = 0.08, Rot = -85},
    {X = 0.68, Y = 10, Size = 19, Trans = 0.26, Rot = 2},
    {X = 0.73, Y = 26, Size = 24, Trans = 0.10, Rot = -84},
    {X = 0.78, Y = 11, Size = 19, Trans = 0.13, Rot = 92},
    {X = 0.83, Y = 25, Size = 22, Trans = 0.17, Rot = -82},
    {X = 0.88, Y = 9, Size = 18, Trans = 0.12, Rot = 4},
    {X = 0.93, Y = 24, Size = 23, Trans = 0.20, Rot = -86},
  }
  for index = 1, #starSpec do
    local data = starSpec[index]
    local star = create("ImageLabel", {
      Parent = starLayer,
      Name = "Star_" .. index,
      AnchorPoint = Vector2.new(0.5, 0.5),
      Position = UDim2.new(data.X, 0, 0, data.Y),
      Size = UDim2.fromOffset(data.Size, data.Size),
      Rotation = data.Rot or 0,
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Image = "rbxassetid://129958829729923",
      ImageColor3 = theme.white,
      ImageTransparency = data.Trans,
      ScaleType = Enum.ScaleType.Fit,
      ZIndex = 3,
    })
    task.spawn(function()
      local baseTransparency = data.Trans
      local dimTransparency = math.min(0.88, baseTransparency + 0.42)
      local duration = 0.7 + math.random() * 0.7
      task.wait(math.random() * 0.8)
      while star.Parent do
        local fadedSize = math.max(data.Size - 3, 11)
        local fadeOut = TweenService:Create(
          star,
          TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
          {
            ImageTransparency = dimTransparency,
            Size = UDim2.fromOffset(fadedSize, fadedSize),
            Rotation = (data.Rot or 0) + 8,
          }
        )
        fadeOut:Play()
        fadeOut.Completed:Wait()
        if not star.Parent then
          break
        end
        local fadeIn = TweenService:Create(
          star,
          TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
          {
            ImageTransparency = baseTransparency,
            Size = UDim2.fromOffset(data.Size, data.Size),
            Rotation = data.Rot or 0,
          }
        )
        fadeIn:Play()
        fadeIn.Completed:Wait()
      end
    end)
  end
  local title = create("Frame", {
    Parent = header,
    Position = UDim2.fromOffset(13, 0),
    Size = UDim2.new(0.27, -13, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 5,
  })
  create("UIListLayout", {
    Parent = title,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
  })
  local titlePrefix = create("TextLabel", {
    Parent = title,
    Size = UDim2.fromOffset(0, headerHeight),
    AutomaticSize = Enum.AutomaticSize.X,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = tostring(options.TitlePrefix or options.titlePrefix or "violet"),
    TextColor3 = theme.white,
    TextSize = 18,
    Font = Enum.Font.ArialBold,
    TextStrokeColor3 = theme.outlineDark,
    TextStrokeTransparency = 0.68,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    LayoutOrder = 1,
    ZIndex = 5,
  })
  local titleSuffix = create("TextLabel", {
    Parent = title,
    Size = UDim2.fromOffset(0, headerHeight),
    AutomaticSize = Enum.AutomaticSize.X,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = tostring(options.TitleSuffix or options.titleSuffix or ".lol"),
    TextColor3 = self.accent,
    TextSize = 18,
    Font = Enum.Font.ArialBold,
    TextStrokeColor3 = theme.outlineDark,
    TextStrokeTransparency = 0.68,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    LayoutOrder = 2,
    ZIndex = 5,
  })
  local mobileClose = create("TextButton", {
    Parent = header,
    Name = "MobileClose",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -5, 0.5, 0),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = theme.black,
    BackgroundTransparency = 0.82,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "×",
    TextColor3 = theme.white,
    TextSize = 18,
    Font = Enum.Font.ArialBold,
    Visible = isMobileDevice,
    ZIndex = 10,
  })
  corner(mobileClose, 4)
  local footerHeight = 54
  local bottomTabBarHeight = 0
  local bodyBackground = create("Frame", {
    Parent = root,
    Name = "BodyBackground",
    Position = UDim2.fromOffset(0, headerHeight - 1),
    Size = UDim2.new(1, 0, 1, -(headerHeight + footerHeight - 2)),
    BackgroundColor3 = theme.background,
    BorderSizePixel = 0,
    ZIndex = 0,
  })
  local tabBar = create("Frame", {
    Parent = root,
    Name = "TabBar",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(410, 46),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 5,
  })
  create("Frame", {
    Parent = tabBar,
    Name = "TabBarDivider",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 5,
  })
  local tabButtons = create("ScrollingFrame", {
    Parent = tabBar,
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.X,
    ScrollBarThickness = 0,
    ScrollingDirection = Enum.ScrollingDirection.X,
    ZIndex = 6,
  })
  create("UIListLayout", {
    Parent = tabButtons,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 8),
  })
  local pageHolder = create("Frame", {
    Parent = root,
    Name = "PageHolder",
    Position = UDim2.fromOffset(10, headerHeight + 4),
    Size = UDim2.new(1, -20, 1, -(headerHeight + footerHeight + 8)),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
  })
  local footer = create("Frame", {
    Parent = root,
    Name = "Footer",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, footerHeight),
    BackgroundColor3 = theme.backgroundTop,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    ZIndex = 2,
  })
  corner(footer, windowCornerRadius)
  create("Frame", {
    Parent = footer,
    Name = "FooterSquareTop",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 1, -windowCornerRadius),
    BackgroundColor3 = theme.backgroundTop,
    BorderSizePixel = 0,
    ZIndex = 2,
  })
  create("Frame", {
    Parent = footer,
    Name = "FooterDivider",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = theme.outlineSoft,
    BackgroundTransparency = 0.24,
    BorderSizePixel = 0,
    ZIndex = 3,
  })
  tabBar.Parent = footer
  tabBar.AnchorPoint = Vector2.new(0, 0.5)
  tabBar.Position = UDim2.new(0, 8, 0.5, 0)
  tabBar.Size = UDim2.fromOffset(420, 46)
  tabBar.BackgroundTransparency = 1
  tabBar.ZIndex = 5
  tabButtons.Position = UDim2.fromOffset(0, 0)
  tabButtons.Size = UDim2.new(1, 0, 1, 0)
  local footerAvatar = create("ImageLabel", {
    Parent = footer,
    Name = "LocalPlayerAvatar",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(24, 24),
    BackgroundColor3 = theme.control,
    BorderSizePixel = 0,
    Image = "",
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 5,
  })
  corner(footerAvatar, 999)
  stroke(footerAvatar, theme.outlineSoft, 0.34, 1)
  task.spawn(function()
    local success, image = pcall(function()
      return Players:GetUserThumbnailAsync(
        LocalPlayer.UserId,
        Enum.ThumbnailType.HeadShot,
        Enum.ThumbnailSize.Size48x48
      )
    end)
    if success and footerAvatar.Parent then
      footerAvatar.Image = image
    end
  end)
  local expiryText = tostring(options.ExpiryText or options.expiryText or "30 days left")
  local footerName = create("TextLabel", {
    Parent = footer,
    Name = "UsernameText",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -42, 0, 10),
    Size = UDim2.fromOffset(120, 16),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = LocalPlayer.Name,
    TextColor3 = theme.text,
    TextSize = 13,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 6,
  })
  local footerText = create("TextLabel", {
    Parent = footer,
    Name = "StatusText",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -42, 0, 27),
    Size = UDim2.fromOffset(120, 15),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    RichText = true,
    Text = "",
    TextColor3 = theme.textMuted,
    TextSize = 12,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 6,
  })

  local function getWhitelistSecondsLeft()
    local ok, value = pcall(function()
      return LP_TIMELEFT
    end)
    value = ok and value or nil
    if tonumber(value) == nil then
      local env = (getgenv and getgenv()) or _G
      value = env and rawget(env, "LP_TIMELEFT") or nil
    end
    value = tonumber(value)
    if not value then
      return nil
    end
    return math.max(0, math.floor(value))
  end

  local function formatWhitelistTime(seconds)
    if not seconds then
      return expiryText
    end
    if seconds <= 0 then
      return "Lifetime"
    end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60
    if days > 0 then
      if hours > 0 then
        return string.format("%dd %dh", days, hours)
      end
      return string.format("%dd", days)
    end
    if hours > 0 then
      if minutes > 0 then
        return string.format("%dh %dm", hours, minutes)
      end
      return string.format("%dh", hours)
    end
    if minutes > 0 then
      return string.format("%dm %ds", minutes, remainingSeconds)
    end
    return string.format("%ds", remainingSeconds)
  end

  local function refreshFooterExpire(color)
    footerName.Text = LocalPlayer.Name
    footerText.Text = string.format(
      'Expire: <font color="#%s">%s</font>',
      (color or self.accent):ToHex(),
      formatWhitelistTime(getWhitelistSecondsLeft())
    )
  end
  local resizeHandle = create("ImageButton", {
    Parent = footer,
    Name = "ResizeHandle",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -5, 1, -4),
    Size = UDim2.fromOffset(18, 18),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Image = "rbxassetid://72566512767985",
    ImageColor3 = theme.textMuted,
    ImageTransparency = 1,
    ScaleType = Enum.ScaleType.Fit,
    Visible = false,
    Active = false,
    ZIndex = 7,
  })
  local resizeTouchTarget = create("TextButton", {
    Parent = footer,
    Name = "ResizeTouchTarget",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, 0, 1, 0),
    Size = UDim2.fromOffset(isMobileDevice and 34 or 18, isMobileDevice and 34 or 18),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    Visible = true,
    Active = true,
    ZIndex = 120,
  })
  resizeHandle.MouseEnter:Connect(function()
    tween(resizeHandle, {
      ImageColor3 = self.accent,
      ImageTransparency = 0,
    }, 0.10, Enum.EasingStyle.Sine)
  end)
  resizeHandle.MouseLeave:Connect(function()
    tween(resizeHandle, {
      ImageColor3 = theme.textMuted,
      ImageTransparency = 0,
    }, 0.10, Enum.EasingStyle.Sine)
  end)
  resizeTouchTarget.MouseEnter:Connect(function()
    tween(resizeHandle, {
      ImageColor3 = self.accent,
      ImageTransparency = 0,
    }, 0.10, Enum.EasingStyle.Sine)
  end)
  resizeTouchTarget.MouseLeave:Connect(function()
    tween(resizeHandle, {
      ImageColor3 = theme.textMuted,
      ImageTransparency = 0,
    }, 0.10, Enum.EasingStyle.Sine)
  end)
  local mobileToggleGlow = create("ImageLabel", {
    Parent = screenGui,
    Name = "MobileMenuToggleGlow",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -4, 0, 52),
    Size = UDim2.fromOffset(124, 64),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://18245826428",
    ImageColor3 = self.accent,
    ImageTransparency = 0.48,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(21, 21, 79, 79),
    Visible = false,
    ZIndex = 2499,
  })
  local mobileToggle = create("TextButton", {
    Parent = screenGui,
    Name = "MobileMenuToggle",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -14, 0, 62),
    Size = UDim2.fromOffset(104, 44),
    BackgroundColor3 = theme.control,
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    Visible = isMobileDevice,
    ZIndex = 2500,
  })
  corner(mobileToggle, 9)
  local mobileToggleStroke = stroke(mobileToggle, self.accent, 0.28, 1)
  local mobileToggleScale = create("UIScale", {
    Parent = mobileToggle,
    Scale = 1,
  })
  create("UIGradient", {
    Parent = mobileToggle,
    Rotation = 90,
    Color = subtleControlSequence(),
  })
  local mobileToggleAccent = create("Frame", {
    Parent = mobileToggle,
    Position = UDim2.fromOffset(0, 7),
    Size = UDim2.fromOffset(3, 30),
    BackgroundColor3 = self.accent,
    BorderSizePixel = 0,
    ZIndex = 2502,
  })
  corner(mobileToggleAccent, 999)
  local mobileToggleIcon = create("Frame", {
    Parent = mobileToggle,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 11, 0.5, 0),
    Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = self.accent,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    ZIndex = 2502,
  })
  corner(mobileToggleIcon, 7)
  create("UIGradient", {
    Parent = mobileToggleIcon,
    Rotation = 90,
    Color = subtleAccentSequence(self.accent),
  })
  create("TextLabel", {
    Parent = mobileToggleIcon,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "V",
    TextColor3 = theme.white,
    TextSize = 14,
    Font = Enum.Font.ArialBold,
    ZIndex = 2503,
  })
  create("TextLabel", {
    Parent = mobileToggle,
    Position = UDim2.fromOffset(45, 0),
    Size = UDim2.new(1, -51, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "open ui",
    TextColor3 = theme.white,
    TextSize = 12,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2502,
  })
  mobileToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      tween(mobileToggleScale, {Scale = 0.94}, 0.06, Enum.EasingStyle.Quad)
      tween(mobileToggle, {BackgroundTransparency = 0}, 0.06, Enum.EasingStyle.Quad)
    end
  end)
  mobileToggle.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      tween(mobileToggleScale, {Scale = 1}, 0.14, Enum.EasingStyle.Back)
      tween(mobileToggle, {BackgroundTransparency = 0.04}, 0.10, Enum.EasingStyle.Quad)
    end
  end)
  window.Gui = screenGui
  window.PopupLayer = popupLayer
  window.BodyBackground = bodyBackground
  window.HeaderBottomMask = headerBottomMask
  window.Shadow = shadow
  window.Root = root
  window.Scale = scale
  window.Header = header
  window.GradientStrip = gradientStrip
  window.HeaderGradient = headerGradient
  window.HeaderBottomGradient = headerBottomGradient
  window.HeaderGradientLeft = headerGradientLeft
  window.HeaderGradientRight = headerGradientRight
  window.StarLayer = starLayer
  window.Title = title
  window.TitlePrefix = titlePrefix
  window.TitleSuffix = titleSuffix
  window.MobileClose = mobileClose
  window.TabBar = tabBar
  window.TabButtons = tabButtons
  window.PageHolder = pageHolder
  window.Footer = footer
  window.FooterAvatar = footerAvatar
  window.FooterName = footerName
  window.FooterText = footerText
  window.ExpiryText = expiryText
  window.ResizeHandle = resizeHandle
  window.MobileToggle = mobileToggle
  window.MobileToggleGlow = mobileToggleGlow
  window.KeybindScreenGui = keybindScreenGui
  window.KeybindFrame = keybindFrame
  window.KeybindHeader = keybindHeader
  window.KeybindIcon = keybindIcon
  window.KeybindContent = keybindContent
  window.KeybindCount = keybindCount
  window.KeybindHeaderLine = keybindHeaderLine
  window.KeybindListVisible = options.KeybindListVisible ~= false
  self.window = window
  local keybindRows = {}
  local emptyKeybindRow = nil
  local keybindRefreshId = 0

  local function rowHeight()
    return isMobileDevice and 27 or 22
  end

  local function destroyEmptyRow(animated)
    local row = emptyKeybindRow
    emptyKeybindRow = nil
    if not row or not row.Parent then
      return
    end
    if animated then
      tween(row, {
        GroupTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
      }, 0.12, Enum.EasingStyle.Quad)
      task.delay(0.125, function()
        if row.Parent then
          row:Destroy()
        end
      end)
    else
      row:Destroy()
    end
  end

  local function createEmptyRow(refreshId)
    task.delay(0.15, function()
      if refreshId ~= keybindRefreshId or emptyKeybindRow or not keybindContent.Parent then
        return
      end
      for _, data in pairs(keybindRows) do
        if data.Row and data.Row.Parent and not data.Removing then
          return
        end
      end
      local row = create("CanvasGroup", {
        Parent = keybindContent,
        Name = "EmptyKeybindRow",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = 1,
        ZIndex = 12,
      })
      create("TextLabel", {
        Parent = row,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "No active keybinds",
        TextColor3 = theme.textDark,
        TextSize = 10,
        Font = Enum.Font.ArialBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 13,
      })
      emptyKeybindRow = row
      tween(row, {
        GroupTransparency = 0,
        Size = UDim2.new(1, 0, 0, rowHeight()),
      }, 0.15, Enum.EasingStyle.Quad)
    end)
  end

  local function formatKeybindEntry(entry)
    local keySuccess, key = pcall(entry.GetKey)
    local modeSuccess, mode = pcall(entry.GetMode or function()
      return "Toggle"
    end)
    local keyText = keySuccess and key ~= nil and keyName(key) or "None"
    local modeText = modeSuccess and normalizeBindMode(mode) or "Toggle"
    return string.format("[%s] %s - %s", modeText, tostring(entry.Name or "Toggle"), keyText)
  end

  local function createKeybindRow(entry, index)
    local row = create("CanvasGroup", {
      Parent = keybindContent,
      Name = "KeybindRow",
      Size = UDim2.new(1, 0, 0, 0),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      GroupTransparency = 1,
      ClipsDescendants = true,
      LayoutOrder = index,
      ZIndex = 12,
    })
    local label = create("TextLabel", {
      Parent = row,
      Size = UDim2.fromScale(1, 1),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = formatKeybindEntry(entry),
      TextColor3 = theme.text,
      TextSize = isMobileDevice and 12 or 10,
      Font = Enum.Font.ArialBold,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Center,
      TextTruncate = Enum.TextTruncate.AtEnd,
      ZIndex = 13,
    })
    local data = {
      Row = row,
      Label = label,
      Removing = false,
      RemovalToken = 0,
    }
    keybindRows[entry] = data
    task.defer(function()
      if row.Parent and not data.Removing then
        tween(row, {
          GroupTransparency = 0,
          Size = UDim2.new(1, 0, 0, rowHeight()),
        }, 0.17, Enum.EasingStyle.Quad)
      end
    end)
    return data
  end

  local function removeKeybindRow(entry, data)
    if not data or not data.Row or not data.Row.Parent then
      keybindRows[entry] = nil
      return
    end
    data.Removing = true
    data.RemovalToken = (data.RemovalToken or 0) + 1
    local removalToken = data.RemovalToken
    tween(data.Row, {
      GroupTransparency = 1,
      Size = UDim2.new(1, 0, 0, 0),
    }, 0.14, Enum.EasingStyle.Quad)
    task.delay(0.145, function()
      if data.Removing and data.RemovalToken == removalToken then
        if data.Row and data.Row.Parent then
          data.Row:Destroy()
        end
        if keybindRows[entry] == data then
          keybindRows[entry] = nil
        end
      end
    end)
  end
  function window:RefreshKeybindList()
    keybindRefreshId = keybindRefreshId + 1
    local refreshId = keybindRefreshId
    local activeEntries = {}
    local activeSet = {}
    local entries = self.library.keybindEntries
    for index = 1, #entries do
      local entry = entries[index]
      local stateSuccess, state = pcall(entry.GetState)
      if stateSuccess and state == true then
        activeEntries[#activeEntries + 1] = entry
        activeSet[entry] = true
      end
    end
    table.sort(activeEntries, function(a, b)
      return (a.Order or 0) < (b.Order or 0)
    end)
    local count = #activeEntries
    keybindCount.Text = tostring(count)
    keybindTitle.Text = string.format("Keybind List (%d)", count)
    keybindFrame.Visible = self.KeybindListVisible == true
    for entry, data in pairs(keybindRows) do
      if not activeSet[entry] then
        removeKeybindRow(entry, data)
      end
    end
    if count > 0 then
      destroyEmptyRow(true)
    end
    for index = 1, #activeEntries do
      local entry = activeEntries[index]
      local data = keybindRows[entry]
      if not data or not data.Row or not data.Row.Parent then
        data = createKeybindRow(entry, index)
      else
        data.Removing = false
        data.RemovalToken = (data.RemovalToken or 0) + 1
        data.Row.LayoutOrder = index
        data.Label.Text = formatKeybindEntry(entry)
        tween(data.Row, {
          GroupTransparency = 0,
          Size = UDim2.new(1, 0, 0, rowHeight()),
        }, 0.13, Enum.EasingStyle.Quad)
      end
    end
    if count == 0 then
      createEmptyRow(refreshId)
    end
  end
  function window:RegisterKeybind(entry)
    entry = entry or {}
    entry.Order = #self.library.keybindEntries + 1
    self.library.keybindEntries[#self.library.keybindEntries + 1] = entry
    self:RefreshKeybindList()
    return entry
  end
  function window:SetKeybindListVisible(state)
    self.KeybindListVisible = state == true
    self.library.flags.keybind_list = self.KeybindListVisible
    keybindFrame.Visible = self.KeybindListVisible
    if self.KeybindListVisible then
      self:RefreshKeybindList()
    end
  end
  local keybindDragging = false
  local keybindDragInput
  local keybindDragStart
  local keybindStartPosition
  keybindHeader.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    keybindDragging = true
    keybindDragInput = input
    keybindDragStart = input.Position
    keybindStartPosition = keybindFrame.Position
  end)
  connect(UserInputService.InputChanged, function(input)
    if not keybindDragging then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    if keybindDragInput and keybindDragInput.UserInputType == Enum.UserInputType.Touch and input ~= keybindDragInput then
      return
    end
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local delta = input.Position - keybindDragStart
    local width = keybindFrame.AbsoluteSize.X
    local height = keybindFrame.AbsoluteSize.Y
    local x = math.clamp(keybindStartPosition.X.Offset + delta.X, 4, math.max(4, viewport.X - width - 4))
    local y = math.clamp(keybindStartPosition.Y.Offset + delta.Y, 4, math.max(4, viewport.Y - height - 4))
    keybindFrame.Position = UDim2.fromOffset(x, y)
  end)
  connect(UserInputService.InputEnded, function(input)
    if input == keybindDragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
      keybindDragging = false
      keybindDragInput = nil
    end
  end)
  function window:RegisterAccent(callback)
    if type(callback) == "function" then
      self.accentCallbacks[#self.accentCallbacks + 1] = callback
      callback(self.library.accent)
    end
  end
  function window:RefreshAccent()
    for index = #self.accentCallbacks, 1, -1 do
      local callback = self.accentCallbacks[index]
      local success = pcall(callback, self.library.accent)
      if not success then
        table.remove(self.accentCallbacks, index)
      end
    end
  end
  window:RegisterAccent(function(color)
    titleSuffix.TextColor3 = color
    mobileToggleGlow.ImageColor3 = color
    mobileToggleStroke.Color = color
    mobileToggleAccent.BackgroundColor3 = color
    mobileToggleIcon.BackgroundColor3 = color
    local mobileIconGradient = mobileToggleIcon:FindFirstChildOfClass("UIGradient")
    if mobileIconGradient then
      mobileIconGradient.Color = subtleAccentSequence(color)
    end
    refreshFooterExpire(color)
    keybindIcon.ImageColor3 = color
    window:RefreshKeybindList()
  end)
  window:RegisterAccent(function(color)
    if notificationAccentLine and notificationAccentLine.Parent then
      notificationAccentLine.BackgroundColor3 = color
    end
  end)

  local footerExpireClock = 0
  connect(RunService.Heartbeat, function()
    local now = os.clock()
    if now - footerExpireClock >= 1 then
      footerExpireClock = now
      refreshFooterExpire(self.accent)
    end
  end)
  function window:SetNotificationsVisible(value)
    value = value == true
    if notificationAnchor then notificationAnchor.Visible = value end
    if notificationStack then notificationStack.Visible = value end
  end
  self.flags.header_gradient_left = headerGradientLeft
  self.flags.header_gradient_right = headerGradientRight
  function window:SetHeaderGradient(leftColor, rightColor)
    if typeof(leftColor) == "Color3" then
      self.HeaderGradientLeft = leftColor
      self.library.flags.header_gradient_left = leftColor
    end
    if typeof(rightColor) == "Color3" then
      self.HeaderGradientRight = rightColor
      self.library.flags.header_gradient_right = rightColor
    end
    local sequence = ColorSequence.new({
      ColorSequenceKeypoint.new(0, self.HeaderGradientLeft),
      ColorSequenceKeypoint.new(1, self.HeaderGradientRight),
    })
    self.HeaderGradient.Color = sequence
    self.HeaderBottomGradient.Color = sequence
  end
  function window:SetHeaderGradientLeft(color)
    self:SetHeaderGradient(color, nil)
  end
  function window:SetHeaderGradientRight(color)
    self:SetHeaderGradient(nil, color)
  end
  function window:GetHeaderGradient()
    return self.HeaderGradientLeft, self.HeaderGradientRight
  end
  function window:SetVisible(state)
    state = state == true
    if self.library.visible == state then
      return
    end
    self.library.visible = state
    self.library:ClosePopup()
    if state then
      self.Gui.Enabled = true
      self.Shadow.Visible = true
      mobileToggle.Visible = false
      mobileToggleGlow.Visible = false
      self.Root.Visible = true
      self.Root.GroupTransparency = 1
      self.Scale.Scale = isMobileDevice and 1 or 0.965
      tween(self.Root, {GroupTransparency = 0}, 0.15, Enum.EasingStyle.Quad)
      if not isMobileDevice then
        tween(self.Scale, {Scale = 1}, 0.18, Enum.EasingStyle.Back)
      end
    else
      tween(self.Root, {GroupTransparency = 1}, 0.11, Enum.EasingStyle.Quad)
      if not isMobileDevice then
        tween(self.Scale, {Scale = 0.975}, 0.11, Enum.EasingStyle.Quad)
      end
      task.delay(0.12, function()
        if not self.library.visible and self.Gui then
          self.Shadow.Visible = false
          if isMobileDevice then
            self.Root.Visible = false
            mobileToggle.Visible = true
            mobileToggleGlow.Visible = true
          else
            self.Gui.Enabled = false
          end
        end
      end)
    end
  end
  function window:Toggle()
    self:SetVisible(not self.library.visible)
  end
  function window:SetMenuKey(key)
    self.menuKey = key
  end
  function window:SetFooter(text)
    self.ExpiryText = tostring(text or "30 days left")
    expiryText = self.ExpiryText
    if self.FooterName then
      self.FooterName.Text = LocalPlayer.Name
    end
    self.FooterText.Text = string.format(
      'Expire: <font color="#%s">%s</font>',
      self.library.accent:ToHex(),
      expiryText
    )
  end
  function window:SetMobileLayout(enabled)
    enabled = enabled == true
    if self.mobileLayout == enabled then
      return
    end
    self.mobileLayout = enabled
    local tabs = self.tabs
    for tabIndex = 1, #tabs do
      local subtabs = tabs[tabIndex].subtabs
      for subtabIndex = 1, #subtabs do
        local subtabObject = subtabs[subtabIndex]
        if subtabObject.SetMobileLayout then
          subtabObject:SetMobileLayout(enabled)
        end
      end
    end
  end
  self.flags.keybind_list = window.KeybindListVisible
  window:RefreshKeybindList()
  mobileToggle.Visible = false
  mobileToggleGlow.Visible = false
  mobileToggle.Activated:Connect(function()
    window:SetVisible(true)
  end)
  mobileClose.Activated:Connect(function()
    window:SetVisible(false)
  end)
  local dragging = false
  local dragInput
  local dragStart
  local startPosition
  header.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    local inputPosition = Vector2.new(input.Position.X, input.Position.Y)
    if pointInside(inputPosition, tabBar) or pointInside(inputPosition, mobileClose) then
      return
    end
    dragging = true
    dragInput = input
    dragStart = input.Position
    startPosition = root.Position
    self:ClosePopup()
  end)
  connect(UserInputService.InputChanged, function(input)
    if not dragging then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    if dragInput and dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
      return
    end
    local delta = input.Position - dragStart
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local startX = (viewport.X * startPosition.X.Scale) + startPosition.X.Offset
    local startY = (viewport.Y * startPosition.Y.Scale) + startPosition.Y.Offset
    local halfWidth = root.AbsoluteSize.X * 0.5
    local halfHeight = root.AbsoluteSize.Y * 0.5
    local targetX = math.clamp(startX + delta.X, halfWidth, math.max(halfWidth, viewport.X - halfWidth))
    local targetY = math.clamp(startY + delta.Y, halfHeight, math.max(halfHeight, viewport.Y - halfHeight))
    local newPosition = UDim2.fromOffset(targetX, targetY)
    root.Position = newPosition
    shadow.Position = newPosition
  end)
  connect(UserInputService.InputEnded, function(input)
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = false
      dragInput = nil
    end
  end)
  local resizing = false
  local resizeEnabled = true
  local resizeInput
  local resizeStart
  local startSize
  local resizeStartPosition

  local function beginResize(input)
    if not resizeEnabled then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    if resizing then
      return
    end
    resizing = true
    resizeInput = input
    resizeStart = input.Position
    startSize = root.AbsoluteSize
    resizeStartPosition = root.Position
    self:ClosePopup()
  end
  resizeTouchTarget.InputBegan:Connect(beginResize)
  resizeHandle.InputBegan:Connect(beginResize)
  connect(UserInputService.InputChanged, function(input)
    if not resizing then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    if resizeInput and resizeInput.UserInputType == Enum.UserInputType.Touch and input ~= resizeInput then
      return
    end
    local delta = input.Position - resizeStart
    local width = math.clamp(startSize.X + delta.X, window.minimumSize.X, window.maximumSize.X)
    local height = math.clamp(startSize.Y + delta.Y, window.minimumSize.Y, window.maximumSize.Y)
    local widthChange = width - startSize.X
    local heightChange = height - startSize.Y
    local nextPosition = UDim2.new(
      resizeStartPosition.X.Scale,
      resizeStartPosition.X.Offset + (widthChange * 0.5),
      resizeStartPosition.Y.Scale,
      resizeStartPosition.Y.Offset + (heightChange * 0.5)
    )
    root.Size = UDim2.fromOffset(width, height)
    root.Position = nextPosition
    shadow.Size = UDim2.fromOffset(width, height)
    shadow.Position = nextPosition
  end)
  connect(UserInputService.InputEnded, function(input)
    if input == resizeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
      resizing = false
      resizeInput = nil
    end
  end)

  local function updateScale()
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local availableX = math.max(viewport.X - 12, 1)
    local availableY = math.max(viewport.Y - 12, 1)
    if isMobileDevice then
      local width = math.min(760, availableX)
      local height = math.min(620, availableY)
      root.Size = UDim2.fromOffset(width, height)
      root.Position = UDim2.fromScale(0.5, 0.5)
      shadow.Size = UDim2.fromOffset(width, height)
      shadow.Position = root.Position
      scale.Scale = 1
      window.maximumSize = Vector2.new(availableX, availableY)
      window:SetMobileLayout(width < 590)
    else
      local current = root.AbsoluteSize
      local newScale = math.min(1, availableX / math.max(current.X, 1), availableY / math.max(current.Y, 1))
      scale.Scale = math.clamp(newScale, 0.50, 1)
      window:SetMobileLayout(false)
    end
  end
  task.defer(updateScale)
  if workspace.CurrentCamera then
    connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
  end
  connect(UserInputService.InputBegan, function(input, processed)
    if processed then
      return
    end
    local key = normalizeKey(input)
    if key == window.menuKey then
      window:Toggle()
    end
  end)
  connect(UserInputService.InputBegan, function(input)
    if not self.currentPopup then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    local position = Vector2.new(input.Position.X, input.Position.Y)
    local popup = self.currentPopup
    if not pointInside(position, popup.Frame) and not pointInside(position, popup.Anchor) then
      self:ClosePopup()
    end
  end)
  return setmetatable(window, {__index = library})
end

function library:Tab(options)
  options = options or {}
  local window = self.Root and self or self.window
  if not window then
    return nil
  end
  local tab = {
    window = window,
    library = window.library,
    name = tostring(options.Name or options.name or "Tab"),
    icon = tostring(options.Icon or options.icon or 71391894371551),
    sections = {},
    subtabs = {},
    activeSubtab = nil,
  }
  local button = create("TextButton", {
    Parent = window.TabButtons,
    Name = tab.name .. "Tab",
    Size = UDim2.fromOffset(86, 46),
    BackgroundColor3 = theme.control,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    LayoutOrder = #window.tabs + 1,
    ZIndex = 6,
  })
  corner(button, 3)
  local buttonScale = create("UIScale", {
    Parent = button,
    Scale = 1,
  })
  local buttonStroke = stroke(button, theme.outlineSoft, 1, 1)
  local activeLine = create("Frame", {
    Parent = button,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 1, -5),
    Size = UDim2.fromOffset(18, 2),
    BackgroundColor3 = window.library.accent,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 8,
  })
  corner(activeLine, 999)
  local activeLineGlow = create("ImageLabel", {
    Parent = button,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 1, -4),
    Size = UDim2.fromOffset(34, 15),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://18245826428",
    ImageColor3 = window.library.accent,
    ImageTransparency = 1,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(21, 21, 79, 79),
    ZIndex = 7,
  })
  local icon = create("ImageLabel", {
    Parent = button,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 1),
    Size = UDim2.fromOffset(23, 23),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://" .. tab.icon,
    ImageColor3 = theme.textDark,
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 8,
  })
  local label = create("TextLabel", {
    Parent = button,
    Position = UDim2.fromOffset(2, 25),
    Size = UDim2.new(1, -4, 0, 16),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = tab.name,
    TextColor3 = theme.textMuted,
    TextSize = 12,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 8,
  })
  local page = create("CanvasGroup", {
    Parent = window.PageHolder,
    Name = tab.name .. "Page",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Visible = false,
  })
  local subtabBar = create("Frame", {
    Parent = page,
    Name = "SubtabBar",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 5,
  })
  local subtabButtons = create("Frame", {
    Parent = subtabBar,
    Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(1, -20, 0, 31),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 6,
  })
  create("UIListLayout", {
    Parent = subtabButtons,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
  })
  local subtabDivider = create("Frame", {
    Parent = subtabBar,
    Name = "Divider",
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.fromOffset(0, 33),
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = theme.outlineSoft,
    BackgroundTransparency = 0.22,
    BorderSizePixel = 0,
    ZIndex = 6,
  })
  local subtabHolder = create("Frame", {
    Parent = page,
    Name = "SubtabHolder",
    Position = UDim2.fromOffset(12, 40),
    Size = UDim2.new(1, -20, 1, -40),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
  })
  tab.Button = button
  tab.Icon = icon
  tab.Label = label
  tab.ActiveLine = activeLine
  tab.ActiveLineGlow = activeLineGlow
  tab.ButtonStroke = buttonStroke
  tab.Page = page
  tab.SubtabBar = subtabBar
  tab.SubtabButtons = subtabButtons
  tab.SubtabHolder = subtabHolder
  tab.SubtabDivider = subtabDivider
  function tab:_CreateSubTab(subOptions, isDefault)
    subOptions = subOptions or {}
    local subtab = {
      tab = self,
      window = self.window,
      library = self.library,
      name = tostring(subOptions.Name or subOptions.name or "Main"),
      sections = {},
    }
    local subButton = create("TextButton", {
      Parent = self.SubtabButtons,
      Size = UDim2.fromOffset(0, 29),
      AutomaticSize = Enum.AutomaticSize.X,
      BackgroundColor3 = theme.control,
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      AutoButtonColor = false,
      Text = "",
      LayoutOrder = #self.subtabs + 1,
      ZIndex = 7,
    })
    corner(subButton, 1)
    padding(subButton, 12, 12, 0, 0)
    local subStroke = stroke(subButton, theme.outlineSoft, 1, 1)
    local subLabel = create("TextLabel", {
      Parent = subButton,
      Position = UDim2.fromOffset(0, 3),
      Size = UDim2.fromOffset(0, 18),
      AutomaticSize = Enum.AutomaticSize.X,
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = subtab.name,
      TextColor3 = theme.textMuted,
      TextSize = 12,
      Font = Enum.Font.ArialBold,
      TextXAlignment = Enum.TextXAlignment.Center,
      TextYAlignment = Enum.TextYAlignment.Center,
      ZIndex = 8,
    })
    local subLine = create("Frame", {
      Parent = subButton,
      AnchorPoint = Vector2.new(0.5, 1),
      Position = UDim2.new(0.5, 0, 1, -2),
      Size = UDim2.fromOffset(16, 2),
      BackgroundColor3 = self.library.accent,
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      ZIndex = 8,
    })
    corner(subLine, 999)
    local subLineGlow = create("ImageLabel", {
      Parent = subButton,
      AnchorPoint = Vector2.new(0.5, 0.5),
      Position = UDim2.new(0.5, 0, 1, -1),
      Size = UDim2.fromOffset(28, 10),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Image = "rbxassetid://18245826428",
      ImageColor3 = self.library.accent,
      ImageTransparency = 1,
      ScaleType = Enum.ScaleType.Slice,
      SliceCenter = Rect.new(21, 21, 79, 79),
      ZIndex = 7,
    })
    local subPage = create("CanvasGroup", {
      Parent = self.SubtabHolder,
      Name = subtab.name .. "SubtabPage",
      Position = UDim2.fromOffset(0, 16),
      Size = UDim2.new(1, 0, 1, -16),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      GroupTransparency = 1,
      Visible = false,
    })
    local leftColumn = create("ScrollingFrame", {
      Parent = subPage,
      Name = "LeftColumn",
      Position = UDim2.fromOffset(0, 0),
      Size = UDim2.new(0.5, -5, 1, 0),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      AutomaticCanvasSize = Enum.AutomaticSize.Y,
      CanvasSize = UDim2.fromOffset(0, 0),
      ScrollBarThickness = isMobileDevice and 4 or 3,
      ScrollBarImageColor3 = window.library.accent,
      ScrollBarImageTransparency = 0.62,
      ScrollingDirection = Enum.ScrollingDirection.Y,
      VerticalScrollBarInset = Enum.ScrollBarInset.None,
    })
    create("UIListLayout", {
      Parent = leftColumn,
      FillDirection = Enum.FillDirection.Vertical,
      HorizontalAlignment = Enum.HorizontalAlignment.Center,
      SortOrder = Enum.SortOrder.LayoutOrder,
      Padding = UDim.new(0, 10),
    })
    padding(leftColumn, 2, 4, 2, 3)
    local rightColumn = create("ScrollingFrame", {
      Parent = subPage,
      Name = "RightColumn",
      Position = UDim2.new(0.5, 5, 0, 0),
      Size = UDim2.new(0.5, -5, 1, 0),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      AutomaticCanvasSize = Enum.AutomaticSize.Y,
      CanvasSize = UDim2.fromOffset(0, 0),
      ScrollBarThickness = isMobileDevice and 4 or 3,
      ScrollBarImageColor3 = window.library.accent,
      ScrollBarImageTransparency = 0.62,
      ScrollingDirection = Enum.ScrollingDirection.Y,
      VerticalScrollBarInset = Enum.ScrollBarInset.None,
    })
    create("UIListLayout", {
      Parent = rightColumn,
      FillDirection = Enum.FillDirection.Vertical,
      HorizontalAlignment = Enum.HorizontalAlignment.Center,
      SortOrder = Enum.SortOrder.LayoutOrder,
      Padding = UDim.new(0, 10),
    })
    padding(rightColumn, 4, 2, 2, 3)
    local mobileColumn = create("ScrollingFrame", {
      Parent = subPage,
      Name = "MobileColumn",
      Position = UDim2.fromOffset(0, 0),
      Size = UDim2.fromScale(1, 1),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      AutomaticCanvasSize = Enum.AutomaticSize.Y,
      CanvasSize = UDim2.fromOffset(0, 0),
      ScrollBarThickness = isMobileDevice and 4 or 3,
      ScrollBarImageColor3 = window.library.accent,
      ScrollBarImageTransparency = 0.62,
      ScrollingDirection = Enum.ScrollingDirection.Y,
      VerticalScrollBarInset = Enum.ScrollBarInset.None,
      Visible = false,
    })
    create("UIListLayout", {
      Parent = mobileColumn,
      FillDirection = Enum.FillDirection.Vertical,
      HorizontalAlignment = Enum.HorizontalAlignment.Center,
      SortOrder = Enum.SortOrder.LayoutOrder,
      Padding = UDim.new(0, 10),
    })
    padding(mobileColumn, 3, 3, 2, 4)
    subtab.Button = subButton
    subtab.Label = subLabel
    subtab.Stroke = subStroke
    subtab.Line = subLine
    subtab.LineGlow = subLineGlow
    subtab.Page = subPage
    subtab.LeftColumn = leftColumn
    subtab.RightColumn = rightColumn
    subtab.MobileColumn = mobileColumn
    self.window:RegisterAccent(function(color)
      leftColumn.ScrollBarImageColor3 = color
      rightColumn.ScrollBarImageColor3 = color
      mobileColumn.ScrollBarImageColor3 = color
    end)
    function subtab:SetMobileLayout(enabled)
      enabled = enabled == true
      self.LeftColumn.Visible = not enabled
      self.RightColumn.Visible = not enabled
      self.MobileColumn.Visible = enabled
      local sections = self.sections
      for index = 1, #sections do
        local sectionObject = sections[index]
        if sectionObject.Frame and sectionObject.Frame.Parent then
          sectionObject.Frame.Parent = enabled and self.MobileColumn or sectionObject.DesktopParent
        end
      end
    end

    local function setVisual(active, hovering)
      if active then
        subButton.BackgroundTransparency = 0.86
        subStroke.Color = theme.outlineSoft
        subStroke.Transparency = 0.58
        subLine.BackgroundColor3 = self.library.accent
        subLine.BackgroundTransparency = 0
        subLine.Size = UDim2.fromOffset(28, 3)
        subLineGlow.ImageColor3 = self.library.accent
        subLineGlow.ImageTransparency = 0.54
        subLineGlow.Size = UDim2.fromOffset(40, 12)
        subLabel.TextColor3 = theme.white
      else
        subStroke.Color = theme.outlineSoft
        subStroke.Transparency = hovering and 0.84 or 1
        subButton.BackgroundTransparency = hovering and 0.95 or 1
        subLine.BackgroundColor3 = self.library.accent
        subLine.BackgroundTransparency = hovering and 0.36 or 1
        subLine.Size = UDim2.fromOffset(18, 2)
        subLineGlow.ImageColor3 = self.library.accent
        subLineGlow.ImageTransparency = hovering and 0.88 or 1
        subLineGlow.Size = UDim2.fromOffset(28, 10)
        subLabel.TextColor3 = hovering and theme.text or theme.textMuted
      end
    end
    function subtab:Open()
      if self.tab.activeSubtab == self then
        return
      end
      self.library:ClosePopup()
      self.tab.subtabTransitionId = (self.tab.subtabTransitionId or 0) + 1
      local transitionId = self.tab.subtabTransitionId
      local previous = self.tab.activeSubtab
      self.tab.activeSubtab = self
      if previous then
        previous.SetVisual(false, false)
      end
      self.SetVisual(true, false)
      local visiblePrevious = nil
      local subtabs = self.tab.subtabs
      for index = 1, #subtabs do
        local other = subtabs[index]
        if other ~= self and other.Page and other.Page.Visible then
          visiblePrevious = other
          break
        end
      end

      local function revealCurrent()
        if self.tab.subtabTransitionId ~= transitionId or self.tab.activeSubtab ~= self then
          return
        end
        local subtabs = self.tab.subtabs
        for index = 1, #subtabs do
          local other = subtabs[index]
          if other ~= self and other.Page then
            other.Page.Visible = false
            other.Page.GroupTransparency = 1
            other.Page.Position = UDim2.fromOffset(0, 0)
          end
        end
        self.Page.Visible = true
        self.Page.GroupTransparency = 1
        self.Page.Position = UDim2.fromOffset(7, 0)
        tween(self.Page, {
          GroupTransparency = 0,
          Position = UDim2.fromOffset(0, 0),
        }, 0.18, Enum.EasingStyle.Quad)
      end
      if visiblePrevious and visiblePrevious.Page then
        local fadeOut = tween(visiblePrevious.Page, {
          GroupTransparency = 1,
          Position = UDim2.fromOffset(-7, 0),
        }, 0.13, Enum.EasingStyle.Quad)
        if fadeOut then
          fadeOut.Completed:Connect(function()
            if self.tab.subtabTransitionId ~= transitionId then
              return
            end
            visiblePrevious.Page.Visible = false
            visiblePrevious.Page.Position = UDim2.fromOffset(0, 0)
            revealCurrent()
          end)
        else
          revealCurrent()
        end
      else
        revealCurrent()
      end
    end
    subtab.SetVisual = setVisual
    setVisual(false, false)
    subtab:SetMobileLayout(self.window.mobileLayout)
    subButton.MouseEnter:Connect(function()
      if self.activeSubtab ~= subtab then
        setVisual(false, true)
      end
    end)
    subButton.MouseLeave:Connect(function()
      if self.activeSubtab ~= subtab then
        setVisual(false, false)
      end
    end)
    subButton.Activated:Connect(function()
      subtab:Open()
    end)
    self.window:RegisterAccent(function(color)
      subLineGlow.ImageColor3 = color
      if self.activeSubtab == subtab then
        subLine.BackgroundColor3 = color
      end
    end)
    self.subtabs[#self.subtabs + 1] = subtab
    if isDefault then
      self.DefaultSubTab = subtab
      self.LeftColumn = leftColumn
      self.RightColumn = rightColumn
    end
    if not self.activeSubtab then
      subtab:Open()
    end
    return setmetatable(subtab, {__index = library})
  end
  window:RegisterAccent(function(color)
    activeLineGlow.ImageColor3 = color
    if window.activeTab == tab then
      activeLine.BackgroundColor3 = color
      icon.ImageColor3 = color
    end
  end)
  function tab:Open()
    if self.window.activeTab == self then
      return
    end
    self.library:ClosePopup()
    self.window.tabTransitionId = (self.window.tabTransitionId or 0) + 1
    local transitionId = self.window.tabTransitionId
    local previous = self.window.activeTab
    self.window.activeTab = self
    if previous then
      tween(previous.Icon, {ImageColor3 = theme.textDark}, 0.10, Enum.EasingStyle.Sine)
      tween(previous.Label, {TextColor3 = theme.textMuted}, 0.10, Enum.EasingStyle.Sine)
      tween(previous.Button, {BackgroundTransparency = 1}, 0.10, Enum.EasingStyle.Sine)
      tween(previous.ButtonStroke, {Transparency = 1}, 0.10, Enum.EasingStyle.Sine)
      tween(previous.ActiveLine, {BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 2)}, 0.10, Enum.EasingStyle.Sine)
      tween(previous.ActiveLineGlow, {ImageTransparency = 1, Size = UDim2.fromOffset(34, 15)}, 0.10, Enum.EasingStyle.Sine)
    end
    tween(self.Button, {BackgroundTransparency = 0.80}, 0.12, Enum.EasingStyle.Quad)
    tween(self.ButtonStroke, {Transparency = 0.34}, 0.12, Enum.EasingStyle.Quad)
    tween(self.ActiveLine, {BackgroundColor3 = self.library.accent, BackgroundTransparency = 0, Size = UDim2.fromOffset(26, 3)}, 0.12, Enum.EasingStyle.Quad)
    tween(self.ActiveLineGlow, {ImageColor3 = self.library.accent, ImageTransparency = 0.24, Size = UDim2.fromOffset(42, 15)}, 0.14, Enum.EasingStyle.Quad)
    tween(self.Icon, {ImageColor3 = self.library.accent}, 0.10, Enum.EasingStyle.Sine)
    tween(self.Label, {TextColor3 = theme.white}, 0.10, Enum.EasingStyle.Sine)
    local visiblePrevious = nil
    local tabs = self.window.tabs
    for index = 1, #tabs do
      local other = tabs[index]
      if other ~= self and other.Page and other.Page.Visible then
        visiblePrevious = other
        break
      end
    end

    local function revealCurrent()
      if self.window.tabTransitionId ~= transitionId or self.window.activeTab ~= self then
        return
      end
      local tabs = self.window.tabs
      for index = 1, #tabs do
        local other = tabs[index]
        if other ~= self and other.Page then
          other.Page.Visible = false
          other.Page.GroupTransparency = 1
          other.Page.Position = UDim2.fromOffset(0, 0)
        end
      end
      self.Page.Visible = true
      self.Page.GroupTransparency = 1
      self.Page.Position = UDim2.fromOffset(10, 0)
      tween(self.Page, {
        GroupTransparency = 0,
        Position = UDim2.fromOffset(0, 0),
      }, 0.20, Enum.EasingStyle.Quad)
    end
    if visiblePrevious and visiblePrevious.Page then
      local fadeOut = tween(visiblePrevious.Page, {
        GroupTransparency = 1,
        Position = UDim2.fromOffset(-10, 0),
      }, 0.14, Enum.EasingStyle.Quad)
      if fadeOut then
        fadeOut.Completed:Connect(function()
          if self.window.tabTransitionId ~= transitionId then
            return
          end
          visiblePrevious.Page.Visible = false
          visiblePrevious.Page.Position = UDim2.fromOffset(0, 0)
          revealCurrent()
        end)
      else
        revealCurrent()
      end
    else
      revealCurrent()
    end
  end
  button.MouseEnter:Connect(function()
    if window.activeTab ~= tab then
      tween(button, {BackgroundTransparency = 0.93}, 0.08, Enum.EasingStyle.Sine)
      tween(icon, {ImageColor3 = theme.textMuted}, 0.08, Enum.EasingStyle.Sine)
      tween(label, {TextColor3 = theme.text}, 0.08, Enum.EasingStyle.Sine)
      tween(activeLine, {BackgroundColor3 = window.library.accent, BackgroundTransparency = 0.30, Size = UDim2.fromOffset(20, 2)}, 0.08, Enum.EasingStyle.Sine)
      tween(activeLineGlow, {ImageColor3 = window.library.accent, ImageTransparency = 0.72, Size = UDim2.fromOffset(34, 13)}, 0.08, Enum.EasingStyle.Sine)
    end
  end)
  button.MouseLeave:Connect(function()
    if window.activeTab ~= tab then
      tween(button, {BackgroundTransparency = 1}, 0.08, Enum.EasingStyle.Sine)
      tween(icon, {ImageColor3 = theme.textDark}, 0.08, Enum.EasingStyle.Sine)
      tween(label, {TextColor3 = theme.textMuted}, 0.08, Enum.EasingStyle.Sine)
      tween(activeLine, {BackgroundColor3 = window.library.accent, BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 2)}, 0.08, Enum.EasingStyle.Sine)
      tween(activeLineGlow, {ImageTransparency = 1, Size = UDim2.fromOffset(34, 15)}, 0.08, Enum.EasingStyle.Sine)
    end
  end)
  button.Activated:Connect(function()
    tab:Open()
  end)
  button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      tween(buttonScale, {Scale = 0.96}, 0.06, Enum.EasingStyle.Quad)
    end
  end)
  button.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      tween(buttonScale, {Scale = 1}, 0.12, Enum.EasingStyle.Back)
    end
  end)
  window.tabs[#window.tabs + 1] = tab
  tab:_CreateSubTab({Name = options.DefaultSubTabName or options.defaultSubTabName or "Main"}, true)
  if not window.activeTab then
    tab:Open()
  end
  return setmetatable(tab, {__index = library})
end

function library:SubTab(options)
  if self._CreateSubTab then
    return self:_CreateSubTab(options, false)
  end
  return nil
end

function library:Section(options)
  options = options or {}
  local host = self
  if self.DefaultSubTab and not self.LeftColumn then
    host = self.DefaultSubTab
  elseif self.DefaultSubTab and self.SubtabHolder then
    host = self.DefaultSubTab
  end
  if not host or not host.LeftColumn or not host.RightColumn then
    return nil
  end
  local side = string.lower(tostring(options.Side or options.side or "Left"))
  local desktopParent = side == "right" and host.RightColumn or host.LeftColumn
  local parent = host.window.mobileLayout and host.MobileColumn or desktopParent
  local section = {
    tab = host.tab or host,
    subtab = host.tab and host or nil,
    window = host.window,
    library = host.library,
    controls = {},
    Side = side,
    DesktopParent = desktopParent,
  }
  local frame = create("Frame", {
    Parent = parent,
    Name = tostring(options.Name or options.name or "Section"),
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = theme.section,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    LayoutOrder = options.Order or options.order or (#host.sections + 1),
  })
  corner(frame, 4)
  stroke(frame, Color3.fromRGB(63, 64, 73), 0.62, 1)
  create("UIListLayout", {
    Parent = frame,
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
  })
  local topInset = create("Frame", {
    Parent = frame,
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    LayoutOrder = 0,
  })
  local header = create("Frame", {
    Parent = frame,
    Name = "Header",
    Size = UDim2.new(1, -2, 0, 26),
    BackgroundColor3 = theme.sectionHeader,
    BorderSizePixel = 0,
    LayoutOrder = 1,
  })
  local headerAccentFade = create("Frame", {
    Parent = header,
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = section.library.accent,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 1,
    Visible = false,
  })
  local headerAccentGradient = create("UIGradient", {
    Parent = headerAccentFade,
    Rotation = 0,
    Transparency = NumberSequence.new({
      NumberSequenceKeypoint.new(0, 0.15),
      NumberSequenceKeypoint.new(0.42, 0.82),
      NumberSequenceKeypoint.new(1, 1),
    }),
    Color = ColorSequence.new(section.library.accent),
  })
  local headerLabel = create("TextLabel", {
    Parent = header,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -17, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = tostring(options.Name or options.name or "Section"),
    TextColor3 = theme.white,
    TextSize = 13,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
  })
  local headerTextGradient = create("UIGradient", {
    Parent = headerLabel,
    Rotation = 0,
    Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, theme.white),
      ColorSequenceKeypoint.new(0.55, lighten(section.library.accent, 0.30)),
      ColorSequenceKeypoint.new(1, section.library.accent),
    }),
    Transparency = NumberSequence.new({
      NumberSequenceKeypoint.new(0, 0),
      NumberSequenceKeypoint.new(0.72, 0.08),
      NumberSequenceKeypoint.new(1, 0.28),
    }),
  })
  local headerLine = create("Frame", {
    Parent = header,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = Color3.fromRGB(54, 55, 63),
    BackgroundTransparency = 0.60,
    BorderSizePixel = 0,
  })
  local content = create("Frame", {
    Parent = frame,
    Name = "Content",
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    LayoutOrder = 2,
    ClipsDescendants = false,
  })
  create("UIListLayout", {
    Parent = content,
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 5),
  })
  padding(content, 9, 9, 7, 9)
  section.window:RegisterAccent(function(color)
    headerAccentFade.BackgroundColor3 = color
    headerAccentGradient.Color = ColorSequence.new(color)
    headerTextGradient.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, theme.white),
      ColorSequenceKeypoint.new(0.55, lighten(color, 0.30)),
      ColorSequenceKeypoint.new(1, color),
    })
  end)
  section.Frame = frame
  section.Header = header
  section.HeaderLabel = headerLabel
  section.HeaderLine = headerLine
  section.HeaderIcon = headerAccentFade
  section.Content = content
  host.sections[#host.sections + 1] = section
  if section.tab and section.tab.sections then
    section.tab.sections[#section.tab.sections + 1] = section
  end
  return setmetatable(section, {__index = library})
end

local function controlBase(section, height, interactive)
  local className = interactive and "TextButton" or "Frame"
  local properties = {
    Parent = section.Content,
    Size = UDim2.new(1, 0, 0, height),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = false,
  }
  if interactive then
    properties.Text = ""
    properties.AutoButtonColor = false
  end
  return create(className, properties)
end

local function controlLabel(parent, text, size, position, muted)
  return create("TextLabel", {
    Parent = parent,
    Position = position or UDim2.fromOffset(0, 0),
    Size = size or UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = tostring(text or ""),
    TextColor3 = muted and theme.textMuted or theme.text,
    TextSize = 13,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
  })
end

local function styleButton(button, section, options)
  options = options or {}
  local disabled = options.Disabled == true
  local buttonText = button.Text
  button.AutoButtonColor = false
  button.Text = ""
  button.BackgroundColor3 = theme.white
  corner(button, 1)
  local buttonScale = create("UIScale", {
    Parent = button,
    Scale = 1,
  })
  local outline = stroke(button, darken(section.library.accent, 0.42), 0, 1)
  local gradient = create("UIGradient", {
    Parent = button,
    Rotation = 90,
    Color = subtleAccentSequence(section.library.accent),
  })
  local hoverOverlay = create("Frame", {
    Parent = button,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = theme.white,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = button.ZIndex + 2,
  })
  corner(hoverOverlay, 1)
  local textLabel = create("TextLabel", {
    Parent = button,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = buttonText,
    TextColor3 = theme.white,
    TextTransparency = 0,
    TextStrokeTransparency = 1,
    TextSize = button.TextSize,
    Font = button.Font,
    TextXAlignment = button.TextXAlignment,
    TextYAlignment = button.TextYAlignment,
    ZIndex = button.ZIndex + 5,
  })
  if not disabled then
    button.MouseEnter:Connect(function()
      tween(hoverOverlay, {BackgroundTransparency = 0.90}, 0.07, Enum.EasingStyle.Linear)
    end)
    button.MouseLeave:Connect(function()
      tween(hoverOverlay, {BackgroundTransparency = 1}, 0.07, Enum.EasingStyle.Linear)
    end)
    button.MouseButton1Down:Connect(function()
      tween(buttonScale, {Scale = 0.985}, 0.05, Enum.EasingStyle.Quad)
      tween(textLabel, {Position = UDim2.fromOffset(0, 1)}, 0.035, Enum.EasingStyle.Linear)
      tween(hoverOverlay, {BackgroundTransparency = 0.80}, 0.04, Enum.EasingStyle.Linear)
    end)
    button.MouseButton1Up:Connect(function()
      tween(buttonScale, {Scale = 1}, 0.10, Enum.EasingStyle.Back)
      tween(textLabel, {Position = UDim2.fromOffset(0, 0)}, 0.055, Enum.EasingStyle.Quad)
      tween(hoverOverlay, {BackgroundTransparency = 0.90}, 0.07, Enum.EasingStyle.Linear)
    end)
  end
  section.window:RegisterAccent(function(color)
    button.BackgroundColor3 = theme.white
    outline.Color = darken(color, 0.42)
    gradient.Color = accentSequence(color)
  end)
  return {
    Gradient = gradient,
    Outline = outline,
    Hover = hoverOverlay,
    Label = textLabel,
    Scale = buttonScale,
  }
end

function library:Label(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  if type(options) == "string" then
    options = {Text = options}
  end
  options = options or {}
  local row = controlBase(section, options.Height or 18, false)
  local label = controlLabel(row, options.Text or options.Name or "Label", UDim2.new(1, 0, 1, 0), nil, options.Muted == true)
  if options.Centered then
    label.TextXAlignment = Enum.TextXAlignment.Center
  end
  return label
end

function library:ESPPreview(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  options = options or {}
  local minimumHeight = tonumber(options.MinimumHeight or options.minimumHeight) or 330
  local maximumHeight = tonumber(options.MaximumHeight or options.maximumHeight) or 390
  local explicitHeight = tonumber(options.Height or options.height)
  local previewExtraBottom = tonumber(options.ExtraBottom or options.extraBottom) or 46
  local previewBottomExtension = tonumber(options.BottomExtension or options.bottomExtension) or 32
  previewBottomExtension = math.max(22, previewBottomExtension)
  local previewImageUrl = tostring(options.ImageUrl or options.imageUrl or "https://raw.githubusercontent.com/vi0letlol1/nett/refs/heads/main/345.png")
  local previewImageAsset = previewImageUrl
  local previewSourceSize = Vector2.new(521, 651)
  local previewCropOffset = Vector2.new(109, 48)
  local previewCropSize = Vector2.new(217, 603)
  local previewImageScale = 1.34
  do
    local environment = (getgenv and getgenv()) or _G

    local function environmentFunction(name)
      local value = environment and rawget(environment, name) or nil
      if type(value) ~= "function" then
        value = rawget(_G, name)
      end
      return type(value) == "function" and value or nil
    end
    local getCustomAsset = environmentFunction("getcustomasset") or environmentFunction("getsynasset")
    local writeFile = environmentFunction("writefile")
    local isFile = environmentFunction("isfile")
    local isFolder = environmentFunction("isfolder")
    local makeFolder = environmentFunction("makefolder")
    local requestFunction = environmentFunction("request") or environmentFunction("http_request")
    if not requestFunction and environment and type(environment.syn) == "table" and type(environment.syn.request) == "function" then
      requestFunction = environment.syn.request
    end
    if getCustomAsset and writeFile then
      if isFolder and makeFolder then
        local okRoot, rootExists = pcall(isFolder, "Violet")
        if not okRoot or not rootExists then
          pcall(makeFolder, "Violet")
        end
        local okAssets, assetsExist = pcall(isFolder, "Violet/Assets")
        if not okAssets or not assetsExist then
          pcall(makeFolder, "Violet/Assets")
        end
      end
      local imagePath = "Violet/Assets/patrick_preview_345.png"
      local exists = false
      if isFile then
        local okExists, result = pcall(isFile, imagePath)
        exists = okExists and result == true
      end
      if not exists then
        local body
        if requestFunction then
          local okRequest, response = pcall(requestFunction, {
            Url = previewImageUrl,
            Method = "GET",
          })
          if okRequest and type(response) == "table" then
            body = response.Body or response.body
          end
        end
        if type(body) ~= "string" or #body < 128 then
          local okHttp, result = pcall(function()
            return game:HttpGet(previewImageUrl)
          end)
          if okHttp then
            body = result
          end
        end
        if type(body) == "string" and #body >= 128 then
          local okWrite = pcall(writeFile, imagePath, body)
          exists = okWrite
        end
      end
      if exists or not isFile then
        local okAsset, asset = pcall(getCustomAsset, imagePath)
        if okAsset and type(asset) == "string" and asset ~= "" then
          previewImageAsset = asset
        end
      end
    end
  end
  local holder = create("Frame", {
    Parent = section.Content,
    Name = "ESPPreview",
    Size = UDim2.new(1, 0, 0, (explicitHeight or 360) + previewBottomExtension),
    BackgroundColor3 = theme.section,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
  })
  corner(holder, 2)
  stroke(holder, theme.outlineSoft, 0.58, 1)
  local previewBackground = create("Frame", {
    Parent = holder,
    Name = "PreviewBackground",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = theme.section,
    BorderSizePixel = 0,
    ZIndex = 1,
  })
  corner(previewBackground, 2)
  create("UIGradient", {
    Parent = previewBackground,
    Rotation = 90,
    Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, lighten(section.library.accent, 0.05)),
      ColorSequenceKeypoint.new(0.52, theme.section),
      ColorSequenceKeypoint.new(1, darken(theme.section, 0.12)),
    }),
  })
  local viewport = create("ViewportFrame", {
    Parent = holder,
    Name = "Viewport",
    Position = UDim2.fromOffset(10, 7),
    Size = UDim2.new(1, -20, 0, math.max(196, (explicitHeight or 360) - 52)),
    BackgroundColor3 = theme.section,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ImageColor3 = Color3.fromRGB(255, 255, 255),
    ImageTransparency = 1,
    Ambient = Color3.fromRGB(255, 255, 255),
    LightColor = Color3.fromRGB(255, 255, 255),
    LightDirection = Vector3.new(0, -0.05, -1),
    Active = false,
    ClipsDescendants = false,
    ZIndex = 2,
  })
  local patrickClip = create("Frame", {
    Parent = viewport,
    Name = "NettspendVisibleBounds",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 6,
  })
  local patrickImage = create("ImageLabel", {
    Parent = patrickClip,
    Name = "NettspendImage",
    AnchorPoint = Vector2.zero,
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromOffset(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = previewImageAsset,
    ImageColor3 = Color3.fromRGB(255, 255, 255),
    ImageTransparency = 0,
    ScaleType = Enum.ScaleType.Stretch,
    ZIndex = 6,
  })
  local previewTopSafeMargin = 5
  local previewBottomSafeMargin = 5
  local previewSideSafeMargin = 2
  local lastPatrickLayoutSignature = nil

  local function updatePatrickImageLayout()
    if not holder.Parent or not viewport.Parent or not patrickClip.Parent or not patrickImage.Parent then
      return
    end
    local viewportSize = viewport.AbsoluteSize
    local holderSize = holder.AbsoluteSize
    if viewportSize.X <= 4 or viewportSize.Y <= 4 or holderSize.Y <= 4 then
      return
    end
    local layoutSignature = string.format("%d:%d", math.floor(viewportSize.X + 0.5), math.floor(viewportSize.Y + 0.5))
    if lastPatrickLayoutSignature == layoutSignature then
      return
    end
    lastPatrickLayoutSignature = layoutSignature
    local cropAspect = previewCropSize.X / math.max(previewCropSize.Y, 1)
    local maxWidth = math.max(1, viewportSize.X - previewSideSafeMargin * 2)
    local maxHeight = math.max(1, viewportSize.Y - previewTopSafeMargin - previewBottomSafeMargin)
    local finalHeight = maxHeight
    local finalWidth = finalHeight * cropAspect
    if finalWidth > maxWidth then
      finalWidth = maxWidth
      finalHeight = finalWidth / math.max(cropAspect, 0.001)
    end
    finalWidth = math.max(1, math.floor(finalWidth + 0.5))
    finalHeight = math.max(1, math.floor(finalHeight + 0.5))
    local centerYInViewport = previewTopSafeMargin + finalHeight * 0.5
    patrickClip.Size = UDim2.fromOffset(finalWidth, finalHeight)
    patrickClip.Position = UDim2.fromOffset(
      math.floor(viewportSize.X * 0.5 + 0.5),
      math.floor(centerYInViewport + 0.5)
    )
    local imageScale = finalHeight / math.max(previewCropSize.Y, 1)
    patrickImage.Size = UDim2.fromOffset(
      math.ceil(previewSourceSize.X * imageScale),
      math.ceil(previewSourceSize.Y * imageScale)
    )
    patrickImage.Position = UDim2.fromOffset(
      -math.floor(previewCropOffset.X * imageScale + 0.5),
      -math.floor(previewCropOffset.Y * imageScale + 0.5)
    )
  end
  local camera = create("Camera", {
    Parent = viewport,
    FieldOfView = tonumber(options.FieldOfView or options.fieldOfView) or 28,
  })
  viewport.CurrentCamera = camera
  local world = create("WorldModel", {
    Parent = viewport,
    Name = "PreviewWorld",
  })
  local keyLightPart = create("Part", {
    Parent = world,
    Name = "KeyLight",
    Anchored = true,
    CanCollide = false,
    CanTouch = false,
    CanQuery = false,
    Transparency = 1,
    Size = Vector3.new(1, 1, 1),
    Position = Vector3.new(-3, 4, 5),
  })
  create("PointLight", {
    Parent = keyLightPart,
    Brightness = 8,
    Range = 54,
    Color = Color3.fromRGB(255, 255, 255),
    Shadows = false,
  })
  local fillLightPart = create("Part", {
    Parent = world,
    Name = "FillLight",
    Anchored = true,
    CanCollide = false,
    CanTouch = false,
    CanQuery = false,
    Transparency = 1,
    Size = Vector3.new(1, 1, 1),
    Position = Vector3.new(4, 2, 2),
  })
  create("PointLight", {
    Parent = fillLightPart,
    Brightness = 5,
    Range = 48,
    Color = Color3.fromRGB(230, 235, 255),
    Shadows = false,
  })
  local frontLightPart = create("Part", {
    Parent = world,
    Name = "FrontLight",
    Anchored = true,
    CanCollide = false,
    CanTouch = false,
    CanQuery = false,
    Transparency = 1,
    Size = Vector3.new(1, 1, 1),
    Position = Vector3.new(0, 3, 8),
  })
  create("PointLight", {
    Parent = frontLightPart,
    Brightness = 6,
    Range = 56,
    Color = Color3.fromRGB(255, 244, 244),
    Shadows = false,
  })
  local overlay = create("Frame", {
    Parent = holder,
    Name = "PreviewOverlay",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    ZIndex = 20,
  })
  local currentModel = nil
  local idleTrack = nil
  local buildToken = 0
  local modelRotation = 180
  local rotatingModel = false
  local rotationInput = nil
  local rotationStartX = 0
  local rotationStartAngle = 180
  local automaticRotationSpeed = 18
  local previewController = nil
  local previewData = nil
  local previewReady = false
  local lastLayoutSignature = nil
  local previewIconUrl = "rbxassetid://117005477469687"
  local previewIconLoading = true

  local function normalizePreviewAssetId(value, fallback)
    local asset = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if asset == "" then
      return fallback
    end
    if asset:match("^%d+$") then
      return "rbxassetid://" .. asset
    end
    if asset:match("^rbxassetid://%d+$") or asset:match("^https?://") then
      return asset
    end
    local numeric = asset:match("(%d+)")
    return numeric and ("rbxassetid://" .. numeric) or fallback
  end
  local draggingElement = nil
  local dragElement = nil
  local dragOffset = nil
  local dragInput = nil
  local dragOriginalZIndex = nil
  local manualLayoutPositions = {}

  local function getRuntimeLibrary()
    local environment = (getgenv and getgenv()) or _G
    return environment.Library or rawget(_G, "Library") or Library
  end

  local function destroyAvatarOnly()
    if idleTrack then
      pcall(function()
        idleTrack:Stop(0)
      end)
      idleTrack = nil
    end
    if currentModel then
      currentModel:Destroy()
      currentModel = nil
    end
  end

  local function cleanModel(model)
    local descendants = model:GetDescendants()
    for index = 1, #descendants do
      local descendant = descendants[index]
      if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Tool") then
        descendant:Destroy()
      elseif descendant:IsA("BasePart") then
        descendant.CanCollide = false
        descendant.CanTouch = false
        descendant.CanQuery = false
        descendant.CastShadow = false
        descendant.Massless = true
        descendant.Anchored = true
        descendant.Transparency = 0
        descendant.Reflectance = 0
        descendant.Material = Enum.Material.SmoothPlastic
        pcall(function()
          descendant.LocalTransparencyModifier = 0
        end)
      elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
        descendant.Transparency = 0
      elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
        descendant.Enabled = false
      elseif descendant:IsA("Highlight") then
        descendant.Enabled = false
      elseif descendant:IsA("SurfaceAppearance") then
        descendant:Destroy()
      elseif descendant:IsA("Motor6D") then
        descendant.Transform = CFrame.new()
      end
    end
  end

  local function addOpaqueMeshBacking(model)
    local backingColor = options.ModelBackingColor or options.modelBackingColor or Color3.fromRGB(255, 157, 172)
    local originals = model:GetDescendants()
    for index = 1, #originals do
      local part = originals[index]
      if part:IsA("MeshPart") and part.Name ~= "PatrickOpaqueBacking" then
        local textureId = ""
        pcall(function()
          textureId = part.TextureID
        end)
        if type(textureId) == "string" and textureId ~= "" then
          local backing = part:Clone()
          backing.Name = "PatrickOpaqueBacking"
          backing.Parent = model
          backing.Color = backingColor
          backing.Material = Enum.Material.SmoothPlastic
          backing.Transparency = 0
          backing.Reflectance = 0
          backing.Size = backing.Size * 0.995
          pcall(function()
            backing.TextureID = ""
            backing.LocalTransparencyModifier = 0
          end)
          local backingDescendants = backing:GetDescendants()
          for childIndex = 1, #backingDescendants do
            local child = backingDescendants[childIndex]
            if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") then
              child:Destroy()
            elseif child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") or child:IsA("Highlight") then
              child:Destroy()
            end
          end
        end
      elseif part:IsA("BasePart") and part.Name ~= "PatrickOpaqueBacking" then
        local mesh = part:FindFirstChildOfClass("SpecialMesh")
        if mesh and type(mesh.TextureId) == "string" and mesh.TextureId ~= "" then
          local backing = part:Clone()
          backing.Name = "PatrickOpaqueBacking"
          backing.Parent = model
          backing.Color = backingColor
          backing.Material = Enum.Material.SmoothPlastic
          backing.Transparency = 0
          backing.Reflectance = 0
          backing.Size = backing.Size * 0.995
          pcall(function()
            backing.LocalTransparencyModifier = 0
          end)
          local backingMesh = backing:FindFirstChildOfClass("SpecialMesh")
          if backingMesh then
            backingMesh.TextureId = ""
            backingMesh.Scale = backingMesh.Scale * 0.995
          end
          local backingDescendants = backing:GetDescendants()
          for childIndex = 1, #backingDescendants do
            local child = backingDescendants[childIndex]
            if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") then
              child:Destroy()
            elseif child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") or child:IsA("Highlight") then
              child:Destroy()
            end
          end
        end
      end
    end
  end

  local function getRigType()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.RigType or Enum.HumanoidRigType.R15
  end

  local function createPreviewModel(rigType)
    local model = create("Model", {
      Name = "PatrickPreview",
    })
    local assetId = tostring(options.ModelId or options.modelId or "5443506954")
    local loadedAsset = nil
    local loadedObjects = nil
    pcall(function()
      if type(game.GetObjects) == "function" then
        loadedObjects = game:GetObjects("rbxassetid://" .. assetId)
      end
    end)
    if type(loadedObjects) == "table" then
      for index = 1, #loadedObjects do
        local object = loadedObjects[index]
        if typeof(object) == "Instance" then
          loadedAsset = object
          break
        end
      end
    end
    if loadedAsset then
      loadedAsset.Name = "PatrickAsset"
      loadedAsset.Parent = model
    else
      local body = create("Part", {
        Parent = model,
        Name = "PatrickMesh",
        Anchored = true,
        CanCollide = false,
        CanTouch = false,
        CanQuery = false,
        CastShadow = false,
        Transparency = 0,
        Size = Vector3.new(1.7, 3.05, 1.05),
        CFrame = CFrame.new(0, 1.525, 0),
        Color = Color3.fromRGB(255, 157, 172),
        Material = Enum.Material.SmoothPlastic,
      })
      pcall(function()
        create("SpecialMesh", {
          Parent = body,
          MeshType = Enum.MeshType.FileMesh,
          MeshId = "rbxassetid://" .. assetId,
          Scale = Vector3.new(0.06, 0.06, 0.06),
        })
      end)
    end
    cleanModel(model)
    addOpaqueMeshBacking(model)
    cleanModel(model)

    local function collectParts()
      local parts = {}
      local descendants = model:GetDescendants()
      for index = 1, #descendants do
        local descendant = descendants[index]
        if descendant:IsA("BasePart") then
          parts[#parts + 1] = descendant
        end
      end
      return parts
    end
    local parts = collectParts()
    if #parts == 0 then
      local body = create("Part", {
        Parent = model,
        Name = "PatrickFallback",
        Anchored = true,
        CanCollide = false,
        CanTouch = false,
        CanQuery = false,
        CastShadow = false,
        Transparency = 0,
        Size = Vector3.new(1.7, 3.05, 1.05),
        CFrame = CFrame.new(0, 1.525, 0),
        Color = Color3.fromRGB(255, 157, 172),
        Material = Enum.Material.SmoothPlastic,
      })
      parts = {body}
    end
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local sizeBase = math.max(boundsSize.Y, boundsSize.X * 1.18, boundsSize.Z * 1.55, 0.05)
    local targetSize = tonumber(options.ModelSize or options.modelSize) or 2.75
    local scaleFactor = math.clamp(targetSize / sizeBase, 0.002, 12)
    local scaled = false
    pcall(function()
      model:ScaleTo(scaleFactor)
      scaled = true
    end)
    if not scaled then
      local origin = boundsCFrame.Position
      for index = 1, #parts do
        local part = parts[index]
        part.Size = part.Size * scaleFactor
        part.CFrame = CFrame.new(origin + (part.Position - origin) * scaleFactor) * part.CFrame.Rotation
        local mesh = part:FindFirstChildOfClass("SpecialMesh")
        if mesh then
          mesh.Scale = mesh.Scale * scaleFactor
        end
      end
    end
    boundsCFrame, boundsSize = model:GetBoundingBox()
    local targetCenter = Vector3.new(0, boundsSize.Y * 0.5, 0)
    local delta = targetCenter - boundsCFrame.Position
    parts = collectParts()
    for index = 1, #parts do
      local part = parts[index]
      part.CFrame = part.CFrame + delta
      part.Anchored = true
      part.CanCollide = false
      part.CanTouch = false
      part.CanQuery = false
      part.CastShadow = false
      part.Massless = true
    end
    pcall(function()
      model.WorldPivot = CFrame.new(0, 0, 0)
    end)
    local primary = parts[1]
    if primary then
      model.PrimaryPart = primary
    end
    return model
  end

  local function playIdle(model, rigType)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
      return
    end
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.AutoRotate = false
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid.NameDisplayDistance = 0
    humanoid.HealthDisplayDistance = 0
    local tracks = humanoid:GetPlayingAnimationTracks()
    for index = 1, #tracks do
      local track = tracks[index]
      pcall(track.Stop, track, 0)
    end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
      animator = create("Animator", {Parent = humanoid})
    end
    local idleId = options.IdleAnimationId or options.idleAnimationId
    if not idleId then
      idleId = rigType == Enum.HumanoidRigType.R6 and 180435571 or 507766666
    end
    local animation = create("Animation", {
      AnimationId = "rbxassetid://" .. tostring(idleId),
    })
    local success, track = pcall(function()
      return animator:LoadAnimation(animation)
    end)
    animation:Destroy()
    if success and track then
      idleTrack = track
      idleTrack.Priority = Enum.AnimationPriority.Idle
      idleTrack.Looped = true
      idleTrack:Play(0.12, 1, 1)
    end
  end

  local function frameModel(model)
    if not model or not model.Parent then
      return
    end
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local viewportSize = viewport.AbsoluteSize
    local aspect = math.max(viewportSize.X / math.max(viewportSize.Y, 1), 0.55)
    local halfFov = math.rad(camera.FieldOfView * 0.5)
    local verticalDistance = boundsSize.Y / math.max(2 * math.tan(halfFov), 0.01)
    local horizontalDistance = boundsSize.X / math.max(2 * math.tan(halfFov) * aspect, 0.01)
    local distance = math.max(verticalDistance, horizontalDistance) * 1.48
    local target = boundsCFrame.Position + Vector3.new(0, boundsSize.Y * 0.04, 0)
    local cameraPosition = target + Vector3.new(0, 0, distance)
    camera.CFrame = CFrame.lookAt(cameraPosition, target)
  end

  local function ensurePreviewEsp()
    if previewReady and previewData and previewData.Objects and previewData.Objects.TargetHolder and previewData.Objects.TargetHolder.Parent then
      return previewController, previewData
    end
    local runtimeLibrary = getRuntimeLibrary()
    if not runtimeLibrary or type(runtimeLibrary.StartESP) ~= "function" then
      return nil, nil
    end
    local controller = runtimeLibrary.ESPController or runtimeLibrary:StartESP()
    if not controller or type(controller.InitEsp) ~= "function" then
      return nil, nil
    end
    previewController = controller
    previewData = {
      Objects = {},
      SkeletonSegments = {},
      SkeletonPoints = {},
      Health = 100,
      MaxHealth = 100,
      Armor = 0,
      MaxArmor = 100,
      CurrentTool = "M4",
      WeaponWorldModel = nil,
      WalkActive = false,
      JumpActive = false,
      Alive = true,
      IncludeAccessories = true,
    }
    controller:InitEsp(previewData, overlay)
    if previewIconUrl then
      previewData.IconUrl = previewIconUrl
      if previewData.Objects and previewData.Objects.PlayerIcon then
        previewData.Objects.PlayerIcon.Image = previewIconUrl
      end
    elseif not previewIconLoading then
      previewIconLoading = true
      task.spawn(function()
        local success, image = pcall(function()
          return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
        if success and type(image) == "string" and image ~= "" then
          previewIconUrl = image
          if previewData and previewData.Objects and previewData.Objects.PlayerIcon then
            previewData.IconUrl = image
            previewData.Objects.PlayerIcon.Image = image
          end
        end
      end)
    end
    local objects = previewData.Objects
    if objects and objects.TargetHolder then
      objects.TargetHolder.Name = "ESPPreviewObjects"
      objects.TargetHolder.ZIndex = 24
      local descendants = objects.TargetHolder:GetDescendants()
      for index = 1, #descendants do
        local object = descendants[index]
        if object:IsA("GuiObject") then
          object.ZIndex = math.max(object.ZIndex + 20, 24)
        end
      end
    end
    previewReady = true
    return previewController, previewData
  end

  local function updatePreviewHeight()
    local baseHeight
    if explicitHeight then
      baseHeight = explicitHeight
    else
      local width = section.Content.AbsoluteSize.X
      baseHeight = math.clamp(math.floor(width * 1.04), minimumHeight, maximumHeight)
    end
    holder.Size = UDim2.new(1, 0, 0, baseHeight + previewBottomExtension)
    viewport.Size = UDim2.new(1, -20, 0, math.max(196, baseHeight - 52))
    task.defer(function()
      updatePatrickImageLayout()
      if currentModel and currentModel.Parent then
        frameModel(currentModel)
      end
    end)
  end

  local function buildPreview()
    buildToken = buildToken + 1
    destroyAvatarOnly()
    patrickClip.Visible = true
    patrickImage.Visible = true
    patrickImage.Image = previewImageAsset
    patrickImage.ImageTransparency = 0
    task.defer(updatePatrickImageLayout)
  end

  local function layoutSignature(controller)
    local tableConfig = controller and controller.Table
    local layout = tableConfig and tableConfig.Layout
    if not layout then
      return ""
    end
    local parts = {}
    for key, entry in pairs(layout) do
      parts[#parts + 1] = tostring(key) .. ":" .. tostring(entry.Zone) .. ":" .. tostring(entry.Order)
    end
    table.sort(parts)
    return table.concat(parts, "|")
  end

  local function setBoxObjectSizes(objects, width, height)
    objects.TargetHolder.Size = UDim2.fromOffset(width, height)
    objects.BoxGlow.Size = UDim2.fromOffset(width, height)
    objects.BoxOutlineHolder.Position = UDim2.fromOffset(0, 0)
    objects.BoxOutlineHolder.Size = UDim2.fromOffset(width, height)
    objects.BoxInlineHolder.Position = UDim2.fromOffset(0, 0)
    objects.BoxInlineHolder.Size = UDim2.fromOffset(width, height)
    objects.BoxFill.Position = UDim2.fromOffset(0, 0)
    objects.BoxFill.Size = UDim2.fromOffset(width, height)
  end

  local function clampElementPosition(element, rawPosition)
    local overlaySize = overlay.AbsoluteSize
    local elementSize = element and element.AbsoluteSize or Vector2.zero
    local margin = 5
    local maxX = math.max(margin, overlaySize.X - elementSize.X - margin)
    local maxY = math.max(margin, overlaySize.Y - elementSize.Y - margin)
    return Vector2.new(
      math.clamp(rawPosition.X, margin, maxX),
      math.clamp(rawPosition.Y, margin, maxY)
    )
  end

  local function applyManualLayoutPositions(controller, data)
    local objects = data and data.Objects
    local target = objects and objects.TargetHolder
    if not target or not target.Parent or not overlay.Parent then
      return
    end
    local overlaySize = overlay.AbsoluteSize
    if overlaySize.X <= 0 or overlaySize.Y <= 0 then
      return
    end

    local function measureBounds()
      local minX = math.huge
      local minY = math.huge
      local maxX = -math.huge
      local maxY = -math.huge
      local found = false

      local function include(guiObject)
        if not guiObject or not guiObject:IsA("GuiObject") or guiObject.Visible == false then
          return
        end
        local name = guiObject.Name
        if name == "BoxGlow" or name == "BoxFill" then
          return
        end
        local size = guiObject.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then
          return
        end
        local localPosition = guiObject.AbsolutePosition - overlay.AbsolutePosition
        minX = math.min(minX, localPosition.X)
        minY = math.min(minY, localPosition.Y)
        maxX = math.max(maxX, localPosition.X + size.X)
        maxY = math.max(maxY, localPosition.Y + size.Y)
        found = true
      end
      include(target)
      local descendants = target:GetDescendants()
      for index = 1, #descendants do
        include(descendants[index])
      end
      return found, minX, minY, maxX, maxY
    end
    local margin = 6
    for _ = 1, 3 do
      local found, minX, minY, maxX, maxY = measureBounds()
      if not found then
        return
      end
      local shiftX = 0
      local shiftY = 0
      if minX < margin then
        shiftX = margin - minX
      elseif maxX > overlaySize.X - margin then
        shiftX = (overlaySize.X - margin) - maxX
      end
      if minY < margin then
        shiftY = margin - minY
      elseif maxY > overlaySize.Y - margin then
        shiftY = (overlaySize.Y - margin) - maxY
      end
      if shiftX == 0 and shiftY == 0 then
        break
      end
      local clipPosition = patrickClip.Position
      patrickClip.Position = UDim2.fromOffset(
        math.floor(clipPosition.X.Offset + shiftX + 0.5),
        math.floor(clipPosition.Y.Offset + shiftY + 0.5)
      )
      local current = target.Position
      target.Position = UDim2.fromOffset(
        math.floor(current.X.Offset + shiftX + 0.5),
        math.floor(current.Y.Offset + shiftY + 0.5)
      )
    end
  end

  local function calculatePreviewBox(model, tableConfig)
    local imageSize = patrickClip.AbsoluteSize
    if imageSize.X <= 1 or imageSize.Y <= 1 then
      return nil
    end
    local holderPosition = holder.AbsolutePosition
    local imagePosition = patrickClip.AbsolutePosition
    local boxX = math.floor(imagePosition.X - holderPosition.X + 0.5)
    local boxY = math.floor(imagePosition.Y - holderPosition.Y + 0.5)
    local boxWidth = math.max(1, math.floor(imageSize.X + 0.5))
    local boxHeight = math.max(1, math.floor(imageSize.Y + 0.5))
    return boxWidth, boxHeight, boxX, boxY
  end

  local function projectPreviewPoint(position)
    if not position then
      return nil
    end
    local viewportSize = viewport.AbsoluteSize
    if viewportSize.X <= 4 or viewportSize.Y <= 4 then
      return nil
    end
    local localPoint = camera.CFrame:PointToObjectSpace(position)
    local depth = -localPoint.Z
    if depth <= 0.03 then
      return nil
    end
    local halfFov = math.tan(math.rad(camera.FieldOfView) * 0.5)
    local focal = (viewportSize.Y * 0.5) / math.max(halfFov, 0.001)
    local holderPosition = holder.AbsolutePosition
    local viewportPosition = viewport.AbsolutePosition
    local screenX = viewportPosition.X - holderPosition.X + viewportSize.X * 0.5 + (localPoint.X * focal) / depth
    local screenY = viewportPosition.Y - holderPosition.Y + viewportSize.Y * 0.5 - (localPoint.Y * focal) / depth
    if screenX ~= screenX or screenY ~= screenY then
      return nil
    end
    return Vector2.new(screenX, screenY)
  end

  local function updateSkeleton(controller, data, boxX, boxY, width, height)
    local objects = data.Objects
    local config = controller.Table.Skeleton
    local visible = config.Enabled == true and objects.SkeletonHolder ~= nil and currentModel ~= nil and currentModel.Parent ~= nil
    objects.SkeletonHolder.Visible = visible
    local lines = objects.SkeletonLines or {}
    if not visible then
      for index = 1, #lines do
        lines[index].Visible = false
      end
      return
    end
    local thickness = math.clamp(tonumber(config.Thickness) or 1, 1, 3)
    if data.SkeletonModel ~= currentModel then
      data.SkeletonModel = currentModel
      data.SkeletonSegments = controller:BuildSkeletonSegments(currentModel)
    end
    local segments = data.SkeletonSegments or {}
    local points = data.SkeletonPoints or {}
    data.SkeletonPoints = points
    table.clear(points)

    local function project(node)
      local cached = points[node]
      if cached ~= nil then
        return cached ~= false and cached or nil
      end
      local worldPosition = controller:ResolveSkeletonNode(node)
      local projected = worldPosition and projectPreviewPoint(worldPosition) or nil
      points[node] = projected or false
      return projected
    end
    for index = 1, #segments do
      local line = lines[index]
      if line then
        line.BackgroundColor3 = config.Color
        local segment = segments[index]
        controller:SetSkeletonLine(line, project(segment[1]), project(segment[2]), boxX, boxY, thickness)
      end
    end
    for index = #segments + 1, #lines do
      lines[index].Visible = false
    end
  end
  local previewLastBoxWidth = 1
  local previewLastBoxHeight = 1

  local function updateExactEspOverlay()
    local controller, data = ensurePreviewEsp()
    if not controller or not data or not data.Objects then
      return
    end
    local objects = data.Objects
    local tableConfig = controller.Table
    local boxesConfig = tableConfig.Boxes
    local textsConfig = tableConfig.Texts
    local barsConfig = tableConfig.Bars
    local width = math.max(1, holder.AbsoluteSize.X)
    local height = math.max(1, holder.AbsoluteSize.Y)
    local boxWidth, boxHeight, boxX, boxY = calculatePreviewBox(currentModel, tableConfig)
    if not boxWidth then
      boxWidth = math.clamp(math.floor(width * 0.33), 76, 118)
      boxHeight = math.clamp(math.floor((height - previewExtraBottom) * 0.70), 134, math.max(135, height - 92))
      boxX = math.floor((width - boxWidth) * 0.5)
      boxY = math.floor(((height - previewExtraBottom) - boxHeight) * 0.5)
    end
    previewLastBoxWidth = boxWidth
    previewLastBoxHeight = boxHeight
    local now = os.clock()
    local phase = (now % 6) / 6
    local ratio = phase < 0.5 and (1 - phase * 2) or ((phase - 0.5) * 2)
    local health = math.floor(ratio * 100 + 0.5)
    data.Health = health
    data.MaxHealth = 100
    data.CurrentTool = "M4"
    data.WalkActive = false
    data.JumpActive = false
    data.Alive = true
    objects.TargetHolder.Visible = tableConfig.Enabled == true
    if not objects.TargetHolder.Visible then
      return
    end
    local signature = layoutSignature(controller)
    local clampState = table.concat({
      signature,
      tostring(textsConfig.Name.Enabled),
      tostring(textsConfig.Name.Icon),
      tostring(textsConfig.Distance.Enabled),
      tostring(textsConfig.Weapon.Enabled),
      tostring(textsConfig.Weapon.Icon),
      tostring(textsConfig.Flags.Enabled),
      tostring(barsConfig["Health Bar"].Enabled),
      tostring(barsConfig["Armor Bar"].Enabled),
    }, ":")
    local layoutChanged = not draggingElement and clampState ~= lastLayoutSignature
    if layoutChanged then
      controller:ApplyLayout(data)
      lastLayoutSignature = clampState
    end
    objects.TargetHolder.Position = UDim2.fromOffset(boxX, boxY)
    setBoxObjectSizes(objects, boxWidth, boxHeight)
    updateSkeleton(controller, data, boxX, boxY, boxWidth, boxHeight)
    if boxesConfig.Enabled then
      objects.BoxGlow.ImageTransparency = boxesConfig["Box Glow"].Enabled and 0 or 1
      objects.BoxGlowGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, boxesConfig["Box Glow"].Top),
        ColorSequenceKeypoint.new(1, boxesConfig["Box Glow"].Bot),
      })
      objects.BoxGlowGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, boxesConfig["Box Glow"].Transparency[1]),
        NumberSequenceKeypoint.new(1, boxesConfig["Box Glow"].Transparency[2]),
      })
      objects.BoxOutlineHolder.Visible = true
      objects.BoxInlineHolder.Visible = true
      objects.BoxInlineGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, boxesConfig.Gradients.Top),
        ColorSequenceKeypoint.new(1, boxesConfig.Gradients.Bot),
      })
      objects.BoxFill.Visible = boxesConfig.Filled.Enabled == true
      objects.BoxFill.BackgroundTransparency = 0
      objects.BoxFill.ZIndex = 1
      patrickClip.ZIndex = 6
      patrickImage.ZIndex = 6
      objects.BoxFillGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, boxesConfig.Filled.Top),
        ColorSequenceKeypoint.new(1, boxesConfig.Filled.Bot),
      })
      local previewFillTopTransparency = math.max(boxesConfig.Filled.Transparency[1], 0.88)
      local previewFillBottomTransparency = math.max(boxesConfig.Filled.Transparency[2], 0.94)
      objects.BoxFillGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, previewFillTopTransparency),
        NumberSequenceKeypoint.new(1, previewFillBottomTransparency),
      })
    else
      objects.BoxGlow.ImageTransparency = 1
      objects.BoxOutlineHolder.Visible = false
      objects.BoxInlineHolder.Visible = false
      objects.BoxFill.Visible = false
    end
    local nameConfig = textsConfig.Name
    if previewIconUrl and data.IconUrl ~= previewIconUrl then
      data.IconUrl = previewIconUrl
    end
    local iconImage = nameConfig.ImageId or previewIconUrl or data.IconUrl
    local iconVisible = nameConfig.Icon == true and type(iconImage) == "string" and iconImage ~= ""
    objects.NameRow.Visible = nameConfig.Enabled or iconVisible
    objects.NameRow.ClipsDescendants = false
    objects.NameRow.AutomaticSize = Enum.AutomaticSize.XY
    objects.NameRow.Size = UDim2.fromOffset(0, 0)
    local nameLayout = objects.NameRow:FindFirstChildOfClass("UIListLayout")
    if nameLayout then
      nameLayout.Padding = UDim.new(0, 2)
      nameLayout.FillDirection = Enum.FillDirection.Horizontal
      nameLayout.VerticalAlignment = Enum.VerticalAlignment.Center
      nameLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    end
    objects.TargetName.Visible = nameConfig.Enabled
    objects.TargetName.LayoutOrder = 2
    objects.TargetName.Text = "nettspend"
    objects.TargetName.TextTruncate = Enum.TextTruncate.None
    objects.TargetName.AutomaticSize = Enum.AutomaticSize.XY
    objects.TargetName.Size = UDim2.fromOffset(0, 0)
    objects.TargetNameGradient.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, nameConfig.Top),
      ColorSequenceKeypoint.new(1, nameConfig.Bot),
    })
    objects.PlayerIcon.Visible = iconVisible
    objects.PlayerIcon.LayoutOrder = 1
    objects.PlayerIcon.Size = UDim2.fromOffset(18, 18)
    objects.PlayerIcon.ScaleType = Enum.ScaleType.Fit
    local iconLayout = tableConfig.Layout and tableConfig.Layout.Icon
    local iconAttachedToName = iconLayout and iconLayout.Zone == "Name"
    if iconAttachedToName and draggingElement ~= "Icon" and objects.PlayerIcon.Parent ~= objects.NameRow then
      objects.PlayerIcon.Parent = objects.NameRow
    end
    if iconVisible and objects.PlayerIcon.Image ~= iconImage then
      objects.PlayerIcon.Image = iconImage
    end
    local distanceConfig = textsConfig.Distance
    objects.Distance.Visible = distanceConfig.Enabled
    objects.Distance.Text = "42st"
    objects.DistanceGradient.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, distanceConfig.Top),
      ColorSequenceKeypoint.new(1, distanceConfig.Bot),
    })
    local flagsConfig = textsConfig.Flags
    objects.FlagsRow.Visible = flagsConfig.Enabled
    objects.IdleFlag.Visible = flagsConfig.Enabled
    objects.WalkFlag.Visible = false
    objects.JumpFlag.Visible = false
    local flagSequence = ColorSequence.new({
      ColorSequenceKeypoint.new(0, flagsConfig.Top),
      ColorSequenceKeypoint.new(1, flagsConfig.Bot),
    })
    objects.IdleFlag.Text = "Idle"
    objects.IdleFlagGradient.Color = flagSequence
    objects.WalkFlagGradient.Color = flagSequence
    objects.JumpFlagGradient.Color = flagSequence
    local healthConfig = barsConfig["Health Bar"]
    local armorConfig = barsConfig["Armor Bar"]
    objects.HealthBarOutline.Visible = healthConfig.Enabled
    objects.ArmorBarOutline.Visible = armorConfig.Enabled
    if healthConfig.Enabled then
      controller:UpdateBarLayout(data, "HealthBar", ratio, boxWidth, boxHeight)
      objects.HealthBarGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, healthConfig.Top),
        ColorSequenceKeypoint.new(0.5, healthConfig.Mid),
        ColorSequenceKeypoint.new(1, healthConfig.Bot),
      })
      objects.HealthBarText.Visible = healthConfig.Text == true
      objects.HealthBarText.Text = tostring(health)
    else
      objects.HealthBarText.Visible = false
    end
    if armorConfig.Enabled then
      controller:UpdateBarLayout(data, "ArmorBar", 1, boxWidth, boxHeight)
      objects.ArmorBarGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, armorConfig.Top),
        ColorSequenceKeypoint.new(0.5, armorConfig.Mid),
        ColorSequenceKeypoint.new(1, armorConfig.Bot),
      })
      objects.ArmorBarText.Visible = false
    else
      objects.ArmorBarText.Visible = false
    end
    local weaponConfig = textsConfig.Weapon
    objects.Weapon.Visible = weaponConfig.Enabled
    objects.Weapon.Text = "M4"
    objects.WeaponGradient.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, weaponConfig.Top),
      ColorSequenceKeypoint.new(1, weaponConfig.Bot),
    })
    if objects.WeaponImage then
      local runtimeLibrary = getRuntimeLibrary()
      local runtimeFlags = runtimeLibrary and runtimeLibrary.Flags
      local previewWeaponIcon = normalizePreviewAssetId(
        runtimeFlags and runtimeFlags.esp_preview_weapon_icon_id,
        "rbxassetid://87030448114840"
      )
      objects.WeaponImage.Image = previewWeaponIcon
      objects.WeaponImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
      objects.WeaponImage.ImageTransparency = 0
      objects.WeaponImage.ScaleType = Enum.ScaleType.Fit
      objects.WeaponImage.Size = UDim2.fromOffset(56, 32)
      objects.WeaponImage.Visible = weaponConfig.Enabled and weaponConfig.Icon ~= false
    end
    if layoutChanged then
      task.defer(function()
        if data == previewData and overlay.Parent and objects.TargetHolder and objects.TargetHolder.Parent then
          applyManualLayoutPositions(controller, data)
        end
      end)
    end
  end

  local function elementBounds(element)
    if not element or not element.Parent or not element.Visible then
      return nil
    end
    local found = false
    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge

    local function include(object)
      if not object or not object.Parent or not object:IsA("GuiObject") or object.Visible == false then
        return
      end
      local position = object.AbsolutePosition
      local size = object.AbsoluteSize
      if size.X <= 0 or size.Y <= 0 then
        return
      end
      minX = math.min(minX, position.X)
      minY = math.min(minY, position.Y)
      maxX = math.max(maxX, position.X + size.X)
      maxY = math.max(maxY, position.Y + size.Y)
      found = true
    end
    include(element)
    local descendants = element:GetDescendants()
    for index = 1, #descendants do
      include(descendants[index])
    end
    if not found then
      return nil
    end
    return minX, minY, maxX, maxY
  end

  local function layoutElementAt(position)
    local holderPosition = holder.AbsolutePosition
    local holderSize = holder.AbsoluteSize
    if position.X < holderPosition.X or position.X > holderPosition.X + holderSize.X or position.Y < holderPosition.Y or position.Y > holderPosition.Y + holderSize.Y then
      return nil, nil
    end
    local controller, data = ensurePreviewEsp()
    if not controller or not data or not data.Objects or type(controller.GetLayoutObjects) ~= "function" then
      return nil, nil
    end
    local elements = controller:GetLayoutObjects(data.Objects)
    local weaponImage = elements.WeaponImage
    if weaponImage and weaponImage.Visible and pointInside(position, weaponImage) then
      return "WeaponImage", weaponImage
    end
    local playerIcon = elements.Icon
    if playerIcon and playerIcon.Visible and pointInside(position, playerIcon) then
      return "Icon", playerIcon
    end
    local bestKey = nil
    local bestElement = nil
    local bestArea = nil
    for key, element in pairs(elements) do
      local dragKey = key
      local dragTarget = element
      if dragTarget and dragTarget.Visible then
        local left, top, right, bottom = elementBounds(dragTarget)
        if left then
          local margin = controller:IsBarKey(dragKey) and 18 or 14
          if dragKey == "Name" then
            margin = 24
          end
          left -= margin
          top -= margin
          right += margin
          bottom += margin
          if position.X >= left and position.X <= right and position.Y >= top and position.Y <= bottom then
            local area = math.max(1, right - left) * math.max(1, bottom - top)
            if not bestArea or area < bestArea then
              bestArea = area
              bestKey = dragKey
              bestElement = dragTarget
            end
          end
        end
      end
    end
    return bestKey, bestElement
  end

  local function nearestLayoutZone(position)
    local controller, data = ensurePreviewEsp()
    local target = data and data.Objects and data.Objects.TargetHolder
    if not target or not target.Parent then
      return "Top"
    end
    local left = target.AbsolutePosition.X
    local top = target.AbsolutePosition.Y
    local right = left + target.AbsoluteSize.X
    local bottom = top + target.AbsoluteSize.Y
    local third = target.AbsoluteSize.X / 3
    local safePosition = Vector2.new(position.X, position.Y)
    if safePosition.Y < top then
      if safePosition.X < left + third then
        return "TopLeft"
      elseif safePosition.X > right - third then
        return "TopRight"
      end
      return "Top"
    elseif safePosition.Y > bottom then
      if safePosition.X < left + third then
        return "BottomLeft"
      elseif safePosition.X > right - third then
        return "BottomRight"
      end
      return "Bottom"
    elseif safePosition.X < (left + right) * 0.5 then
      return "Left"
    end
    return "Right"
  end

  local function beginElementDrag(key, element, position)
    if not key or not element then
      return
    end
    draggingElement = key
    dragElement = element
    dragOriginalZIndex = element.ZIndex
    dragOffset = Vector2.new(position.X, position.Y) - element.AbsolutePosition
    local absolute = element.AbsolutePosition - overlay.AbsolutePosition
    element.Parent = overlay
    element.AnchorPoint = Vector2.zero
    local clampedPosition = clampElementPosition(element, absolute)
    element.Position = UDim2.fromOffset(clampedPosition.X, clampedPosition.Y)
    element.ZIndex = 220
  end

  local function moveElement(position)
    if not dragElement then
      return
    end
    local localPosition = Vector2.new(position.X, position.Y) - overlay.AbsolutePosition - dragOffset
    local clampedPosition = clampElementPosition(dragElement, localPosition)
    dragElement.Position = UDim2.fromOffset(clampedPosition.X, clampedPosition.Y)
  end

  local function finishElementDrag(position)
    local key = draggingElement
    if not key then
      return
    end
    local controller, data = ensurePreviewEsp()
    if controller and data and controller.Table and controller.Table.Layout[key] then
      local zone = nearestLayoutZone(position)
      if key == "Name" and data.Objects and data.Objects.TargetHolder then
        local holderLeft = data.Objects.TargetHolder.AbsolutePosition.X
        local holderTop = data.Objects.TargetHolder.AbsolutePosition.Y
        local holderRight = holderLeft + data.Objects.TargetHolder.AbsoluteSize.X
        local holderBottom = holderTop + data.Objects.TargetHolder.AbsoluteSize.Y
        if position.X >= holderLeft - 12 and position.X <= holderRight + 12 and position.Y >= holderTop - 12 and position.Y <= holderBottom + 12 then
          if position.Y <= holderTop + data.Objects.TargetHolder.AbsoluteSize.Y * 0.35 then
            zone = "Top"
          elseif position.Y >= holderBottom - data.Objects.TargetHolder.AbsoluteSize.Y * 0.35 then
            zone = "Bottom"
          elseif position.X < (holderLeft + holderRight) * 0.5 then
            zone = "Left"
          else
            zone = "Right"
          end
        end
      end
      local entry = controller.Table.Layout[key]
      entry.Zone = zone
      local runtimeLibrary = getRuntimeLibrary()
      local flags = runtimeLibrary and runtimeLibrary.Flags
      if flags then
        local prefix = "esp_layout_" .. string.lower(key)
        flags[prefix .. "_zone"] = zone
        flags[prefix .. "_order"] = entry.Order or 1
      end
      if dragElement and dragOriginalZIndex then
        dragElement.ZIndex = dragOriginalZIndex
      end
      if type(controller.ApplyAllLayouts) == "function" then
        controller:ApplyAllLayouts()
      end
      controller:ApplyLayout(data)
      lastLayoutSignature = layoutSignature(controller)
    end
    draggingElement = nil
    dragElement = nil
    dragOffset = nil
    dragOriginalZIndex = nil
    updateExactEspOverlay()
  end
  connect(UserInputService.InputBegan, function(input)
    if not holder.Parent then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    local key, element = layoutElementAt(input.Position)
    if key then
      dragInput = input
      beginElementDrag(key, element, input.Position)
    end
  end)
  connect(UserInputService.InputChanged, function(input)
    if not draggingElement then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    if dragInput and dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
      return
    end
    moveElement(input.Position)
  end)
  connect(UserInputService.InputEnded, function(input)
    if not draggingElement then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    if dragInput and dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
      return
    end
    finishElementDrag(input.Position)
    dragInput = nil
  end)
  connect(UserInputService.InputChanged, function(input)
    if not rotatingModel then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    if rotationInput and rotationInput.UserInputType == Enum.UserInputType.Touch and input ~= rotationInput then
      return
    end
    modelRotation = rotationStartAngle + (input.Position.X - rotationStartX) * 0.7
  end)
  connect(UserInputService.InputEnded, function(input)
    if input == rotationInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
      rotatingModel = false
      rotationInput = nil
    end
  end)

  local function updateSmoothPreviewHealth()
    local controller = previewController
    local data = previewData
    local objects = data and data.Objects
    local tableConfig = controller and controller.Table
    local bars = tableConfig and tableConfig.Bars
    local healthConfig = bars and bars["Health Bar"]
    if not controller or not objects or not healthConfig or not healthConfig.Enabled then
      return
    end
    if not objects.TargetHolder or not objects.TargetHolder.Visible or not objects.HealthBarOutline or not objects.HealthBarOutline.Visible then
      return
    end
    local now = os.clock()
    local phase = (now % 6) / 6
    local ratio = phase < 0.5 and (1 - phase * 2) or ((phase - 0.5) * 2)
    local health = math.floor(ratio * 100 + 0.5)
    data.Health = health
    data.MaxHealth = 100
    controller:UpdateBarLayout(data, "HealthBar", ratio, previewLastBoxWidth, previewLastBoxHeight)
    if objects.HealthBarText and healthConfig.Text == true then
      objects.HealthBarText.Text = tostring(health)
    end
  end
  local previewUpdateAccumulator = 0
  local previewUpdateInterval = 1 / 12
  connect(RunService.RenderStepped, function(deltaTime)
    if not holder.Parent or holder.AbsoluteSize.X <= 0 or holder.AbsoluteSize.Y <= 0 or section.library.visible == false then
      return
    end
    updateSmoothPreviewHealth()
    previewUpdateAccumulator += deltaTime
    if previewUpdateAccumulator < previewUpdateInterval then
      return
    end
    local elapsed = previewUpdateAccumulator
    previewUpdateAccumulator = 0
    if currentModel and currentModel.Parent then
      if not rotatingModel then
        modelRotation = (modelRotation + automaticRotationSpeed * elapsed) % 360
      end
      currentModel:PivotTo(CFrame.Angles(0, math.rad(modelRotation), 0))
    end
    updateExactEspOverlay()
    updateSmoothPreviewHealth()
  end)
  connect(section.Content:GetPropertyChangedSignal("AbsoluteSize"), updatePreviewHeight)
  connect(holder:GetPropertyChangedSignal("AbsoluteSize"), function()
    lastLayoutSignature = nil
    lastPatrickLayoutSignature = nil
    updatePatrickImageLayout()
  end)
  connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), function()
    lastLayoutSignature = nil
    lastPatrickLayoutSignature = nil
    updatePatrickImageLayout()
    if currentModel and currentModel.Parent then
      frameModel(currentModel)
    end
  end)
  connect(LocalPlayer.CharacterAdded, function()
    task.delay(0.8, function()
      if holder.Parent then
        buildPreview()
      end
    end)
  end)
  pcall(function()
    connect(LocalPlayer.CharacterAppearanceLoaded, function()
      task.delay(0.25, function()
        if holder.Parent then
          buildPreview()
        end
      end)
    end)
  end)
  task.defer(updatePreviewHeight)
  buildPreview()
  task.defer(updateExactEspOverlay)

  local function stopCurrent()
    buildToken = buildToken + 1
    destroyAvatarOnly()
    if previewData and previewData.Objects and previewData.Objects.TargetHolder then
      previewData.Objects.TargetHolder:Destroy()
    end
    previewData = nil
    previewReady = false
  end
  return {
    Object = holder,
    Overlay = overlay,
    Viewport = viewport,
    Camera = camera,
    World = world,
    Refresh = updateExactEspOverlay,
    Destroy = stopCurrent,
  }
end

function library:Button(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  if type(options) == "string" then
    options = {Name = options}
  end
  options = options or {}
  local disabled = options.Disabled == true
  local button = create("TextButton", {
    Parent = section.Content,
    Size = UDim2.new(1, 0, 0, options.Height or 27),
    BackgroundColor3 = Color3.fromRGB(48, 49, 55),
    BorderSizePixel = 0,
    Text = tostring(options.Name or options.Text or "Button"),
    TextColor3 = theme.white,
    TextSize = 13,
    Font = Enum.Font.ArialBold,
    AutoButtonColor = false,
  })
  styleButton(button, section, options)
  if not disabled then
    button.Activated:Connect(function()
      local flash = create("Frame", {
        Parent = button,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.white,
        BackgroundTransparency = 0.78,
        BorderSizePixel = 0,
        ZIndex = button.ZIndex + 4,
      })
      corner(flash, 1)
      tween(flash, {BackgroundTransparency = 1}, 0.15, Enum.EasingStyle.Quad)
      task.delay(0.16, function()
        if flash.Parent then
          flash:Destroy()
        end
      end)
      fire(options.Callback or options.callback)
    end)
  end
  return button
end

function library:ButtonRow(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  options = options or {}
  local buttons = options.Buttons or options.buttons or {}
  local row = controlBase(section, options.Height or 27, false)
  create("UIListLayout", {
    Parent = row,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 5),
  })
  local objects = table.create(#buttons)
  local count = math.max(#buttons, 1)
  for index = 1, #buttons do
    local data = buttons[index]
    if type(data) == "string" then
      data = {Name = data}
    end
    local widthScale = data.WidthScale or (1 / count)
    local offset = -math.floor((5 * math.max(count - 1, 0)) / count)
    local disabled = data.Disabled == true
    local button = create("TextButton", {
      Parent = row,
      Size = UDim2.new(widthScale, offset, 1, 0),
      BackgroundColor3 = theme.control,
      BorderSizePixel = 0,
      Text = tostring(data.Name or data.Text or ("Button " .. index)),
      TextColor3 = theme.white,
      TextSize = 12,
      Font = Enum.Font.ArialBold,
      AutoButtonColor = false,
      LayoutOrder = index,
    })
    styleButton(button, section, data)
    if not disabled then
      button.Activated:Connect(function()
        fire(data.Callback or data.callback, index)
      end)
    end
    objects[#objects + 1] = button
  end
  return objects
end

function library:Textbox(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  options = options or {}
  local hasName = options.Name ~= nil or options.name ~= nil
  local row = controlBase(section, hasName and 44 or 27, false)
  if hasName then
    local topLabel = controlLabel(row, options.Name or options.name, UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 0), true)
    topLabel.TextSize = 12
  end
  local box = create("TextBox", {
    Parent = row,
    Position = UDim2.fromOffset(0, hasName and 17 or 0),
    Size = UDim2.new(1, 0, 0, 27),
    BackgroundColor3 = theme.control,
    BorderSizePixel = 0,
    Text = tostring(options.Default or options.default or ""),
    PlaceholderText = tostring(options.Placeholder or options.placeholder or "Type here..."),
    PlaceholderColor3 = theme.textDark,
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = options.ClearTextOnFocus == true,
  })
  corner(box, 1)
  local boxStroke = stroke(box, theme.outline, 0, 1)
  padding(box, 7, 7, 0, 0)
  local flag = options.Flag or options.flag
  if flag then
    section.library.flags[flag] = box.Text
  end
  box.MouseEnter:Connect(function()
    tween(box, {BackgroundColor3 = theme.controlHover}, 0.07, Enum.EasingStyle.Linear)
  end)
  box.MouseLeave:Connect(function()
    if not box:IsFocused() then
      tween(box, {BackgroundColor3 = theme.control}, 0.07, Enum.EasingStyle.Linear)
    end
  end)
  box.Focused:Connect(function()
    tween(box, {BackgroundColor3 = theme.controlHover}, 0.07, Enum.EasingStyle.Linear)
    tween(boxStroke, {Color = section.library.accent}, 0.08, Enum.EasingStyle.Linear)
  end)
  box.FocusLost:Connect(function(enterPressed)
    tween(box, {BackgroundColor3 = theme.control}, 0.08, Enum.EasingStyle.Linear)
    tween(boxStroke, {Color = theme.outline}, 0.08, Enum.EasingStyle.Linear)
    if flag then
      section.library.flags[flag] = box.Text
    end
    fire(options.Callback or options.callback, box.Text, enterPressed)
  end)
  local control = {
    Object = box,
    Set = function(_, value)
      box.Text = tostring(value or "")
      if flag then
        section.library.flags[flag] = box.Text
      end
      fire(options.Callback or options.callback, box.Text, false)
    end,
    Get = function()
      return box.Text
    end,
  }
  section.library:RegisterOption(flag, control)
  return control
end

function library:Dropdown(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  options = options or {}
  local choices = options.Options or options.options or options.Items or options.items or {"Option"}
  local multi = options.Multi == true or options.multi == true
  local default = options.Default
  if default == nil then
    default = options.default
  end
  if default == nil and not multi then
    default = choices[1]
  end
  local flag = options.Flag or options.flag
  local row = controlBase(section, 44, false)
  local topLabel = controlLabel(row, options.Name or options.name or "Dropdown", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 0), true)
  topLabel.TextSize = 12
  local button = create("TextButton", {
    Parent = row,
    Position = UDim2.fromOffset(0, 17),
    Size = UDim2.new(1, 0, 0, 27),
    BackgroundColor3 = theme.white,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ClipsDescendants = true,
    ZIndex = 4,
  })
  corner(button, 1)
  local buttonStroke = stroke(button, theme.outline, 0.55, 1)
  create("UIGradient", {
    Parent = button,
    Rotation = 90,
    Color = subtleControlSequence(),
  })
  local hoverOverlay = create("Frame", {
    Parent = button,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = theme.white,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 5,
  })
  corner(hoverOverlay, 1)
  local selectedLabel = create("TextLabel", {
    Parent = button,
    Position = UDim2.fromOffset(8, 0),
    Size = UDim2.new(1, -31, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 6,
  })
  local arrow = create("ImageLabel", {
    Parent = button,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -13, 0.5, 0),
    Size = UDim2.fromOffset(12, 12),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://101007429951147",
    ImageColor3 = theme.textMuted,
    Rotation = 0,
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 6,
  })
  local selectedValues = {}
  local choiceLookup = {}
  local current = nil
  local openPopupObject = nil
  local control = {}

  local function rebuildChoiceLookup()
    table.clear(choiceLookup)
    for index = 1, #choices do
      choiceLookup[choices[index]] = true
    end
  end
  rebuildChoiceLookup()

  local function selectionList()
    local values = table.create(#choices)
    for index = 1, #choices do
      local value = choices[index]
      if selectedValues[value] then
        values[#values + 1] = value
      end
    end
    return values
  end

  local function updateDisplay()
    if multi then
      local values = selectionList()
      if #values == 0 then
        selectedLabel.Text = tostring(options.EmptyText or options.emptyText or "None")
      else
        local labels = table.create(#values)
        for index = 1, #values do
          labels[index] = tostring(values[index])
        end
        selectedLabel.Text = table.concat(labels, ", ")
      end
      if flag then
        section.library.flags[flag] = table.clone(values)
      end
    else
      selectedLabel.Text = tostring(current or "")
      if flag then
        section.library.flags[flag] = current
      end
    end
  end

  local function set(value, invoke)
    if multi then
      table.clear(selectedValues)
      if typeof(value) == "table" then
        for index = 1, #value do
          local item = value[index]
          if choiceLookup[item] then
            selectedValues[item] = true
          end
        end
      elseif value ~= nil and choiceLookup[value] then
        selectedValues[value] = true
      end
      updateDisplay()
      if invoke ~= false then
        fire(options.Callback or options.callback, selectionList())
      end
    else
      current = value
      updateDisplay()
      if invoke ~= false then
        fire(options.Callback or options.callback, value)
      end
    end
  end
  if multi then
    if typeof(default) == "table" then
      set(default, false)
    elseif default ~= nil then
      set({default}, false)
    else
      set({}, false)
    end
  else
    set(default, false)
  end

  local function closeDropdown()
    if openPopupObject and section.library.currentPopup == openPopupObject then
      section.library:ClosePopup()
    elseif openPopupObject and openPopupObject.Close then
      openPopupObject:Close()
    end
  end

  local function openDropdown()
    if openPopupObject and openPopupObject.Frame and openPopupObject.Frame.Parent then
      closeDropdown()
      return
    end
    section.library:ClosePopup()
    local optionHeight = isMobileDevice and 34 or 30
    local optionGap = 2
    local popupPadding = 5
    local desiredHeight = (#choices * optionHeight) + (math.max(#choices - 1, 0) * optionGap) + (popupPadding * 2)
    local maxHeight = options.MaxHeight or options.maxHeight or (isMobileDevice and 250 or 214)
    local popupLayer = section.window.PopupLayer
    local popupFrame = create("CanvasGroup", {
      Parent = popupLayer,
      Name = "DropdownPopup",
      AnchorPoint = Vector2.new(0, 0),
      Position = UDim2.fromOffset(0, 0),
      Size = UDim2.fromOffset(0, 0),
      BackgroundColor3 = Color3.fromRGB(31, 32, 38),
      BorderSizePixel = 0,
      Active = true,
      ClipsDescendants = true,
      GroupTransparency = 1,
      ZIndex = 5000,
    })
    corner(popupFrame, 1)
    stroke(popupFrame, theme.outlineSoft, 0.50, 1)
    local popupScale = create("UIScale", {
      Parent = popupFrame,
      Scale = 0.97,
    })
    local scrolling = create("ScrollingFrame", {
      Parent = popupFrame,
      Position = UDim2.fromOffset(0, 0),
      Size = UDim2.fromScale(1, 1),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      CanvasSize = UDim2.fromOffset(0, 0),
      AutomaticCanvasSize = Enum.AutomaticSize.Y,
      ScrollBarThickness = 0,
      ScrollBarImageColor3 = section.library.accent,
      ScrollBarImageTransparency = 0.48,
      VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
      ZIndex = 5001,
    })
    create("UIListLayout", {
      Parent = scrolling,
      FillDirection = Enum.FillDirection.Vertical,
      SortOrder = Enum.SortOrder.LayoutOrder,
      Padding = UDim.new(0, optionGap),
    })
    padding(scrolling, popupPadding, popupPadding, popupPadding, popupPadding)
    local popup = {
      Frame = popupFrame,
      Anchor = button,
      Closed = false,
      FollowConnection = nil,
    }

    local function reposition()
      if popup.Closed or not popupFrame.Parent or not button.Parent or not popupLayer.Parent then
        return
      end
      local layerPosition = popupLayer.AbsolutePosition
      local layerSize = popupLayer.AbsoluteSize
      local anchorPosition = button.AbsolutePosition
      local anchorSize = button.AbsoluteSize
      local px = math.floor((anchorPosition.X - layerPosition.X) + 0.5)
      local py = math.floor((anchorPosition.Y - layerPosition.Y) + anchorSize.Y + 2.5)
      local width = math.max(math.floor(anchorSize.X + 0.5), 100)
      local availableBelow = math.max(optionHeight + 8, layerSize.Y - py - 4)
      local height = math.min(desiredHeight, maxHeight, availableBelow)
      popupFrame.Position = UDim2.fromOffset(px, py)
      popupFrame.Size = UDim2.fromOffset(width, height)
      scrolling.ScrollBarThickness = desiredHeight > height and (isMobileDevice and 4 or 2) or 0
    end
    function popup:Close()
      if self.Closed then
        return
      end
      self.Closed = true
      if self.FollowConnection then
        self.FollowConnection:Disconnect()
        self.FollowConnection = nil
      end
      if openPopupObject == self then
        openPopupObject = nil
      end
      tween(arrow, {Rotation = 0, ImageColor3 = theme.textMuted}, 0.12, Enum.EasingStyle.Quad)
      tween(buttonStroke, {Color = theme.outline, Transparency = 0.55}, 0.10, Enum.EasingStyle.Sine)
      if popupFrame.Parent then
        tween(popupFrame, {GroupTransparency = 1}, 0.11, Enum.EasingStyle.Quad)
        tween(popupScale, {Scale = 0.97}, 0.11, Enum.EasingStyle.Quad)
        task.delay(0.115, function()
          if popupFrame.Parent then
            popupFrame:Destroy()
          end
        end)
      end
    end
    local refreshers = table.create(#choices)
    for index = 1, #choices do
      local value = choices[index]
      local hovering = false
      local optionButton = create("TextButton", {
        Parent = scrolling,
        Size = UDim2.new(1, 0, 0, optionHeight),
        BackgroundColor3 = section.library.accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = index,
        ZIndex = 5002,
      })
      corner(optionButton, 1)
      local optionLabel = create("TextLabel", {
        Parent = optionButton,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = tostring(value),
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.ArialBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5005,
      })

      local function isSelected()
        return multi and selectedValues[value] == true or (not multi and value == current)
      end

      local function refresh(animated)
        local selected = isSelected()
        local targetBackground = section.library.accent
        local transparency = hovering and 0.86 or 1
        local targetPosition = UDim2.fromOffset(hovering and 15 or 10, 0)
        local targetColor
        if hovering then
          targetColor = theme.white
        elseif selected then
          targetColor = lighten(section.library.accent, 0.24)
        else
          targetColor = theme.text
        end
        if animated then
          tween(optionButton, {
            BackgroundColor3 = targetBackground,
            BackgroundTransparency = transparency,
          }, 0.10, Enum.EasingStyle.Quad)
          tween(optionLabel, {
            Position = targetPosition,
            TextColor3 = targetColor,
          }, 0.10, Enum.EasingStyle.Quad)
        else
          optionButton.BackgroundColor3 = targetBackground
          optionButton.BackgroundTransparency = transparency
          optionLabel.Position = targetPosition
          optionLabel.TextColor3 = targetColor
        end
      end
      refreshers[#refreshers + 1] = refresh
      refresh(false)
      optionButton.MouseEnter:Connect(function()
        hovering = true
        refresh(true)
      end)
      optionButton.MouseLeave:Connect(function()
        hovering = false
        refresh(true)
      end)
      optionButton.Activated:Connect(function()
        if multi then
          selectedValues[value] = not selectedValues[value]
          updateDisplay()
          for index = 1, #refreshers do
            refreshers[index](true)
          end
          fire(options.Callback or options.callback, selectionList(), value, selectedValues[value] == true)
        else
          set(value, true)
          closeDropdown()
        end
      end)
    end
    openPopupObject = popup
    section.library.currentPopup = popup
    popup.FollowConnection = RunService.RenderStepped:Connect(reposition)
    reposition()
    tween(popupFrame, {GroupTransparency = 0}, 0.14, Enum.EasingStyle.Quad)
    tween(popupScale, {Scale = 1}, 0.16, Enum.EasingStyle.Back)
    tween(arrow, {Rotation = 90, ImageColor3 = theme.white}, 0.12, Enum.EasingStyle.Quad)
    tween(buttonStroke, {Color = theme.outline, Transparency = 0.42}, 0.10, Enum.EasingStyle.Sine)
  end
  button.MouseEnter:Connect(function()
    tween(hoverOverlay, {BackgroundTransparency = 0.96}, 0.06, Enum.EasingStyle.Linear)
  end)
  button.MouseLeave:Connect(function()
    tween(hoverOverlay, {BackgroundTransparency = 1}, 0.06, Enum.EasingStyle.Linear)
  end)
  button.Activated:Connect(openDropdown)
  control.Object = button
  control.Multi = multi
  control.Set = function(_, value)
    set(value, true)
  end
  control.Get = function()
    return multi and selectionList() or current
  end
  control.Refresh = function(_, newChoices)
    choices = newChoices or {}
    rebuildChoiceLookup()
    if multi then
      for value in pairs(selectedValues) do
        if not choiceLookup[value] then
          selectedValues[value] = nil
        end
      end
      updateDisplay()
    elseif not choiceLookup[current] then
      set(choices[1] or "", false)
    end
    closeDropdown()
  end
  control.Open = openDropdown
  control.Close = closeDropdown
  section.library:RegisterOption(flag, control)
  return control
end

function library:Slider(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  options = options or {}
  local minimum = tonumber(options.Min or options.min) or 0
  local maximum = tonumber(options.Max or options.max) or 100
  local step = tonumber(options.Step or options.step or options.Interval or options.interval) or 1
  local value = tonumber(options.Default or options.default) or minimum
  local suffix = tostring(options.Suffix or options.suffix or "")
  local flag = options.Flag or options.flag
  local row = controlBase(section, 45, false)
  local nameLabel = controlLabel(row, options.Name or options.name or "Slider", UDim2.new(1, -58, 0, 18), UDim2.fromOffset(0, 0), false)
  local valueLabel = create("TextLabel", {
    Parent = row,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.fromOffset(56, 18),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Right,
  })
  local trackButton = create("TextButton", {
    Parent = row,
    Position = UDim2.fromOffset(0, 21),
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
  })
  local track = create("Frame", {
    Parent = trackButton,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.fromScale(0, 0.5),
    Size = UDim2.new(1, 0, 0, 10),
    BackgroundColor3 = theme.controlBottom,
    BorderSizePixel = 0,
  })
  corner(track, 999)
  local fill = create("Frame", {
    Parent = track,
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = theme.white,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    ZIndex = 4,
  })
  corner(fill, 999)
  local fillGlow = create("ImageLabel", {
    Parent = fill,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 22, 1, 22),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://18245826428",
    ImageColor3 = lighten(section.library.accent, 0.12),
    ImageTransparency = 1,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(21, 21, 79, 79),
    ZIndex = 3,
  })
  local fillGradient = create("UIGradient", {
    Parent = fill,
    Rotation = 90,
    Color = subtleAccentSequence(section.library.accent),
  })
  local fillFlash = create("Frame", {
    Parent = fill,
    Position = UDim2.fromOffset(1, 1),
    Size = UDim2.new(1, -2, 0, 1),
    BackgroundColor3 = theme.white,
    BackgroundTransparency = 0.80,
    BorderSizePixel = 0,
  })
  local handleGlow = create("ImageLabel", {
    Parent = trackButton,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0, 0.5),
    Size = UDim2.fromOffset(28, 28),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://18245826428",
    ImageColor3 = lighten(section.library.accent, 0.14),
    ImageTransparency = 0.58,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(21, 21, 79, 79),
    ZIndex = 5,
  })
  local handle = create("Frame", {
    Parent = trackButton,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0, 0.5),
    Size = UDim2.fromOffset(13, 13),
    BackgroundColor3 = section.library.accent,
    BorderSizePixel = 0,
    ZIndex = 6,
  })
  corner(handle, 999)
  local handleStroke = stroke(handle, theme.white, 0.12, 1)
  local valueBubble = create("CanvasGroup", {
    Parent = trackButton,
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0, 0, 0, -4),
    Size = UDim2.fromOffset(58, 22),
    BackgroundColor3 = theme.controlTop,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Visible = false,
    ZIndex = 12,
  })
  corner(valueBubble, 4)
  local valueBubbleStroke = stroke(valueBubble, section.library.accent, 0.38, 1)
  local valueBubbleLabel = create("TextLabel", {
    Parent = valueBubble,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = theme.white,
    TextSize = 11,
    Font = Enum.Font.ArialBold,
    ZIndex = 13,
  })

  local function showValueBubble(visible)
    if visible then
      valueBubble.Visible = true
      tween(valueBubble, {GroupTransparency = 0}, 0.10, Enum.EasingStyle.Quad)
      tween(handle, {Size = UDim2.fromOffset(15, 15)}, 0.10, Enum.EasingStyle.Back)
      tween(handleGlow, {ImageTransparency = 0.34}, 0.10, Enum.EasingStyle.Quad)
    else
      tween(valueBubble, {GroupTransparency = 1}, 0.08, Enum.EasingStyle.Quad)
      tween(handle, {Size = UDim2.fromOffset(13, 13)}, 0.10, Enum.EasingStyle.Quad)
      tween(handleGlow, {ImageTransparency = 0.58}, 0.10, Enum.EasingStyle.Quad)
      task.delay(0.085, function()
        if valueBubble.Parent and valueBubble.GroupTransparency >= 0.99 then
          valueBubble.Visible = false
        end
      end)
    end
  end
  section.window:RegisterAccent(function(color)
    fill.BackgroundColor3 = theme.white
    fillGradient.Color = subtleAccentSequence(color)
    fillGlow.ImageColor3 = lighten(color, 0.12)
    handle.BackgroundColor3 = color
    handleGlow.ImageColor3 = lighten(color, 0.14)
    valueBubbleStroke.Color = color
  end)
  local precision = 0
  local stepText = tostring(step)
  local decimal = string.find(stepText, ".", 1, true)
  if decimal then
    precision = #stepText - decimal
  elseif step < 1 then
    precision = 2
  end

  local function roundToStep(number)
    local rounded = math.floor(((number - minimum) / step) + 0.5) * step + minimum
    return math.clamp(rounded, minimum, maximum)
  end

  local function format(number)
    if precision > 0 then
      return string.format("%." .. precision .. "f", number) .. suffix
    end
    return tostring(math.floor(number + 0.5)) .. suffix
  end

  local function set(newValue, invoke, animated)
    value = roundToStep(tonumber(newValue) or minimum)
    local ratio = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
    local targetSize = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
    local glowTransparency = ratio > 0 and 0.48 or 1
    local targetPosition = UDim2.fromScale(math.clamp(ratio, 0, 1), 0.5)
    local targetBubblePosition = UDim2.new(math.clamp(ratio, 0, 1), 0, 0, -4)
    if animated then
      tween(fill, {Size = targetSize}, 0.07, Enum.EasingStyle.Linear)
      tween(fillGlow, {ImageTransparency = glowTransparency}, 0.07, Enum.EasingStyle.Linear)
      tween(handle, {Position = targetPosition}, 0.07, Enum.EasingStyle.Linear)
      tween(handleGlow, {Position = targetPosition}, 0.07, Enum.EasingStyle.Linear)
      tween(valueBubble, {Position = targetBubblePosition}, 0.07, Enum.EasingStyle.Linear)
    else
      fill.Size = targetSize
      fillGlow.ImageTransparency = glowTransparency
      handle.Position = targetPosition
      handleGlow.Position = targetPosition
      valueBubble.Position = targetBubblePosition
    end
    valueLabel.Text = format(value)
    valueBubbleLabel.Text = format(value)
    if flag then
      section.library.flags[flag] = value
    end
    if invoke ~= false then
      fire(options.Callback or options.callback, value)
    end
  end
  local dragging = false
  local activeInput

  local function update(input)
    local x = input.Position.X
    local ratio = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
    set(minimum + (maximum - minimum) * ratio, true, false)
  end
  trackButton.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    dragging = true
    activeInput = input
    showValueBubble(true)
    tween(fillFlash, {BackgroundTransparency = 0.62}, 0.055, Enum.EasingStyle.Linear)
    update(input)
  end)
  connect(UserInputService.InputChanged, function(input)
    if not dragging then
      return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end
    if activeInput and activeInput.UserInputType == Enum.UserInputType.Touch and input ~= activeInput then
      return
    end
    update(input)
  end)
  connect(UserInputService.InputEnded, function(input)
    if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = false
      activeInput = nil
      tween(fillFlash, {BackgroundTransparency = 0.80}, 0.075, Enum.EasingStyle.Quad)
      showValueBubble(false)
    end
  end)
  trackButton.MouseEnter:Connect(function()
    showValueBubble(true)
  end)
  trackButton.MouseLeave:Connect(function()
    if not dragging then
      showValueBubble(false)
    end
  end)
  set(value, false, false)
  local control = {
    Object = row,
    Set = function(_, newValue)
      set(newValue, true, true)
    end,
    Get = function()
      return value
    end,
  }
  section.library:RegisterOption(flag, control)
  return control
end

function library:Toggle(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  options = options or {}
  local state = options.Default == true or options.default == true
  local flag = options.Flag or options.flag
  local rowHeight = options.Info and 38 or 24
  local row = controlBase(section, rowHeight, true)
  local isEspControl = type(flag) == "string" and string.sub(string.lower(flag), 1, 4) == "esp_"
  local isRisky = options.Risky == true or options.risky == true
  local rowHover = create("Frame", {
    Parent = row,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = section.library.accent,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 1,
  })
  corner(rowHover, 4)
  local toggleGlow = create("ImageLabel", {
    Parent = row,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, -9, 0, 12),
    Size = UDim2.fromOffset(35, 35),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://18245826428",
    ImageColor3 = lighten(section.library.accent, 0.18),
    ImageTransparency = state and (isEspControl and 0.12 or 0.26) or 1,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(21, 21, 79, 79),
    ZIndex = 2,
  })
  local toggle = create("Frame", {
    Parent = row,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 0, 0, 12),
    Size = UDim2.fromOffset(17, 17),
    BackgroundColor3 = theme.white,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 3,
  })
  corner(toggle, 1)
  local toggleStroke = stroke(toggle, state and darken(section.library.accent, 0.34) or theme.outline, 0, 1)
  local toggleGradient = create("UIGradient", {
    Parent = toggle,
    Rotation = 90,
    Color = state and subtleAccentSequence(section.library.accent) or subtleControlSequence(),
  })
  local checkmark = create("ImageLabel", {
    Parent = toggle,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = state and UDim2.fromOffset(15, 15) or UDim2.fromOffset(9, 9),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://86817768619372",
    ImageColor3 = theme.black,
    ImageTransparency = state and 0 or 1,
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 4,
  })
  local accessoryHolder = create("Frame", {
    Parent = row,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, 0, 0, 12),
    Size = UDim2.fromOffset(0, 22),
    AutomaticSize = Enum.AutomaticSize.X,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
  })
  create("UIListLayout", {
    Parent = accessoryHolder,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 5),
  })
  local nameLabel = controlLabel(row, options.Name or options.name or "Toggle", UDim2.new(1, -26, 0, 24), UDim2.fromOffset(26, 0), false)
  local riskyIcon = nil
  if isRisky then
    nameLabel.TextColor3 = theme.risky
    riskyIcon = create("ImageLabel", {
      Parent = row,
      AnchorPoint = Vector2.new(0, 0.5),
      Position = UDim2.fromOffset(26, 12),
      Size = UDim2.fromOffset(isMobileDevice and 20 or 18, isMobileDevice and 20 or 13),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Image = "rbxassetid://1764960410",
      ImageColor3 = theme.risky,
      ScaleType = Enum.ScaleType.Fit,
      ZIndex = 7,
    })
  end
  local infoLabel = nil
  if options.Info then
    infoLabel = controlLabel(row, options.Info, UDim2.new(1, -26, 0, 14), UDim2.fromOffset(26, 22), true)
    infoLabel.TextSize = 11
    infoLabel.Font = Enum.Font.ArialBold
  end
  local colorpickerData = {}
  do
    local source = options.Colorpickers or options.colorpickers
    if source == nil and (options.Colorpicker or options.colorpicker) ~= nil then
      source = {options.Colorpicker or options.colorpicker}
    end
    if source then
      if typeof(source) ~= "table" or source.Default or source.default or source.Flag or source.flag or source.Callback or source.callback or source.Name or source.name then
        source = {source}
      end
      for index = 1, #source do
        local entry = source[index]
        if entry == true then
          entry = {}
        elseif typeof(entry) == "Color3" then
          entry = {Default = entry}
        end
        colorpickerData[#colorpickerData + 1] = entry
      end
    end
  end
  local keybindOptions = options.Keybind or options.keybind
  if keybindOptions ~= nil and typeof(keybindOptions) ~= "table" then
    keybindOptions = {Default = keybindOptions}
  end
  local bindState = {
    key = keybindOptions and coerceKey(keybindOptions.Default or keybindOptions.default or Enum.KeyCode.Insert) or nil,
    mode = normalizeBindMode(keybindOptions and (keybindOptions.Mode or keybindOptions.mode) or "Toggle"),
    binding = false,
    held = false,
    button = nil,
    stroke = nil,
  }
  local keybindEntry = nil

  local function refreshKeybindEntry()
    if keybindEntry and section.window.RefreshKeybindList then
      section.window:RefreshKeybindList()
    end
  end

  local function updateLabelBounds()
    local accessoryWidth = accessoryHolder.AbsoluteSize.X
    local rightInset = accessoryWidth > 0 and (accessoryWidth + 8) or 0
    nameLabel.Position = UDim2.fromOffset(26, 0)
    nameLabel.Size = UDim2.new(1, -(26 + rightInset), 0, 24)
    if riskyIcon then
      local iconSize = riskyIcon.AbsoluteSize.X > 0 and riskyIcon.AbsoluteSize.X or (isMobileDevice and 15 or 13)
      local bounds = TextService:GetTextSize(nameLabel.Text, nameLabel.TextSize, nameLabel.Font, Vector2.new(1000, 24))
      local maxX = math.max(26, row.AbsoluteSize.X - rightInset - iconSize - 2)
      local targetX = math.clamp(26 + math.ceil(bounds.X) + 5, 26, maxX)
      riskyIcon.Position = UDim2.fromOffset(targetX, 12)
      riskyIcon.ImageColor3 = theme.risky
    end
    if infoLabel then
      infoLabel.Position = UDim2.fromOffset(26, 22)
      infoLabel.Size = UDim2.new(1, -(26 + rightInset), 0, 14)
    end
  end

  local function createMiniColorpicker(config, order)
    local currentColor = config.Default or config.default or section.library.accent
    local colorFlag = config.Flag or config.flag
    local rainbowController
    if colorFlag then
      section.library.flags[colorFlag] = currentColor
    end
    local icon = create("ImageButton", {
      Parent = accessoryHolder,
      Size = UDim2.fromOffset(isMobileDevice and 26 or 20, isMobileDevice and 26 or 20),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      AutoButtonColor = false,
      Image = "rbxassetid://103592623663192",
      ImageColor3 = currentColor,
      ScaleType = Enum.ScaleType.Fit,
      LayoutOrder = order,
    })

    local function setColor(color, invoke)
      if typeof(color) ~= "Color3" then
        return
      end
      currentColor = color
      icon.ImageColor3 = color
      if colorFlag then
        section.library.flags[colorFlag] = color
      end
      if invoke ~= false then
        fire(config.Callback or config.callback or options.Callback or options.callback, color)
      end
    end

    local function openPopup()
      if rainbowController and rainbowController.ConsumeActivation() then
        return
      end
      section.library:ClosePopup()
      local hue, saturation, value = currentColor:ToHSV()
      local popupWidth = 206
      local popupHeight = 181
      local popupFrame = create("CanvasGroup", {
        Parent = section.window.Gui,
        Name = "ColorpickerPopup",
        Position = popupPosition(icon, popupWidth, popupHeight, 5),
        Size = UDim2.fromOffset(popupWidth, popupHeight),
        BackgroundColor3 = Color3.fromRGB(45, 46, 52),
        BorderSizePixel = 0,
        ZIndex = 700,
        GroupTransparency = 1,
      })
      corner(popupFrame, 4)
      stroke(popupFrame, Color3.fromRGB(57, 58, 66), 0, 1)
      local popupScale = create("UIScale", {
        Parent = popupFrame,
        Scale = 0.97,
      })
      local topIcon = create("ImageLabel", {
        Parent = popupFrame,
        Position = UDim2.fromOffset(9, 8),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "rbxassetid://103592623663192",
        ImageColor3 = currentColor,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 702,
      })
      local hexLabel = create("TextBox", {
        Parent = popupFrame,
        Position = UDim2.fromOffset(34, 7),
        Size = UDim2.fromOffset(58, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "#" .. currentColor:ToHex(),
        TextColor3 = theme.textMuted,
        TextSize = 11,
        Font = Enum.Font.ArialBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        MultiLine = false,
        ZIndex = 702,
      })
      local rgbLabel = create("TextBox", {
        Parent = popupFrame,
        Position = UDim2.fromOffset(93, 7),
        Size = UDim2.new(1, -98, 0, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = colorRGBText(currentColor),
        TextColor3 = theme.textMuted,
        TextSize = 11,
        Font = Enum.Font.ArialBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        MultiLine = false,
        ZIndex = 702,
      })
      local hueBar = create("Frame", {
        Parent = popupFrame,
        Position = UDim2.fromOffset(9, 34),
        Size = UDim2.fromOffset(17, 137),
        BackgroundColor3 = theme.white,
        BorderSizePixel = 0,
        ZIndex = 702,
      })
      corner(hueBar, 4)
      stroke(hueBar, Color3.fromRGB(57, 58, 66), 0, 1)
      create("UIGradient", {
        Parent = hueBar,
        Rotation = 90,
        Color = ColorSequence.new({
          ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
          ColorSequenceKeypoint.new(0.16, Color3.fromHSV(0.16, 1, 1)),
          ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
          ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
          ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66, 1, 1)),
          ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
          ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1)),
        }),
      })
      local hueSelector = create("Frame", {
        Parent = popupFrame,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 17, 0, 34 + hue * 137),
        Size = UDim2.fromOffset(15, 15),
        BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 706,
      })
      corner(hueSelector, 999)
      stroke(hueSelector, theme.white, 0, 2)
      stroke(hueSelector, theme.black, 0.48, 1)
      local svSquare = create("Frame", {
        Parent = popupFrame,
        Position = UDim2.fromOffset(36, 34),
        Size = UDim2.fromOffset(160, 137),
        BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 702,
        ClipsDescendants = true,
      })
      corner(svSquare, 3)
      stroke(svSquare, Color3.fromRGB(57, 58, 66), 0, 1)
      local whiteOverlay = create("Frame", {
        Parent = svSquare,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.white,
        BorderSizePixel = 0,
        ZIndex = 703,
      })
      create("UIGradient", {
        Parent = whiteOverlay,
        Rotation = 0,
        Transparency = NumberSequence.new({
          NumberSequenceKeypoint.new(0, 0),
          NumberSequenceKeypoint.new(1, 1),
        }),
      })
      local blackOverlay = create("Frame", {
        Parent = svSquare,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.black,
        BorderSizePixel = 0,
        ZIndex = 704,
      })
      create("UIGradient", {
        Parent = blackOverlay,
        Rotation = 90,
        Transparency = NumberSequence.new({
          NumberSequenceKeypoint.new(0, 1),
          NumberSequenceKeypoint.new(1, 0),
        }),
      })
      local svSelector = create("Frame", {
        Parent = popupFrame,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(36 + saturation * 160, 34 + (1 - value) * 137),
        Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 707,
      })
      corner(svSelector, 999)
      stroke(svSelector, theme.white, 0, 2)
      stroke(svSelector, theme.black, 0.34, 1)
      local hueInput = create("TextButton", {
        Parent = popupFrame,
        Position = hueBar.Position,
        Size = hueBar.Size,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 710,
      })
      local svInput = create("TextButton", {
        Parent = popupFrame,
        Position = svSquare.Position,
        Size = svSquare.Size,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 710,
      })
      local draggingHue = false
      local draggingSV = false
      local activeHueInput
      local activeSVInput
      local updatingFields = false

      local function refresh(invoke, source)
        local color = Color3.fromHSV(hue, saturation, value)
        if invoke ~= false and rainbowController then
          rainbowController.SetEnabled(false)
        end
        svSquare.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        hueSelector.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        hueSelector.Position = UDim2.new(0, 17, 0, 34 + hue * 137)
        svSelector.Position = UDim2.fromOffset(36 + saturation * 160, 34 + (1 - value) * 137)
        topIcon.ImageColor3 = color
        updatingFields = true
        if source ~= "hex" and not hexLabel:IsFocused() then
          hexLabel.Text = "#" .. color:ToHex()
        end
        if source ~= "rgb" and not rgbLabel:IsFocused() then
          rgbLabel.Text = colorRGBText(color)
        end
        updatingFields = false
        setColor(color, invoke)
      end

      local function applyHexText()
        local color = parseHexColor(hexLabel.Text)
        if color then
          hue, saturation, value = color:ToHSV()
          refresh(true, "hex")
          return true
        end
        return false
      end

      local function applyRGBText()
        local color = parseRGBColor(rgbLabel.Text)
        if color then
          hue, saturation, value = color:ToHSV()
          refresh(true, "rgb")
          return true
        end
        return false
      end
      hexLabel:GetPropertyChangedSignal("Text"):Connect(function()
        if not updatingFields and hexLabel:IsFocused() then
          applyHexText()
        end
      end)
      rgbLabel:GetPropertyChangedSignal("Text"):Connect(function()
        if not updatingFields and rgbLabel:IsFocused() then
          applyRGBText()
        end
      end)
      hexLabel.FocusLost:Connect(function()
        if not applyHexText() then
          hexLabel.Text = "#" .. currentColor:ToHex()
        end
      end)
      rgbLabel.FocusLost:Connect(function()
        if not applyRGBText() then
          rgbLabel.Text = colorRGBText(currentColor)
        end
      end)

      local function updateHue(input)
        local ratio = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
        hue = ratio
        refresh(true)
      end

      local function updateSV(input)
        saturation = math.clamp((input.Position.X - svSquare.AbsolutePosition.X) / math.max(svSquare.AbsoluteSize.X, 1), 0, 1)
        value = 1 - math.clamp((input.Position.Y - svSquare.AbsolutePosition.Y) / math.max(svSquare.AbsoluteSize.Y, 1), 0, 1)
        refresh(true)
      end
      hueInput.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
          return
        end
        draggingHue = true
        activeHueInput = input
        updateHue(input)
      end)
      svInput.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
          return
        end
        draggingSV = true
        activeSVInput = input
        updateSV(input)
      end)
      local hueMoveConnection
      local svMoveConnection
      local endConnection
      hueMoveConnection = UserInputService.InputChanged:Connect(function(input)
        if not draggingHue then
          return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
          return
        end
        if activeHueInput and activeHueInput.UserInputType == Enum.UserInputType.Touch and input ~= activeHueInput then
          return
        end
        updateHue(input)
      end)
      svMoveConnection = UserInputService.InputChanged:Connect(function(input)
        if not draggingSV then
          return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
          return
        end
        if activeSVInput and activeSVInput.UserInputType == Enum.UserInputType.Touch and input ~= activeSVInput then
          return
        end
        updateSV(input)
      end)
      endConnection = UserInputService.InputEnded:Connect(function(input)
        if input == activeHueInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
          draggingHue = false
          activeHueInput = nil
        end
        if input == activeSVInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
          draggingSV = false
          activeSVInput = nil
        end
      end)
      local lastRainbowVisualUpdate = 0
      local rainbowVisualConnection = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if rainbowController and rainbowController.GetEnabled() and now - lastRainbowVisualUpdate >= 1 / 30 then
          lastRainbowVisualUpdate = now
          hue, saturation, value = currentColor:ToHSV()
          refresh(false)
        end
      end)
      local popup = {
        Frame = popupFrame,
        Anchor = icon,
      }
      function popup:Close()
        if hueMoveConnection then hueMoveConnection:Disconnect() end
        if svMoveConnection then svMoveConnection:Disconnect() end
        if endConnection then endConnection:Disconnect() end
        if rainbowVisualConnection then rainbowVisualConnection:Disconnect() end
        tween(popupFrame, {GroupTransparency = 1}, 0.09, Enum.EasingStyle.Linear)
        tween(popupScale, {Scale = 0.97}, 0.09, Enum.EasingStyle.Linear)
        task.delay(0.095, function()
          if popupFrame.Parent then
            popupFrame:Destroy()
          end
        end)
      end
      section.library.currentPopup = popup
      tween(popupFrame, {GroupTransparency = 0}, 0.12, Enum.EasingStyle.Quad)
      tween(popupScale, {Scale = 1}, 0.12, Enum.EasingStyle.Quad)
    end
    icon.Activated:Connect(openPopup)
    rainbowController = createRainbowController(section, icon, colorFlag, setColor)
    local colorControl = {
      Icon = icon,
      Set = function(_, color)
        setColor(color, true)
      end,
      Get = function()
        return currentColor
      end,
    }
    section.library:RegisterOption(colorFlag, colorControl)
    return colorControl
  end

  local function applyToggleState(newState, invoke)
    state = newState == true
    if flag then
      section.library.flags[flag] = state
    end
    toggleGradient.Color = state and subtleAccentSequence(section.library.accent) or subtleControlSequence()
    tween(toggleStroke, {Color = state and darken(section.library.accent, 0.34) or theme.outline}, 0.16, Enum.EasingStyle.Quad)
    tween(toggleGlow, {ImageTransparency = state and (isEspControl and 0.12 or 0.26) or 1}, 0.16, Enum.EasingStyle.Quad)
    tween(checkmark, {
      ImageTransparency = state and 0 or 1,
      Size = state and UDim2.fromOffset(15, 15) or UDim2.fromOffset(9, 9),
    }, 0.14, Enum.EasingStyle.Quad)
    refreshKeybindEntry()
    if invoke ~= false then
      fire(options.Callback or options.callback, state)
    end
  end
  if keybindOptions then
    local bindFlag = keybindOptions.Flag or keybindOptions.flag
    local modeFlag = keybindOptions.ModeFlag or keybindOptions.modeFlag
    if bindFlag then
      section.library.flags[bindFlag] = bindState.key
    end
    if modeFlag then
      section.library.flags[modeFlag] = bindState.mode
    end

    local function bindWidthForText(value)
      return math.clamp(keybindWidth(value, 11, 24, 90) + 17, 39, 108)
    end
    local bindHeight = isMobileDevice and 23 or 19
    local bindButton = create("TextButton", {
      Parent = accessoryHolder,
      Size = UDim2.fromOffset(bindWidthForText(keyName(bindState.key)), bindHeight),
      AutomaticSize = Enum.AutomaticSize.None,
      BackgroundColor3 = theme.control,
      BackgroundTransparency = 0,
      BorderSizePixel = 0,
      Text = "",
      AutoButtonColor = false,
      Active = true,
      ClipsDescendants = true,
      LayoutOrder = 90,
      ZIndex = 8,
    })
    create("UISizeConstraint", {
      Parent = bindButton,
      MinSize = Vector2.new(39, bindHeight),
      MaxSize = Vector2.new(108, bindHeight),
    })
    corner(bindButton, 2)
    local bindStroke = stroke(bindButton, Color3.fromRGB(68, 69, 77), 0, 1)
    local bindGradient = create("UIGradient", {
      Parent = bindButton,
      Rotation = 90,
      Color = subtleControlSequence(),
    })
    local bindIcon = create("ImageLabel", {
      Parent = bindButton,
      AnchorPoint = Vector2.new(0, 0.5),
      Position = UDim2.new(0, 4, 0.5, 0),
      Size = UDim2.fromOffset(11, 11),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Image = "rbxassetid://121978468376124",
      ImageColor3 = section.library.accent,
      ScaleType = Enum.ScaleType.Fit,
      ZIndex = bindButton.ZIndex + 2,
    })
    local bindLabel = create("TextLabel", {
      Parent = bindButton,
      Position = UDim2.fromOffset(17, 0),
      Size = UDim2.new(1, -20, 1, 0),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = keyName(bindState.key),
      TextColor3 = theme.textMuted,
      TextSize = 11,
      Font = Enum.Font.ArialBold,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Center,
      ZIndex = bindButton.ZIndex + 1,
    })

    local function refreshBindVisuals()
      bindButton.AutomaticSize = Enum.AutomaticSize.None
      bindButton.BackgroundColor3 = theme.control
      bindButton.BackgroundTransparency = 0
      bindButton.BorderSizePixel = 0
      bindButton.ClipsDescendants = true
      bindButton.ZIndex = 8
      bindIcon.ZIndex = 10
      bindLabel.ZIndex = 9
      bindStroke.Color = Color3.fromRGB(68, 69, 77)
      bindStroke.Transparency = 0
      bindGradient.Color = subtleControlSequence()
    end

    local function updateBindWidth(animated)
      if not bindState.binding then
        bindLabel.Text = keyName(bindState.key)
      end
      local target = UDim2.fromOffset(bindWidthForText(bindLabel.Text), bindHeight)
      refreshBindVisuals()
      if animated then
        tween(bindButton, {Size = target, BackgroundTransparency = 0}, 0.10, Enum.EasingStyle.Quad)
      else
        bindButton.Size = target
      end
      task.defer(updateLabelBounds)
    end
    bindState.button = bindButton
    bindState.label = bindLabel
    bindState.stroke = bindStroke
    bindState.icon = bindIcon
    updateBindWidth(false)

    local function setMode(newMode)
      bindState.mode = normalizeBindMode(newMode)
      bindState.held = false
      if modeFlag then
        section.library.flags[modeFlag] = bindState.mode
      end
      if bindState.mode == "Always" and keybindOptions.ToggleTarget ~= false then
        applyToggleState(true, true)
      elseif bindState.mode == "Hold" and keybindOptions.ToggleTarget ~= false then
        applyToggleState(false, true)
      else
        refreshKeybindEntry()
      end
      fire(keybindOptions.ModeChanged or keybindOptions.modeChanged, bindState.mode)
    end

    local function openModeMenu()
      section.library:ClosePopup()
      local popupLayer = section.window.PopupLayer
      local popupWidth = isMobileDevice and 112 or 98
      local itemHeight = isMobileDevice and 31 or 26
      local popupHeight = itemHeight * 3 + 8
      local popupFrame = create("CanvasGroup", {
        Parent = popupLayer,
        Name = "KeybindModePopup",
        Size = UDim2.fromOffset(popupWidth, popupHeight),
        BackgroundColor3 = Color3.fromRGB(31, 32, 38),
        BorderSizePixel = 0,
        Active = true,
        ClipsDescendants = true,
        GroupTransparency = 1,
        ZIndex = 5100,
      })
      corner(popupFrame, 1)
      stroke(popupFrame, theme.outlineSoft, 0.50, 1)
      local popupScale = create("UIScale", {
        Parent = popupFrame,
        Scale = 0.97,
      })
      padding(popupFrame, 4, 4, 4, 4)
      create("UIListLayout", {
        Parent = popupFrame,
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
      })
      local popup = {
        Frame = popupFrame,
        Anchor = bindButton,
        Closed = false,
        FollowConnection = nil,
      }

      local function reposition()
        if popup.Closed or not popupFrame.Parent or not bindButton.Parent then
          return
        end
        local layerPosition = popupLayer.AbsolutePosition
        local layerSize = popupLayer.AbsoluteSize
        local anchorPosition = bindButton.AbsolutePosition
        local anchorSize = bindButton.AbsoluteSize
        local x = math.floor(anchorPosition.X - layerPosition.X + anchorSize.X - popupWidth + 0.5)
        local y = math.floor(anchorPosition.Y - layerPosition.Y + anchorSize.Y + 3.5)
        x = math.clamp(x, 3, math.max(3, layerSize.X - popupWidth - 3))
        if y + popupHeight > layerSize.Y - 3 then
          y = math.floor(anchorPosition.Y - layerPosition.Y - popupHeight - 3.5)
        end
        popupFrame.Position = UDim2.fromOffset(x, math.max(3, y))
      end
      function popup:Close()
        if self.Closed then
          return
        end
        self.Closed = true
        if self.FollowConnection then
          self.FollowConnection:Disconnect()
          self.FollowConnection = nil
        end
        if popupFrame.Parent then
          tween(popupFrame, {GroupTransparency = 1}, 0.10, Enum.EasingStyle.Quad)
          tween(popupScale, {Scale = 0.97}, 0.10, Enum.EasingStyle.Quad)
          task.delay(0.105, function()
            if popupFrame.Parent then
              popupFrame:Destroy()
            end
          end)
        end
      end
      for index = 1, #KEYBIND_MODES do
        local modeName = KEYBIND_MODES[index]
        local selected = bindState.mode == modeName
        local optionButton = create("TextButton", {
          Parent = popupFrame,
          Size = UDim2.new(1, 0, 0, itemHeight),
          BackgroundColor3 = section.library.accent,
          BackgroundTransparency = 1,
          BorderSizePixel = 0,
          Text = "",
          AutoButtonColor = false,
          LayoutOrder = index,
          ZIndex = 5101,
        })
        corner(optionButton, 1)
        local optionLabel = create("TextLabel", {
          Parent = optionButton,
          Position = UDim2.fromOffset(8, 0),
          Size = UDim2.new(1, -16, 1, 0),
          BackgroundTransparency = 1,
          BorderSizePixel = 0,
          Text = modeName,
          TextColor3 = selected and lighten(section.library.accent, 0.24) or theme.text,
          TextSize = isMobileDevice and 12 or 11,
          Font = Enum.Font.ArialBold,
          TextXAlignment = Enum.TextXAlignment.Left,
          TextYAlignment = Enum.TextYAlignment.Center,
          ZIndex = 5102,
        })
        optionButton.MouseEnter:Connect(function()
          tween(optionButton, {
            BackgroundColor3 = section.library.accent,
            BackgroundTransparency = 0.86,
          }, 0.10, Enum.EasingStyle.Quad)
          tween(optionLabel, {
            Position = UDim2.fromOffset(13, 0),
            TextColor3 = theme.white,
          }, 0.10, Enum.EasingStyle.Quad)
        end)
        optionButton.MouseLeave:Connect(function()
          tween(optionButton, {
            BackgroundColor3 = section.library.accent,
            BackgroundTransparency = 1,
          }, 0.10, Enum.EasingStyle.Quad)
          tween(optionLabel, {
            Position = UDim2.fromOffset(8, 0),
            TextColor3 = selected and lighten(section.library.accent, 0.24) or theme.text,
          }, 0.10, Enum.EasingStyle.Quad)
        end)
        optionButton.Activated:Connect(function()
          setMode(modeName)
          section.library:ClosePopup()
        end)
      end
      section.library.currentPopup = popup
      popup.FollowConnection = RunService.RenderStepped:Connect(reposition)
      reposition()
      tween(popupFrame, {GroupTransparency = 0}, 0.14, Enum.EasingStyle.Quad)
      tween(popupScale, {Scale = 1}, 0.16, Enum.EasingStyle.Back)
    end
    local suppressActivation = false
    local touchSerial = 0
    bindButton.InputBegan:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseButton2 and not bindState.binding then
        openModeMenu()
        return
      end
      if input.UserInputType == Enum.UserInputType.Touch and not bindState.binding then
        touchSerial = touchSerial + 1
        local serial = touchSerial
        tween(bindStroke, {Color = section.library.accent}, 0.12, Enum.EasingStyle.Quad)
        task.delay(0.40, function()
          if serial == touchSerial and bindButton.Parent then
            suppressActivation = true
            openModeMenu()
          end
        end)
      end
    end)
    bindButton.InputEnded:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.Touch then
        touchSerial = touchSerial + 1
        if not bindState.binding then
          bindStroke.Color = Color3.fromRGB(68, 69, 77)
        end
      end
    end)
    bindButton.MouseEnter:Connect(function()
      if not bindState.binding then
        tween(bindButton, {BackgroundColor3 = theme.controlHover, BackgroundTransparency = 0}, 0.07, Enum.EasingStyle.Sine)
        tween(bindLabel, {TextColor3 = theme.text}, 0.07, Enum.EasingStyle.Sine)
      end
    end)
    bindButton.MouseLeave:Connect(function()
      if not bindState.binding then
        tween(bindButton, {BackgroundColor3 = theme.control, BackgroundTransparency = 0}, 0.07, Enum.EasingStyle.Sine)
        tween(bindLabel, {TextColor3 = theme.textMuted}, 0.07, Enum.EasingStyle.Sine)
      end
    end)
    bindButton.Activated:Connect(function()
      if suppressActivation then
        suppressActivation = false
        return
      end
      bindState.binding = true
      bindLabel.Text = "..."
      updateBindWidth(true)
      bindLabel.TextColor3 = section.library.accent
      bindStroke.Color = section.library.accent
    end)
    connect(UserInputService.InputBegan, function(input, processed)
      local pressed = normalizeKey(input)
      if not pressed then
        return
      end
      if bindState.binding then
        bindState.binding = false
        if pressed == Enum.KeyCode.Escape then
          bindState.key = nil
        else
          bindState.key = pressed
        end
        bindLabel.Text = keyName(bindState.key)
        updateBindWidth(true)
        bindLabel.TextColor3 = theme.textMuted
        bindButton.BackgroundColor3 = theme.control
        bindButton.BackgroundTransparency = 0
        bindStroke.Color = Color3.fromRGB(68, 69, 77)
        if bindFlag then
          section.library.flags[bindFlag] = bindState.key
        end
        fire(keybindOptions.Changed or keybindOptions.changed, bindState.key)
        refreshKeybindEntry()
        return
      end
      if input.UserInputType == Enum.UserInputType.MouseButton2 and not bindState.binding then
        local inputPosition = Vector2.new(input.Position.X, input.Position.Y)
        if pointInside(inputPosition, bindButton) then
          return
        end
      end
      if processed or not bindState.key or pressed ~= bindState.key then
        return
      end
      fire(keybindOptions.Callback or keybindOptions.callback, bindState.key)
      if keybindOptions.ToggleTarget == false then
        return
      end
      if bindState.mode == "Always" then
        applyToggleState(true, true)
      elseif bindState.mode == "Hold" then
        if not bindState.held then
          bindState.held = true
          applyToggleState(true, true)
        end
      else
        applyToggleState(not state, true)
      end
    end)
    connect(UserInputService.InputEnded, function(input)
      if bindState.mode ~= "Hold" or not bindState.held or not bindState.key then
        return
      end
      local released = normalizeKey(input)
      if released == bindState.key then
        bindState.held = false
        if keybindOptions.ToggleTarget ~= false then
          applyToggleState(false, true)
        end
        fire(keybindOptions.Released or keybindOptions.released, bindState.key)
      end
    end)
    section.window:RegisterAccent(function(color)
      bindIcon.ImageColor3 = color
      if bindState.binding then
        bindLabel.TextColor3 = color
        bindStroke.Color = color
      end
    end)
  end
  local colorpickers = table.create(#colorpickerData)
  for index = 1, #colorpickerData do
    colorpickers[index] = createMiniColorpicker(colorpickerData[index], index)
  end
  local settingsButton
  local settingsPanel
  local settingsOpen = false
  local lastSettingsClick = 0

  local function createSettingsPanel()
    if settingsPanel then
      return settingsPanel
    end
    settingsButton = create("ImageButton", {
      Parent = accessoryHolder,
      Size = UDim2.fromOffset(19, 19),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Image = "rbxassetid://106205298246017",
      ImageColor3 = theme.textMuted,
      ImageTransparency = 0,
      ScaleType = Enum.ScaleType.Fit,
      AutoButtonColor = false,
      LayoutOrder = 70,
      ZIndex = 8,
    })
    local settingsGlow = create("ImageLabel", {
      Parent = settingsButton,
      AnchorPoint = Vector2.new(0.5, 0.5),
      Position = UDim2.fromScale(0.5, 0.5),
      Size = UDim2.fromOffset(31, 31),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Image = "rbxassetid://18245826428",
      ImageColor3 = section.library.accent,
      ImageTransparency = 1,
      ScaleType = Enum.ScaleType.Slice,
      SliceCenter = Rect.new(21, 21, 79, 79),
      ZIndex = 7,
    })
    local holder = create("Frame", {
      Parent = section.Content,
      Name = tostring(flag or options.Name or options.name or "Toggle") .. "Settings",
      Size = UDim2.new(1, 0, 0, 0),
      AutomaticSize = Enum.AutomaticSize.Y,
      BackgroundColor3 = Color3.fromRGB(15, 16, 20),
      BackgroundTransparency = 0.04,
      BorderSizePixel = 0,
      ClipsDescendants = true,
      Visible = false,
    })
    corner(holder, 2)
    stroke(holder, theme.outlineSoft, 0.55, 1)
    padding(holder, 7, 7, 6, 7)
    local content = create("Frame", {
      Parent = holder,
      Size = UDim2.new(1, 0, 0, 0),
      AutomaticSize = Enum.AutomaticSize.Y,
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      ClipsDescendants = false,
    })
    create("UIListLayout", {
      Parent = content,
      FillDirection = Enum.FillDirection.Vertical,
      HorizontalAlignment = Enum.HorizontalAlignment.Center,
      SortOrder = Enum.SortOrder.LayoutOrder,
      Padding = UDim.new(0, 5),
    })
    local panel = {
      library = section.library,
      window = section.window,
      tab = section.tab,
      subtab = section.subtab,
      Content = content,
      Frame = holder,
      ParentToggle = row,
    }
    function panel:SetVisible(value)
      settingsOpen = value == true
      holder.Visible = settingsOpen
      settingsButton.ImageColor3 = settingsOpen and section.library.accent or theme.textMuted
      settingsGlow.ImageTransparency = settingsOpen and 0.38 or 1
      settingsButton.Rotation = settingsOpen and 90 or 0
    end
    function panel:ToggleVisible()
      self:SetVisible(not settingsOpen)
    end
    settingsButton.MouseEnter:Connect(function()
      settingsButton.ImageColor3 = section.library.accent
    end)
    settingsButton.MouseLeave:Connect(function()
      if not settingsOpen then
        settingsButton.ImageColor3 = theme.textMuted
      end
    end)
    settingsButton.Activated:Connect(function()
      lastSettingsClick = os.clock()
      panel:ToggleVisible()
    end)
    section.window:RegisterAccent(function(color)
      settingsGlow.ImageColor3 = color
      if settingsOpen then
        settingsButton.ImageColor3 = color
      end
    end)
    settingsPanel = setmetatable(panel, {__index = library})
    task.defer(updateLabelBounds)
    return settingsPanel
  end
  section.window:RegisterAccent(function(color)
    rowHover.BackgroundColor3 = color
    toggleGlow.ImageColor3 = lighten(color, 0.18)
    if state then
      toggleGradient.Color = subtleAccentSequence(color)
      toggleStroke.Color = darken(color, 0.34)
    end
    if bindState.binding and bindState.button and bindState.label and bindState.stroke then
      bindState.label.TextColor3 = color
      bindState.stroke.Color = color
    end
  end)

  local function set(newState, invoke)
    if bindState.mode == "Always" and keybindOptions and keybindOptions.ToggleTarget ~= false then
      newState = true
    end
    applyToggleState(newState, invoke)
  end
  if keybindOptions and section.window.RegisterKeybind then
    keybindEntry = section.window:RegisterKeybind({
      Name = tostring(options.Name or options.name or "Toggle"),
      GetState = function()
        return state
      end,
      GetKey = function()
        return bindState.key
      end,
      GetMode = function()
        return bindState.mode
      end,
    })
  end
  row.Activated:Connect(function()
    if bindState.binding then
      return
    end
    if settingsButton and os.clock() - lastSettingsClick < 0.12 then
      return
    end
    set(not state, true)
  end)
  row.MouseEnter:Connect(function()
    tween(rowHover, {BackgroundTransparency = state and 0.91 or 0.95}, 0.10, Enum.EasingStyle.Quad)
  end)
  row.MouseLeave:Connect(function()
    tween(rowHover, {BackgroundTransparency = 1}, 0.10, Enum.EasingStyle.Quad)
  end)
  row.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      tween(rowHover, {BackgroundTransparency = 0.84}, 0.06, Enum.EasingStyle.Quad)
      tween(toggle, {Size = UDim2.fromOffset(15, 15)}, 0.06, Enum.EasingStyle.Quad)
    end
  end)
  row.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      tween(rowHover, {BackgroundTransparency = 0.95}, 0.09, Enum.EasingStyle.Quad)
      tween(toggle, {Size = UDim2.fromOffset(17, 17)}, 0.11, Enum.EasingStyle.Back)
    end
  end)
  task.defer(updateLabelBounds)
  accessoryHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLabelBounds)
  if bindState.mode == "Always" and keybindOptions and keybindOptions.ToggleTarget ~= false then
    state = true
  end
  set(state, false)
  local control = {
    Object = row,
    Toggle = toggle,
    Glow = toggleGlow,
    Keybind = bindState.button,
    GetKeybindMode = function()
      return bindState.mode
    end,
    SetKeybindMode = function(_, mode)
      bindState.mode = normalizeBindMode(mode)
      if keybindOptions then
        local bindFlag = keybindOptions.Flag or keybindOptions.flag
        local modeFlag = keybindOptions.ModeFlag or keybindOptions.modeFlag or (bindFlag and (bindFlag .. "_mode"))
        if modeFlag then section.library.flags[modeFlag] = bindState.mode end
        if keybindOptions.ToggleTarget ~= false then
          if bindState.mode == "Always" then
            applyToggleState(true, true)
          elseif bindState.mode == "Hold" then
            applyToggleState(false, true)
          end
        end
        fire(keybindOptions.ModeChanged or keybindOptions.modeChanged, bindState.mode)
      end
      refreshKeybindEntry()
    end,
    SetKey = function(_, newKey)
      bindState.key = coerceKey(newKey)
      if bindState.label and bindState.button then
        updateBindWidth(false)
        task.defer(updateBindWidth, false)
        task.delay(0.05, updateBindWidth, false)
      end
      if keybindOptions then
        local bindFlag = keybindOptions.Flag or keybindOptions.flag
        if bindFlag then section.library.flags[bindFlag] = bindState.key end
        fire(keybindOptions.Changed or keybindOptions.changed, bindState.key)
      end
      refreshKeybindEntry()
    end,
    GetKey = function()
      return bindState.key
    end,
    RefreshKeybindWidth = function()
      if bindState.label and bindState.button then
        updateBindWidth(false)
        task.defer(updateBindWidth, false)
        task.delay(0.05, updateBindWidth, false)
      end
    end,
    Settings = function()
      return createSettingsPanel()
    end,
    settings = function()
      return createSettingsPanel()
    end,
    Colorpickers = colorpickers,
    Set = function(_, newState)
      set(newState, true)
    end,
    Get = function()
      return state
    end,
  }
  section.library:RegisterOption(flag, control)
  if keybindOptions then
    local bindFlag = keybindOptions.Flag or keybindOptions.flag
    local modeFlag = keybindOptions.ModeFlag or keybindOptions.modeFlag or (bindFlag and (bindFlag .. "_mode"))
    if bindFlag then
      section.library:RegisterOption(bindFlag, {
        Set = function(_, value) control:SetKey(value) end,
        Get = function() return control:GetKey() end,
      })
    end
    if modeFlag then
      section.library:RegisterOption(modeFlag, {
        Set = function(_, value) control:SetKeybindMode(value) end,
        Get = function() return control:GetKeybindMode() end,
      })
    end
  end
  return control
end

function library:Checkbox(options)
  return self:Toggle(options)
end

function library:Keybind(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  options = options or {}
  local key = coerceKey(options.Default or options.default or Enum.KeyCode.Insert)
  local flag = options.Flag or options.flag
  local binding = false
  local row = controlBase(section, 24, true)
  local keybindNameLabel = controlLabel(row, options.Name or options.name or "Keybind", UDim2.new(1, -40, 1, 0), UDim2.fromOffset(0, 0), false)
  local bindButton = create("Frame", {
    Parent = row,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, 0, 0.5, 0),
    Size = UDim2.fromOffset(math.clamp(keybindWidth(keyName(key), 11, 24, 100) + 17, 39, 116), 20),
    AutomaticSize = Enum.AutomaticSize.None,
    BackgroundColor3 = theme.control,
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 8,
  })
  create("UISizeConstraint", {
    Parent = bindButton,
    MinSize = Vector2.new(39, 20),
    MaxSize = Vector2.new(116, 20),
  })
  corner(bindButton, 2)
  local bindStroke = stroke(bindButton, Color3.fromRGB(68, 69, 77), 0, 1)
  local standaloneBindGradient = create("UIGradient", {
    Parent = bindButton,
    Rotation = 90,
    Color = subtleControlSequence(),
  })
  local standaloneBindIcon = create("ImageLabel", {
    Parent = bindButton,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 4, 0.5, 0),
    Size = UDim2.fromOffset(11, 11),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://121978468376124",
    ImageColor3 = section.library.accent,
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = bindButton.ZIndex + 2,
  })
  local bindLabel = create("TextLabel", {
    Parent = bindButton,
    Position = UDim2.fromOffset(17, 0),
    Size = UDim2.new(1, -20, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = keyName(key),
    TextColor3 = theme.textMuted,
    TextSize = 11,
    Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = bindButton.ZIndex + 1,
  })

  local function refreshStandaloneBindVisuals()
    bindButton.AutomaticSize = Enum.AutomaticSize.None
    bindButton.BackgroundColor3 = theme.control
    bindButton.BackgroundTransparency = 0
    bindButton.BorderSizePixel = 0
    bindButton.ClipsDescendants = true
    bindButton.ZIndex = 8
    standaloneBindIcon.ZIndex = 10
    bindLabel.ZIndex = 9
    bindStroke.Color = Color3.fromRGB(68, 69, 77)
    bindStroke.Transparency = 0
    standaloneBindGradient.Color = subtleControlSequence()
  end

  local function updateStandaloneBindWidth(animated)
    if not binding then
      bindLabel.Text = keyName(key)
    end
    local width = math.clamp(keybindWidth(bindLabel.Text, 11, 24, 100) + 17, 39, 116)
    local target = UDim2.fromOffset(width, 20)
    refreshStandaloneBindVisuals()
    if animated then
      tween(bindButton, {Size = target, BackgroundTransparency = 0}, 0.10, Enum.EasingStyle.Quad)
    else
      bindButton.Size = target
    end
    keybindNameLabel.Size = UDim2.new(1, -(width + 10), 1, 0)
  end
  updateStandaloneBindWidth(false)
  if flag then
    section.library.flags[flag] = key
  end
  row.MouseEnter:Connect(function()
    tween(bindButton, {BackgroundColor3 = theme.controlHover, BackgroundTransparency = 0}, 0.055, Enum.EasingStyle.Linear)
    tween(bindLabel, {TextColor3 = theme.text}, 0.055, Enum.EasingStyle.Linear)
  end)
  row.MouseLeave:Connect(function()
    if not binding then
      tween(bindButton, {BackgroundColor3 = theme.control, BackgroundTransparency = 0}, 0.055, Enum.EasingStyle.Linear)
      tween(bindLabel, {TextColor3 = theme.textMuted}, 0.055, Enum.EasingStyle.Linear)
    end
  end)
  row.Activated:Connect(function()
    binding = true
    bindLabel.Text = "..."
    updateStandaloneBindWidth(true)
    tween(bindLabel, {TextColor3 = section.library.accent}, 0.06, Enum.EasingStyle.Linear)
    tween(bindStroke, {Color = section.library.accent}, 0.06, Enum.EasingStyle.Linear)
  end)
  connect(UserInputService.InputBegan, function(input, processed)
    local pressed = normalizeKey(input)
    if not pressed then
      return
    end
    if binding then
      binding = false
      if pressed == Enum.KeyCode.Escape then
        key = nil
      else
        key = pressed
      end
      bindLabel.Text = keyName(key)
      updateStandaloneBindWidth(true)
      tween(bindButton, {BackgroundColor3 = theme.control, BackgroundTransparency = 0}, 0.06, Enum.EasingStyle.Linear)
      tween(bindLabel, {TextColor3 = theme.textMuted}, 0.06, Enum.EasingStyle.Linear)
      tween(bindStroke, {Color = Color3.fromRGB(68, 69, 77)}, 0.06, Enum.EasingStyle.Linear)
      if flag then
        section.library.flags[flag] = key
      end
      fire(options.Changed or options.changed, key)
      return
    end
    if not processed and key and pressed == key then
      fire(options.Callback or options.callback, key)
    end
  end)
  section.window:RegisterAccent(function(color)
    standaloneBindIcon.ImageColor3 = color
    if binding then
      bindLabel.TextColor3 = color
      bindStroke.Color = color
    end
  end)
  local control = {
    Object = row,
    Set = function(_, newKey)
      key = coerceKey(newKey)
      bindLabel.Text = keyName(key)
      updateStandaloneBindWidth(true)
      if flag then
        section.library.flags[flag] = key
      end
      fire(options.Changed or options.changed, key)
    end,
    Get = function()
      return key
    end,
    RefreshKeybindWidth = function()
      bindLabel.Text = keyName(key)
      updateStandaloneBindWidth(false)
    end,
  }
  section.library:RegisterOption(flag, control)
  return control
end

function library:Colorpicker(options)
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  options = options or {}
  local currentColor = options.Default or options.default or Color3.fromRGB(0, 174, 255)
  local flag = options.Flag or options.flag
  local rainbowController
  local row = controlBase(section, options.Info and 38 or 24, true)
  local nameLabel = controlLabel(row, options.Name or options.name or "Color", UDim2.new(1, -42, 0, 24), UDim2.fromOffset(0, 0), false)
  if options.Info then
    local info = controlLabel(row, options.Info, UDim2.new(1, -42, 0, 14), UDim2.fromOffset(0, 22), true)
    info.TextSize = 11
  end
  local iconButton = create("ImageLabel", {
    Parent = row,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, 0, 0, 12),
    Size = UDim2.fromOffset(isMobileDevice and 26 or 20, isMobileDevice and 26 or 20),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://103592623663192",
    ImageColor3 = currentColor,
    ImageTransparency = 0,
    ScaleType = Enum.ScaleType.Fit,
    Active = true,
  })
  local iconStroke = stroke(iconButton, theme.outline, 1, 1)
  if flag then
    section.library.flags[flag] = currentColor
  end
  local control = {}

  local function setColor(color, invoke)
    if typeof(color) ~= "Color3" then
      return
    end
    currentColor = color
    iconButton.ImageColor3 = color
    if flag then
      section.library.flags[flag] = color
    end
    if invoke ~= false then
      fire(options.Callback or options.callback, color)
    end
  end

  local function openPopup()
    if rainbowController and rainbowController.ConsumeActivation() then
      return
    end
    section.library:ClosePopup()
    local hue, saturation, value = currentColor:ToHSV()
    local popupWidth = 206
    local popupHeight = 181
    local popupFrame = create("CanvasGroup", {
      Parent = section.window.Gui,
      Name = "ColorpickerPopup",
      Position = popupPosition(row, popupWidth, popupHeight, 5),
      Size = UDim2.fromOffset(popupWidth, popupHeight),
      BackgroundColor3 = Color3.fromRGB(28, 27, 33),
      BorderSizePixel = 0,
      ZIndex = 700,
      GroupTransparency = 1,
    })
    corner(popupFrame, 4)
    stroke(popupFrame, theme.outlineDark, 0, 1)
    stroke(popupFrame, Color3.fromRGB(53, 48, 63), 0, 1)
    local popupScale = create("UIScale", {
      Parent = popupFrame,
      Scale = 0.965,
    })
    local topIcon = create("ImageLabel", {
      Parent = popupFrame,
      Position = UDim2.fromOffset(9, 8),
      Size = UDim2.fromOffset(16, 16),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Image = "rbxassetid://103592623663192",
      ImageColor3 = currentColor,
      ScaleType = Enum.ScaleType.Fit,
      ZIndex = 702,
    })
    local hexLabel = create("TextBox", {
      Parent = popupFrame,
      Position = UDim2.fromOffset(34, 7),
      Size = UDim2.fromOffset(58, 20),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = "#" .. currentColor:ToHex(),
      TextColor3 = theme.textMuted,
      TextSize = 11,
      Font = Enum.Font.ArialBold,
      TextXAlignment = Enum.TextXAlignment.Left,
      ClearTextOnFocus = false,
      MultiLine = false,
      ZIndex = 702,
    })
    local rgbLabel = create("TextBox", {
      Parent = popupFrame,
      Position = UDim2.fromOffset(93, 7),
      Size = UDim2.new(1, -98, 0, 20),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = colorRGBText(currentColor),
      TextColor3 = theme.textMuted,
      TextSize = 11,
      Font = Enum.Font.ArialBold,
      TextXAlignment = Enum.TextXAlignment.Left,
      ClearTextOnFocus = false,
      MultiLine = false,
      ZIndex = 702,
    })
    local hueBar = create("Frame", {
      Parent = popupFrame,
      Position = UDim2.fromOffset(9, 34),
      Size = UDim2.fromOffset(17, 137),
      BackgroundColor3 = theme.white,
      BorderSizePixel = 0,
      ZIndex = 702,
    })
    corner(hueBar, 4)
    stroke(hueBar, theme.outlineDark, 0, 1)
    create("UIGradient", {
      Parent = hueBar,
      Rotation = 90,
      Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
        ColorSequenceKeypoint.new(0.16, Color3.fromHSV(0.16, 1, 1)),
        ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
        ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
        ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66, 1, 1)),
        ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
        ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1)),
      }),
    })
    local hueSelector = create("Frame", {
      Parent = popupFrame,
      AnchorPoint = Vector2.new(0.5, 0.5),
      Position = UDim2.new(0, 17, 0, 34 + hue * 137),
      Size = UDim2.fromOffset(15, 15),
      BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
      BorderSizePixel = 0,
      ZIndex = 706,
    })
    corner(hueSelector, 999)
    stroke(hueSelector, theme.white, 0, 2)
    stroke(hueSelector, theme.black, 0.48, 1)
    local svSquare = create("Frame", {
      Parent = popupFrame,
      Position = UDim2.fromOffset(36, 34),
      Size = UDim2.fromOffset(160, 137),
      BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
      BorderSizePixel = 0,
      ZIndex = 702,
      ClipsDescendants = true,
    })
    corner(svSquare, 3)
    stroke(svSquare, theme.outlineDark, 0, 1)
    local whiteOverlay = create("Frame", {
      Parent = svSquare,
      Size = UDim2.fromScale(1, 1),
      BackgroundColor3 = theme.white,
      BorderSizePixel = 0,
      ZIndex = 703,
    })
    create("UIGradient", {
      Parent = whiteOverlay,
      Rotation = 0,
      Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
      }),
    })
    local blackOverlay = create("Frame", {
      Parent = svSquare,
      Size = UDim2.fromScale(1, 1),
      BackgroundColor3 = theme.black,
      BorderSizePixel = 0,
      ZIndex = 704,
    })
    create("UIGradient", {
      Parent = blackOverlay,
      Rotation = 90,
      Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
      }),
    })
    local svSelector = create("Frame", {
      Parent = popupFrame,
      AnchorPoint = Vector2.new(0.5, 0.5),
      Position = UDim2.fromOffset(36 + saturation * 160, 34 + (1 - value) * 137),
      Size = UDim2.fromOffset(14, 14),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      ZIndex = 707,
    })
    corner(svSelector, 999)
    stroke(svSelector, theme.white, 0, 2)
    stroke(svSelector, theme.black, 0.34, 1)
    local hueInput = create("TextButton", {
      Parent = popupFrame,
      Position = hueBar.Position,
      Size = hueBar.Size,
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = "",
      AutoButtonColor = false,
      ZIndex = 710,
    })
    local svInput = create("TextButton", {
      Parent = popupFrame,
      Position = svSquare.Position,
      Size = svSquare.Size,
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      Text = "",
      AutoButtonColor = false,
      ZIndex = 710,
    })
    local draggingHue = false
    local draggingSV = false
    local activeHueInput
    local activeSVInput
    local updatingFields = false

    local function refresh(invoke, source)
      local color = Color3.fromHSV(hue, saturation, value)
      if invoke ~= false and rainbowController then
        rainbowController.SetEnabled(false)
      end
      svSquare.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
      hueSelector.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
      hueSelector.Position = UDim2.new(0, 17, 0, 34 + hue * 137)
      svSelector.Position = UDim2.fromOffset(36 + saturation * 160, 34 + (1 - value) * 137)
      topIcon.ImageColor3 = color
      updatingFields = true
      if source ~= "hex" and not hexLabel:IsFocused() then
        hexLabel.Text = "#" .. color:ToHex()
      end
      if source ~= "rgb" and not rgbLabel:IsFocused() then
        rgbLabel.Text = colorRGBText(color)
      end
      updatingFields = false
      setColor(color, invoke)
    end

    local function applyHexText()
      local color = parseHexColor(hexLabel.Text)
      if color then
        hue, saturation, value = color:ToHSV()
        refresh(true, "hex")
        return true
      end
      return false
    end

    local function applyRGBText()
      local color = parseRGBColor(rgbLabel.Text)
      if color then
        hue, saturation, value = color:ToHSV()
        refresh(true, "rgb")
        return true
      end
      return false
    end
    hexLabel:GetPropertyChangedSignal("Text"):Connect(function()
      if not updatingFields and hexLabel:IsFocused() then
        applyHexText()
      end
    end)
    rgbLabel:GetPropertyChangedSignal("Text"):Connect(function()
      if not updatingFields and rgbLabel:IsFocused() then
        applyRGBText()
      end
    end)
    hexLabel.FocusLost:Connect(function()
      if not applyHexText() then
        hexLabel.Text = "#" .. currentColor:ToHex()
      end
    end)
    rgbLabel.FocusLost:Connect(function()
      if not applyRGBText() then
        rgbLabel.Text = colorRGBText(currentColor)
      end
    end)

    local function updateHue(input)
      local ratio = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
      hue = ratio
      refresh(true)
    end

    local function updateSV(input)
      saturation = math.clamp((input.Position.X - svSquare.AbsolutePosition.X) / math.max(svSquare.AbsoluteSize.X, 1), 0, 1)
      value = 1 - math.clamp((input.Position.Y - svSquare.AbsolutePosition.Y) / math.max(svSquare.AbsoluteSize.Y, 1), 0, 1)
      refresh(true)
    end
    hueInput.InputBegan:Connect(function(input)
      if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
      end
      draggingHue = true
      activeHueInput = input
      tween(hueSelector, {Size = UDim2.fromOffset(17, 17)}, 0.05, Enum.EasingStyle.Linear)
      updateHue(input)
    end)
    svInput.InputBegan:Connect(function(input)
      if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
      end
      draggingSV = true
      activeSVInput = input
      tween(svSelector, {Size = UDim2.fromOffset(16, 16)}, 0.05, Enum.EasingStyle.Linear)
      updateSV(input)
    end)
    local hueMoveConnection
    local svMoveConnection
    local endConnection
    hueMoveConnection = UserInputService.InputChanged:Connect(function(input)
      if not draggingHue then
        return
      end
      if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
        return
      end
      if activeHueInput and activeHueInput.UserInputType == Enum.UserInputType.Touch and input ~= activeHueInput then
        return
      end
      updateHue(input)
    end)
    svMoveConnection = UserInputService.InputChanged:Connect(function(input)
      if not draggingSV then
        return
      end
      if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
        return
      end
      if activeSVInput and activeSVInput.UserInputType == Enum.UserInputType.Touch and input ~= activeSVInput then
        return
      end
      updateSV(input)
    end)
    endConnection = UserInputService.InputEnded:Connect(function(input)
      if input == activeHueInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingHue = false
        activeHueInput = nil
        tween(hueSelector, {Size = UDim2.fromOffset(15, 15)}, 0.07, Enum.EasingStyle.Back)
      end
      if input == activeSVInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSV = false
        activeSVInput = nil
        tween(svSelector, {Size = UDim2.fromOffset(14, 14)}, 0.07, Enum.EasingStyle.Back)
      end
    end)
    local lastRainbowVisualUpdate = 0
    local rainbowVisualConnection = RunService.RenderStepped:Connect(function()
      local now = os.clock()
      if rainbowController and rainbowController.GetEnabled() and now - lastRainbowVisualUpdate >= 1 / 30 then
        lastRainbowVisualUpdate = now
        hue, saturation, value = currentColor:ToHSV()
        refresh(false)
      end
    end)
    local popup = {
      Frame = popupFrame,
      Anchor = row,
    }
    function popup:Close()
      if hueMoveConnection then
        hueMoveConnection:Disconnect()
        hueMoveConnection = nil
      end
      if svMoveConnection then
        svMoveConnection:Disconnect()
        svMoveConnection = nil
      end
      if endConnection then
        endConnection:Disconnect()
        endConnection = nil
      end
      if rainbowVisualConnection then
        rainbowVisualConnection:Disconnect()
        rainbowVisualConnection = nil
      end
      tween(popupFrame, {GroupTransparency = 1}, 0.09, Enum.EasingStyle.Linear)
      tween(popupScale, {Scale = 0.97}, 0.09, Enum.EasingStyle.Linear)
      task.delay(0.095, function()
        if popupFrame.Parent then
          popupFrame:Destroy()
        end
      end)
    end
    section.library.currentPopup = popup
    tween(popupFrame, {GroupTransparency = 0}, 0.12, Enum.EasingStyle.Quad)
    tween(popupScale, {Scale = 1}, 0.14, Enum.EasingStyle.Back)
  end
  row.Activated:Connect(openPopup)
  rainbowController = createRainbowController(section, row, flag, setColor)
  control.Object = row
  control.Icon = iconButton
  control.Set = function(_, color)
    setColor(color, true)
  end
  control.Get = function()
    return currentColor
  end
  section.library:RegisterOption(flag, control)
  return control
end

function library:Separator()
  local section = self.Content and self or nil
  if not section then
    return nil
  end
  return create("Frame", {
    Parent = section.Content,
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = theme.outlineSoft,
    BackgroundTransparency = 0.22,
    BorderSizePixel = 0,
  })
end
library.window = library.Window
library.tab = library.Tab
library.subtab = library.SubTab
library.section = library.Section
library.label = library.Label
library.esppreview = library.ESPPreview
library.espPreview = library.ESPPreview
library.button = library.Button
library.buttonrow = library.ButtonRow
library.textbox = library.Textbox
library.dropdown = library.Dropdown
library.slider = library.Slider
library.toggle = library.Toggle
library.checkbox = library.Toggle
library.keybind = library.Keybind
library.colorpicker = library.Colorpicker
library.separator = library.Separator
library.seperator = library.Separator
library.unload = library.Unload

local function makeV23()
-- violet.lol v23 | categorized subtabs, reference-style example controls, nested toggle settings
-- Standalone client script: executes directly, constructs its own ScreenGui,
-- uses CoreGui/gethui when available and PlayerGui only as Studio fallback.
-- Appearance and visual coordinates are unchanged from V20.
-- This is a UI/settings library, not game-specific ESP/aimbot functionality.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local library = {
    gui = nil,
    window = nil,
    flags = {},
    tabs = {},
    controls = {},
    options = {},
    keybinds = {},
    callbacks = {},
    connections = {},
    activeTweens = setmetatable({}, {__mode = "k"}),
    visible = true,
}

local function guiParent()
    local customGetHui = gethui
    if type(customGetHui) == "function" then
        local ok, parent = pcall(customGetHui)
        if ok and typeof(parent) == "Instance" then return parent end
    end
    return CoreGui
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    local list = library.connections
    list[#list + 1] = connection
    return connection
end

function library:Unload()
    if self._unloading then return end
    self._unloading = true
    local list = self.connections
    for i = #list, 1, -1 do
        list[i]:Disconnect()
        list[i] = nil
    end
    for instance, tween in pairs(self.activeTweens) do
        if tween then pcall(function() tween:Cancel() end) end
        self.activeTweens[instance] = nil
    end
    local oldGui = self.gui
    self.gui = nil
    self.window = nil
    self.controls = {}
    self.options = {}
    self.keybinds = {}
    self.callbacks = {}
    if oldGui then pcall(function() oldGui:Destroy() end) end
    self._unloading = false
end

local W, H = 1282, 946
-- The reference library's default window is 600px wide. Keep our original
-- proportions and use ~603x445 physical pixels at ordinary screen sizes.
local MENU_SCALE = 0.47 -- Change to 0.50 for ~641x473, 0.55 for ~705x520.
-- Optional: set to a string to replace the automatic Roblox place name.
-- By default the place name is looked up at runtime, then displayed with
-- white brackets and an accent-colored name.
local GAME_NAME_OVERRIDE = nil
-- This asset is the nine-slice bevel texture used by the supplied reference UI.
-- Manual bevel edges remain visible if the asset is private/unavailable in-game.
local REFERENCE_BEVEL_ASSET = "rbxassetid://118318078814280"
local USE_REFERENCE_BEVEL = true -- Set false to use only built-in Frames/gradients.
local TEXT_SCALE = 1.15 -- Body/title text kept at V6 size; section headers slightly smaller.
local CUSTOM_FONT_FAMILY = nil -- Optional Roblox-accessible font-family asset in Studio.
local CUSTOM_BOLD_FONT_FAMILY = nil -- Optional published TahomaBold font-family asset.
-- Both source URLs below match the provided reference script's CustomFont loader.
-- The second regular URL is your earlier 8px Tahoma file as a fallback.
local TAHOMA_TTF_URLS = {
    "https://github.com/sametexe001/luas/raw/refs/heads/main/fonts/windows-xp-tahoma.ttf",
    "https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/fs-tahoma-8px.ttf",
}
local TAHOMA_BOLD_TTF_URLS = {
    "https://github.com/sametexe001/luas/raw/refs/heads/main/fonts/TAHOMA-8PT-BOLD-WINDOWS-XP.TTF",
}
-- Reference-inspired gradient header and star field. Both colors can also be
-- customized from Config and saved with a profile.
local HEADER_GRADIENT_LEFT_DEFAULT = Color3.fromRGB(128, 183, 255)
local HEADER_GRADIENT_RIGHT_DEFAULT = Color3.fromRGB(136, 121, 254)
local HEADER_STAR_IMAGE = "rbxassetid://129958829729923"
local COLOR_PICKER_ICON = "rbxassetid://103592623663192"
local HEADER_STARS_TWINKLE = true -- Set false for entirely stationary stars.

local C = {
    -- Dark, neutral charcoal: not the bright beveled palette from v2.
    window = Color3.fromRGB(34, 34, 34),
    header = Color3.fromRGB(21, 21, 21),
    sidebar = Color3.fromRGB(32, 32, 32),
    pane = Color3.fromRGB(35, 35, 35),
    paneHeader = Color3.fromRGB(23, 23, 23),
    input = Color3.fromRGB(26, 26, 26),
    inputLight = Color3.fromRGB(32, 32, 32),
    border = Color3.fromRGB(15, 15, 15),
    subtleBorder = Color3.fromRGB(49, 49, 49),
    separator = Color3.fromRGB(41, 41, 41),
    text = Color3.fromRGB(187, 187, 187),
    textDim = Color3.fromRGB(117, 117, 117),
    textBright = Color3.fromRGB(216, 216, 216),
    accent = Color3.fromRGB(220, 160, 239),
}
local EDGE = {
    -- Classic 1px bevel pairings: light on top/left, shadow on bottom/right.
    panelHi = Color3.fromRGB(57, 57, 57),
    panelLo = Color3.fromRGB(25, 25, 25),
    innerHi = Color3.fromRGB(48, 48, 48),
    innerLo = Color3.fromRGB(19, 19, 19),
    controlHi = Color3.fromRGB(72, 72, 72),
    controlLo = Color3.fromRGB(17, 17, 17),
    controlInsideHi = Color3.fromRGB(52, 52, 52),
    controlInsideLo = Color3.fromRGB(28, 28, 28),
}
-- Reference font workflow: save the raw .ttf, register it through
-- getcustomasset, write the font-family JSON, then use Font.new on that JSON.
-- This is supported ONLY in hosts providing those non-Studio APIs. In an
-- ordinary LocalScript, the readable built-in fonts are used instead.
local FONT = Enum.Font.Legacy
local fontFace = Font.fromEnum(FONT)
local titleFontFace = Font.fromEnum(Enum.Font.ArialBold)
local fontSource = "built-in fallback (Legacy)"
local titleFontSource = "built-in fallback (ArialBold)"

local function loadFontFromLocalAsset(fileStem, displayName, sources)
    if type(writefile) ~= "function" or type(getcustomasset) ~= "function" then
        error("writefile/getcustomasset are unavailable")
    end
    local ttfPath = "violetlol_" .. fileStem .. ".ttf"
    local familyPath = "violetlol_" .. fileStem .. ".json"
    local function validFont(data)
        if type(data) ~= "string" or #data < 1000 then return false end
        local signature = data:sub(1, 4)
        return signature == string.char(0, 1, 0, 0)
            or signature == "OTTO" or signature == "true" or signature == "ttcf"
    end
    local bytes
    if type(isfile) == "function" and type(readfile) == "function" and isfile(ttfPath) then
        local ok, saved = pcall(readfile, ttfPath)
        if ok and validFont(saved) then bytes = saved end
    end
    if not bytes then
        for _index_01 = 1, #sources do
            local url = sources[_index_01]
            local ok, downloaded = pcall(function() return game:HttpGet(url) end)
            if ok and validFont(downloaded) then
                bytes = downloaded
                break
            end
        end
    end
    if not bytes then error(displayName .. " font download failed") end
    writefile(ttfPath, bytes)
    task.wait(0.1)
    local descriptor = game:GetService("HttpService"):JSONEncode({
        name = displayName,
        faces = {{
            name = "Regular", weight = 400, style = "normal",
            assetId = getcustomasset(ttfPath),
        }},
    })
    writefile(familyPath, descriptor)
    task.wait(0.1)
    return Font.new(getcustomasset(familyPath))
end

local function tryFontFamily(asset)
    if type(asset) ~= "string" or asset == "" then return nil end
    local ok, value = pcall(function() return Font.new(asset) end)
    if ok then return value end
    return nil
end

-- Body/caption font: reference's TahomaXP.
local customRegular = tryFontFamily(CUSTOM_FONT_FAMILY)
if customRegular then
    fontFace, fontSource = customRegular, "custom Roblox Tahoma family"
else
    local ok, loaded = pcall(loadFontFromLocalAsset,
        "tahoma_xp", "violet.lol TahomaXP", TAHOMA_TTF_URLS)
    if ok and loaded then
        fontFace, fontSource = loaded, "reference TahomaXP (.ttf)"
    else
        warn("[violet.lol] TahomaXP unavailable; using Legacy fallback. " ..
             "Studio LocalScripts cannot use writefile/getcustomasset.")
    end
end

-- Heading font: reference's distinct TahomaBold file, used only for the
-- window title and section headers; other content stays regular TahomaXP.
local customBold = tryFontFamily(CUSTOM_BOLD_FONT_FAMILY)
if customBold then
    titleFontFace, titleFontSource = customBold, "custom Roblox TahomaBold family"
else
    local ok, loaded = pcall(loadFontFromLocalAsset,
        "tahoma_bold", "violet.lol TahomaBold", TAHOMA_BOLD_TTF_URLS)
    if ok and loaded then
        titleFontFace, titleFontSource = loaded, "reference TahomaBold (.ttf)"
    else
        warn("[violet.lol] TahomaBold unavailable; using ArialBold fallback.")
    end
end

-- Centralize text scaling so all controls, tooltips and popup menus get the
-- same modest boost. No changes to size/position or bevel design are needed.
local function create(className, properties)
 startupYield()
    local instance = Instance.new(className)
    -- Match reference-style declarations, parenting last so first render uses
    -- the complete set of properties (including the custom font).
    for property, value in pairs(properties or {}) do
        if property ~= "Parent" then instance[property] = value end
    end
    if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
        if properties and type(properties.TextSize) == "number" then
            instance.TextSize = math.max(1, math.floor(properties.TextSize * TEXT_SCALE + 0.5))
        end
        local ok = pcall(function() instance.FontFace = fontFace end)
        if not ok then instance.Font = FONT end
    end
    if properties then instance.Parent = properties.Parent end
    return instance
end

-- Reference menu timing: 0.15s Sine Out for controls, 0.20s fades,
-- Quart Out for slider dragging. Cancel a prior tween on that object to avoid
-- slider/keybind updates fighting one another during rapid interaction.
local TWEEN_DURATION = 0.15
local FADE_DURATION = 0.20
local activeTweens = library.activeTweens
local function animate(object, properties, duration, easing)
    if not object or not object.Parent then return nil end
    if activeTweens[object] then activeTweens[object]:Cancel() end
    local tween = TweenService:Create(object,
        TweenInfo.new(duration or TWEEN_DURATION,
            easing or Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        properties)
    activeTweens[object] = tween
    tween.Completed:Connect(function()
        if activeTweens[object] == tween then activeTweens[object] = nil end
    end)
    tween:Play()
    return tween
end

local function setHeadingFont(textObject)
    local ok = pcall(function() textObject.FontFace = titleFontFace end)
    if not ok then textObject.Font = Enum.Font.ArialBold end
    return textObject
end

local function edge(parent, color, thickness)
    return create("UIStroke", {Parent = parent, 
        Color = color or C.border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

-- Light/shadow edges are only one pixel each. Major panels get only a
-- subdued single-step bevel; widgets receive a sharper, two-step bevel.
-- Unlike the v2 design, there's no thick black UIStroke on every section.
local function bevel(parent, raised, z, subtle)
    z = z or (parent.ZIndex + 1)
    local topColor = C.subtleBorder
    local bottomColor = topColor
    local innerTopColor = Color3.fromRGB(34,34,34)
    local innerBottomColor = innerTopColor
    local function stripe(pos, size, color)
        return create("Frame", {Parent = parent, 
            Position = pos,
            Size = size,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = z,
        })
    end
    stripe(UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 1), topColor)
    stripe(UDim2.fromOffset(0, 1), UDim2.new(0, 1, 1, -2), topColor)
    stripe(UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1), bottomColor)
    stripe(UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, -1), bottomColor)
    if not subtle then
        stripe(UDim2.fromOffset(1, 1), UDim2.new(1, -2, 0, 1), innerTopColor)
        stripe(UDim2.fromOffset(1, 2), UDim2.new(0, 1, 1, -4), innerTopColor)
        stripe(UDim2.new(0, 1, 1, -2), UDim2.new(1, -2, 0, 1), innerBottomColor)
        stripe(UDim2.new(1, -2, 0, 1), UDim2.new(0, 1, 1, -2), innerBottomColor)
    end
end

-- Uniform panel rims: every side uses the same neutral gray.
local function directionalInset(parent, z, palette)
    palette = palette or {}
    local top = C.subtleBorder
    local left,bottom,right = top,top,top
    local insideTop = Color3.fromRGB(34,34,34)
    local insideLeft,insideBottom,insideRight = insideTop,insideTop,insideTop
    local pieces = {}
    local function line(name, pos, size, color)
        local f = create("Frame", {Parent = parent, 
            Name = name,
            Position = pos,
            Size = size,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = z,
        })
        pieces[#pieces + 1] = f
    end
    -- Bold outer rim: 2px, not a black UIStroke covering all four sides.
    line("InsetDarkTop", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 2), top)
    line("InsetDarkLeft", UDim2.fromOffset(0, 2), UDim2.new(0, 2, 1, -4), left)
    line("InsetLightBottom", UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2), bottom)
    line("InsetLightRight", UDim2.new(1, -2, 0, 2), UDim2.new(0, 2, 1, -4), right)
    -- Subtle secondary reflection lets each boundary look inset rather than flat.
    line("InsetInnerTop", UDim2.fromOffset(2, 2), UDim2.new(1, -4, 0, 1), insideTop)
    line("InsetInnerLeft", UDim2.fromOffset(2, 3), UDim2.new(0, 1, 1, -6), insideLeft)
    line("InsetInnerBottom", UDim2.new(0, 2, 1, -3), UDim2.new(1, -4, 0, 1), insideBottom)
    line("InsetInnerRight", UDim2.new(1, -3, 0, 3), UDim2.new(0, 1, 1, -6), insideRight)
    return pieces
end

-- Source uses a pixelated 9-slice image on its buttons, sliders, and fields.
-- Layer it *under* text/checkmarks, with native bevels as a robust fallback.
local function referenceSlice(parent, z, transparency)
    if not USE_REFERENCE_BEVEL then return nil end
    return create("ImageLabel", {Parent = parent, 
        Name = "ReferenceBevel9Slice",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = REFERENCE_BEVEL_ASSET,
        ImageTransparency = transparency or 0.27,
        ImageColor3 = Color3.fromRGB(245, 245, 245),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(Vector2.new(2, 2), Vector2.new(3, 3)),
        ResampleMode = Enum.ResamplerMode.Pixelated,
        ZIndex = z or (parent.ZIndex + 2),
    })
end

local function gloss(parent, top, bottom)
    -- UIGradient multiplies the underlying BackgroundColor3, so white is
    -- required for these exact dark grey gradient stops to stay visible.
    parent.BackgroundColor3 = Color3.new(1, 1, 1)
    return create("UIGradient", {Parent = parent, 
        Color = ColorSequence.new(top, bottom),
        Rotation = 90,
    })
end

local function rect(parent, x, y, w, h, background, z)
    return create("Frame", {Parent = parent, 
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = background,
        BorderSizePixel = 0,
        ZIndex = z or 2,
    })
end

local function label(parent, text, x, y, w, h, size, color, z)
    return create("TextLabel", {Parent = parent, 
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = color or C.text,
        TextSize = size or 21,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Font = FONT,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = z or 5,
    })
end

local function button(parent, text, x, y, w, h, z)
    z = z or 5
    local b = create("TextButton", {Parent = parent, 
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = C.input,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = z,
    })
    -- Reuse the reference's bevel slice at restrained opacity. Text is separate
    -- so the sliced image can never obscure the caption.
    local buttonGradient = gloss(b, Color3.fromRGB(48, 48, 48), Color3.fromRGB(29, 29, 29))
    bevel(b, true, z + 1)
    local texture = referenceSlice(b, z + 2, 0.19)
    local caption = label(b, text, 3, 1, w - 6, h - 2, 21, C.text, z + 3)
    caption.TextXAlignment = Enum.TextXAlignment.Center
    local pressed = false
    local function restyle()
        if pressed then
            animate(caption, {Position = UDim2.fromOffset(4, 2)}, 0.10)
            buttonGradient.Color = ColorSequence.new(Color3.fromRGB(29, 29, 29), Color3.fromRGB(40, 40, 40))
            if texture then animate(texture, {ImageTransparency = 0.36}, 0.10) end
        else
            animate(caption, {Position = UDim2.fromOffset(3, 1)}, 0.12)
            buttonGradient.Color = ColorSequence.new(Color3.fromRGB(48, 48, 48), Color3.fromRGB(29, 29, 29))
            if texture then animate(texture, {ImageTransparency = 0.19}, 0.12) end
        end
    end
    b.MouseButton1Down:Connect(function() pressed = true; restyle() end)
    b.MouseButton1Up:Connect(function() pressed = false; restyle() end)
    b.MouseLeave:Connect(function() pressed = false; restyle() end)
    -- Existing call sites may update b.Text; reroute visible label updates.
    b:GetPropertyChangedSignal("Text"):Connect(function()
        if b.Text ~= "" then
            caption.Text = b.Text
            b.Text = ""
        end
    end)
    return b
end

local function textBox(parent, placeholder, x, y, w, h, z)
    z = z or 5
    local field = rect(parent, x, y, w, h, C.input, z)
    gloss(field, Color3.fromRGB(23, 23, 23), Color3.fromRGB(31, 31, 31))
    bevel(field, false, z + 1)
    referenceSlice(field, z + 2, 0.27)
    local box = create("TextBox", {Parent = parent, 
        Position = UDim2.fromOffset(x + 4, y + 2),
        Size = UDim2.fromOffset(w - 8, h - 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = C.textDim,
        TextColor3 = C.textBright,
        Font = FONT,
        TextSize = 21,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = z + 3,
    })
    create("UIPadding", {Parent = box, PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)})
    return box, field
end

function library:Window(options)
    options = options or {}
    if self.gui then self:Unload() end
    if typeof(options.AccentColor) == "Color3" then C.accent = options.AccentColor end
    if typeof(options.HeaderGradientLeft) == "Color3" then
        HEADER_GRADIENT_LEFT_DEFAULT = options.HeaderGradientLeft
    end
    if typeof(options.HeaderGradientRight) == "Color3" then
        HEADER_GRADIENT_RIGHT_DEFAULT = options.HeaderGradientRight
    end
    self.flags = options.SharedFlags or {}
    self.tabs = {}
    self.controls = {}
    self.options = {}
    self.keybinds = {}
    self.callbacks = {}
    self.visible = true
    local name = options.GuiName or "VioletLOL"
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        local prior = playerGui:FindFirstChild(name)
        if prior then prior:Destroy() end
    end
    local root = guiParent()
    local found, previous = pcall(function() return root:FindFirstChild(name) end)
    if found and previous then previous:Destroy() end
    local gui = create("ScreenGui", {Parent = nil,
    Name = name,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 20,
})
-- CoreGui/gethui mirrors the supplied reference; ordinary Studio clients
-- cannot write to CoreGui, so PlayerGui is a compatibility fallback.
local parented = pcall(function() gui.Parent = root end)
if not parented then
    local fallback = player:WaitForChild("PlayerGui")
    local prior = fallback:FindFirstChild(name)
    if prior then prior:Destroy() end
    gui.Parent = fallback
end
self.gui = gui
connect(gui.Destroying, function()
    if self.gui == gui then
        self.gui = nil
        self:Unload()
    end
end)
gui:SetAttribute("FontSource", fontSource)
gui:SetAttribute("TitleFontSource", titleFontSource)
local changed = create("BindableEvent", {Parent = gui, Name = "SettingChanged"})
local state = self.flags
local unlocked = options.KeySystem == false
gui:SetAttribute("AccessGranted",unlocked)
self.SettingChanged = changed.Event
local updaters = {}
local permanentUpdaters = {}
local visibleCheckmarks = {}
local visibleSliders = {}
local refreshAccent = function() end
local function attributeName(key)
    return (key:gsub("[^%w_]", "_"))
end
local function setSetting(key, value)
    if state[key] == value then return end
    if key == "theme.accent" and typeof(value) == "Color3" then
        C.accent = value
    end
    state[key] = value
    gui:SetAttribute(attributeName(key), value)
    if updaters[key] then updaters[key](value) end
    if key == "theme.accent" then refreshAccent() end
    changed:Fire(key, value)
    local listeners = self.callbacks[key]
    if listeners then
        for i = 1, #listeners do
            local control = listeners[i]
            if control.Callback then
                local ok, err = pcall(control.Callback, value, control)
                if not ok then warn("[violet.lol] Control callback failed for " .. key .. ": " .. tostring(err)) end
            end
        end
    end
end
local function ensureSetting(key, default)
    if state[key] == nil then setSetting(key, default) end
    return state[key]
end

function self:SetFlag(key, value)
    setSetting(key, value)
end
function self:GetFlag(key)
    return state[key]
end
function self:GetOption(key)
    return self.options[key]
end

local window = rect(gui, 0, 0, W, H, C.window, 1)
window.Visible = unlocked
self.window = window
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.new(0.5, 0, 0.5, 0)
-- The sole strongly dark outline is the outer edge of the full window.
edge(window, Color3.fromRGB(8, 14, 25), 2)
gloss(window, Color3.fromRGB(38, 38, 38), Color3.fromRGB(33, 33, 33))
-- Muted cobalt border closely follows the screenshot's outer blue rim.
rect(window, 1, 1, W - 2, 2, Color3.fromRGB(44, 61, 87), 2)
local actualScale = MENU_SCALE
if typeof(options.Size) == "UDim2" and options.Size.X.Offset > 0 and options.Size.Y.Offset > 0 then
    actualScale = math.min(options.Size.X.Offset / W, options.Size.Y.Offset / H)
end
local scaler = create("UIScale", {Parent = window, Scale = actualScale})

local scaleNow = actualScale
local previewPanel, previewScaler
local PREVIEW_PANEL_W, PREVIEW_PANEL_H = 340, 418
local PREVIEW_GAP = 18
local function positionPreviewPanel()
    if not previewPanel or not previewPanel.Parent then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local view = cam.ViewportSize
    local previewScale = previewScaler and previewScaler.Scale or 1
    local width = PREVIEW_PANEL_W * previewScale
    local gap = PREVIEW_GAP
    local right = window.AbsolutePosition.X + window.AbsoluteSize.X + gap
    local left = window.AbsolutePosition.X - width - gap
    local detached = previewPanel:GetAttribute("Detached")
    local x = detached and previewPanel.Position.X.Offset
        or (right + width <= view.X - 8 and right or left)
    x = math.clamp(x, 8, math.max(8, view.X - width - 8))
    local y = math.clamp(detached and previewPanel.Position.Y.Offset or window.AbsolutePosition.Y, 8,
        math.max(8, view.Y - PREVIEW_PANEL_H * previewScale - 8))
    previewPanel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end
local function resize()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local view = cam.ViewportSize
    local touch=UserInputService.TouchEnabled
    scaleNow = math.min(touch and math.max(actualScale,.6) or actualScale, (view.X - 20) / W, (view.Y - (touch and 76 or 20)) / H)
    scaler.Scale = math.max(0.1, scaleNow)
    scaleNow = scaler.Scale
    local half=Vector2.new(W*scaleNow/2,window.Size.Y.Offset*scaleNow/2)
    local center=Vector2.new(window.Position.X.Scale*view.X+window.Position.X.Offset,window.Position.Y.Scale*view.Y+window.Position.Y.Offset)
    window.Position=UDim2.fromOffset(math.clamp(center.X,half.X+8,math.max(half.X+8,view.X-half.X-8)),
        math.clamp(center.Y,half.Y+8,math.max(half.Y+8,view.Y-half.Y-8)))
    if previewScaler then previewScaler.Scale = math.min(UserInputService.TouchEnabled and .8 or 1,
        (view.X-16)/PREVIEW_PANEL_W,(view.Y-16)/PREVIEW_PANEL_H) end
    positionPreviewPanel()
end
connect(window:GetPropertyChangedSignal("AbsolutePosition"), positionPreviewPanel)
connect(window:GetPropertyChangedSignal("AbsoluteSize"), positionPreviewPanel)
local cameraSizeConnection
local function watchCamera()
    if cameraSizeConnection then
        cameraSizeConnection:Disconnect()
        cameraSizeConnection = nil
    end
    if workspace.CurrentCamera then
        cameraSizeConnection = connect(
            workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), resize)
    end
    resize()
end
watchCamera()
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)

local titleBar = rect(window, 3, 3, W - 6, 52, Color3.new(1, 1, 1), 3)
titleBar.Name = "GradientHeader"
-- Same two-stop, left-to-right gradient as the supplied reference menu.
-- UIGradient multiplies BackgroundColor3, so the header uses a WHITE base.
local headerGradient = create("UIGradient", {Parent = titleBar, 
    Rotation = 0,
    Color = ColorSequence.new(HEADER_GRADIENT_LEFT_DEFAULT, HEADER_GRADIENT_RIGHT_DEFAULT),
})
local function applyHeaderGradient()
    local left = state["theme.header_left"] or HEADER_GRADIENT_LEFT_DEFAULT
    local right = state["theme.header_right"] or HEADER_GRADIENT_RIGHT_DEFAULT
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, left),
        ColorSequenceKeypoint.new(1, right),
    })
end
permanentUpdaters["theme.header_left"] = applyHeaderGradient
permanentUpdaters["theme.header_right"] = applyHeaderGradient
updaters["theme.header_left"] = applyHeaderGradient
updaters["theme.header_right"] = applyHeaderGradient
ensureSetting("theme.header_left", HEADER_GRADIENT_LEFT_DEFAULT)
ensureSetting("theme.header_right", HEADER_GRADIENT_RIGHT_DEFAULT)
applyHeaderGradient()
-- Delicate light edge at top; dark rim at the bottom, matching the inset UI.
local headerTopEdge = rect(titleBar, 0, 0, W - 6, 1, Color3.fromRGB(255, 255, 255), 4)
headerTopEdge.BackgroundTransparency = 0.64
local headerBottomEdge = rect(titleBar, 0, 51, W - 6, 1, Color3.fromRGB(30, 26, 68), 4)
headerBottomEdge.BackgroundTransparency = 0.32

-- Original reference's 16 white four-point star images, distributed across the
-- strip. Star coordinates and sizes below are *visible* pixels, compensating
-- for the main window's UIScale so the designs remain legible at 0.47 scale.
local starLayer = create("Frame", {Parent = titleBar, 
    Name = "Stars",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    ClipsDescendants = true,
    ZIndex = 5,
})
local STAR_LAYOUT = {
    {x=.20,y=5,size=12,alpha=.17,rot=-12},
    {x=.24,y=17,size=15,alpha=.29,rot=94},
    {x=.28,y=5,size=11,alpha=.12,rot=-82},
    {x=.33,y=15,size=14,alpha=.23,rot=8},
    {x=.38,y=6,size=12,alpha=.16,rot=-78},
    {x=.43,y=18,size=15,alpha=.27,rot=93},
    {x=.48,y=6,size=12,alpha=.16,rot=-82},
    {x=.53,y=16,size=15,alpha=.23,rot=98},
    {x=.58,y=6,size=12,alpha=.26,rot=91},
    {x=.63,y=17,size=14,alpha=.14,rot=-85},
    {x=.68,y=6,size=13,alpha=.34,rot=2},
    {x=.73,y=17,size=15,alpha=.17,rot=-84},
    {x=.78,y=7,size=12,alpha=.18,rot=92},
    {x=.83,y=17,size=14,alpha=.23,rot=-82},
    {x=.88,y=7,size=12,alpha=.18,rot=4},
    {x=.93,y=16,size=15,alpha=.26,rot=-86},
}
local stars = {}
local function refreshStarScale()
    local factor = math.max(0.25, scaler.Scale)
    for i = 1, #STAR_LAYOUT do
        local info = STAR_LAYOUT[i]
        local star = stars[i]
        if star and star.Parent then
            local size = math.max(1, math.floor(info.size / factor + .5))
            star.Position = UDim2.new(info.x, 0, 0, math.floor(info.y / factor + .5))
            star.Size = UDim2.fromOffset(size, size)
        end
    end
end
for i = 1, #STAR_LAYOUT do
    local info = STAR_LAYOUT[i]
    local star = create("ImageLabel", {Parent = starLayer, 
        Name = "Star_" .. i,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(.5,.5),
        Position = UDim2.new(info.x,0,0,info.y),
        Size = UDim2.fromOffset(info.size, info.size),
        Rotation = info.rot,
        Image = HEADER_STAR_IMAGE,
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        ImageTransparency = info.alpha,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 6,
    })
    stars[i] = star
    if HEADER_STARS_TWINKLE then
        task.spawn(function()
            task.wait((i * .173) % .9)
            local duration = .75 + (i % 5) * .15
            local dim = math.min(.84, info.alpha + .40)
            while gui.Parent and star.Parent do
                local fadeOut = TweenService:Create(star,
                    TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    {ImageTransparency = dim, Rotation = info.rot + 7})
                fadeOut:Play()
                fadeOut.Completed:Wait()
                if not star.Parent or not gui.Parent then break end
                local fadeIn = TweenService:Create(star,
                    TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    {ImageTransparency = info.alpha, Rotation = info.rot})
                fadeIn:Play()
                fadeIn.Completed:Wait()
            end
        end)
    end
end
refreshStarScale()
connect(scaler:GetPropertyChangedSignal("Scale"), refreshStarScale)

-- Use an automatic horizontal layout instead of guessing how wide "violet"
-- is. Different Tahoma font hosts have different glyph metrics; AutoSize and
-- UIListLayout make overlap impossible even when a custom font loads late.
local titleTextRow = rect(titleBar, 18, 6, 350, 38, C.header, 22)
titleTextRow.BackgroundTransparency = 1
create("UIListLayout", {Parent = titleTextRow, 
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
})
local mainTitle = setHeadingFont(label(titleTextRow, options.TitlePrefix or "violet", 0, 0, 0, 38, 24,
    Color3.fromRGB(255, 255, 255), 23))
mainTitle.LayoutOrder = 1
mainTitle.AutomaticSize = Enum.AutomaticSize.X
mainTitle.TextTruncate = Enum.TextTruncate.None
mainTitle.TextWrapped = false
mainTitle.TextStrokeColor3 = Color3.fromRGB(44, 37, 77)
mainTitle.TextStrokeTransparency = 0.64
local titleSuffix = setHeadingFont(label(titleTextRow, options.TitleSuffix or ".lol", 0, 0, 0, 38, 24, C.accent, 23))
titleSuffix.LayoutOrder = 2
titleSuffix.AutomaticSize = Enum.AutomaticSize.X
titleSuffix.TextTruncate = Enum.TextTruncate.None
titleSuffix.TextWrapped = false
-- UIShadow cannot cast a shadow from individual glyphs; on TextLabels it
-- shadows their rectangular bounds. Two soft UIStrokes instead produce a
-- subtle, letter-shaped accent halo that follows the live theme color.
local titleGlowOuter = create("UIStroke", {Parent = titleSuffix, 
    Name = "AccentTextGlowOuter",
    ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
    Color = C.accent, Thickness = 4.0, Transparency = 0.81,
    LineJoinMode = Enum.LineJoinMode.Round,
    ZIndex = -2,
})
local titleGlowInner = create("UIStroke", {Parent = titleSuffix, 
    Name = "AccentTextGlowInner",
    ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
    Color = C.accent, Thickness = 2.0, Transparency = 0.67,
    LineJoinMode = Enum.LineJoinMode.Round,
    ZIndex = -1,
})
titleSuffix.TextStrokeColor3 = C.accent
titleSuffix.TextStrokeTransparency = 0.79

-- Gradient colors are independent of the accent color and save with configs.

-- Drag the window by its title strip.
local moving, dragOrigin, startWindowPosition,windowPointer
local function dragStart(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        moving = true
        windowPointer=input
        dragOrigin = input.Position
        startWindowPosition = window.Position
    end
end
titleBar.Active=true
titleBar.InputBegan:Connect(dragStart)
connect(UserInputService.InputChanged, function(input)
    if moving and (input.UserInputType == Enum.UserInputType.MouseMovement and windowPointer.UserInputType~=Enum.UserInputType.Touch or input==windowPointer) then
        local offset = input.Position - dragOrigin
        window.Position = UDim2.new(
            startWindowPosition.X.Scale, startWindowPosition.X.Offset + offset.X,
            startWindowPosition.Y.Scale, startWindowPosition.Y.Offset + offset.Y
        )
        resize()
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input==windowPointer then
        moving = false
        windowPointer=nil
    end
end)

-- The content ends above the compact, full-width status footer.
-- Both columns keep their original horizontal positions and bevel treatment.
local sidebar = rect(window, 20, 79, 255, 762, C.sidebar, 2)
-- Distinct recessed nav-list box: left and top dark, bottom highlighted.
-- Layered, directional lines stay visible even when the whole menu is scaled.
gloss(sidebar, Color3.fromRGB(35, 35, 35), Color3.fromRGB(30, 30, 30))
directionalInset(sidebar, 4, {
    top = Color3.fromRGB(13, 13, 13), left = Color3.fromRGB(10, 10, 10),
    bottom = Color3.fromRGB(78, 78, 78), right = Color3.fromRGB(61, 61, 61),
    insideTop = Color3.fromRGB(27, 27, 27),
    insideBottom = Color3.fromRGB(50, 50, 50),
})
-- Slim, full-width footer replacing the old sidebar-only profile card.
-- At 0.47 scale this is ~34px high and spans the same margins as the menu.
local profile = rect(window, 20, 854, W - 40, 72, C.sidebar, 3)
profile.Name = "StatusFooter"
gloss(profile, Color3.fromRGB(39, 39, 39), Color3.fromRGB(29, 29, 29))
directionalInset(profile, 4, {
    top = Color3.fromRGB(13, 13, 13), left = Color3.fromRGB(12, 12, 12),
    bottom = Color3.fromRGB(78, 78, 78), right = Color3.fromRGB(61, 61, 61),
    insideTop = Color3.fromRGB(26, 26, 26),
    insideBottom = Color3.fromRGB(50, 50, 50),
})
local avatar = create("ViewportFrame", {Parent = profile, 
    Position = UDim2.fromOffset(11, 8),
    Size = UDim2.fromOffset(56, 56),
    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
    BorderSizePixel = 0,
    Ambient = Color3.fromRGB(180, 180, 180),
    LightColor = Color3.fromRGB(255, 255, 255),
    LightDirection = Vector3.new(-0.5, -1, -0.3),
    ZIndex = 5,
})
edge(avatar, C.subtleBorder, 1)
local world = create("WorldModel", {Parent = avatar})
local avatarCamera = create("Camera", {Parent = avatar})
avatar.CurrentCamera = avatarCamera
local fallbackAvatar = label(profile, "◉", 18, 9, 41, 52, 32, C.textDim, 6)
fallbackAvatar.TextXAlignment = Enum.TextXAlignment.Center

-- One inline greeting: regular TahomaXP followed by bold accent username.
-- UIListLayout + AutomaticSize keeps variable-width names from overlapping.
local welcomeRow = rect(profile, 84, 10, 660, 52, C.sidebar, 5)
welcomeRow.Name = "WelcomeRow"
welcomeRow.BackgroundTransparency = 1
create("UIListLayout", {Parent = welcomeRow, 
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 9),
})
local welcomeText = label(welcomeRow, "Welcome Back,", 0, 0, 0, 46, 22,
    Color3.fromRGB(255, 255, 255), 6)
welcomeText.LayoutOrder = 1
welcomeText.AutomaticSize = Enum.AutomaticSize.X
welcomeText.TextTruncate = Enum.TextTruncate.None
welcomeText.TextWrapped = false
local usernameText = setHeadingFont(label(welcomeRow, player.Name,
    0, 0, 0, 46, 25, C.accent, 6))
usernameText.Name = "AccentUsername"
usernameText.LayoutOrder = 2
usernameText.AutomaticSize = Enum.AutomaticSize.X
usernameText.TextTruncate = Enum.TextTruncate.AtEnd
usernameText.TextWrapped = false
create("UISizeConstraint", {Parent = usernameText, MaxSize = Vector2.new(420, 46)})

-- Flat, accent-colored TahomaBold username: no UIStroke, halo, glimmer,
-- gradient or pulsing animation. Keep the username readable at menu scale.
usernameText.TextStrokeTransparency = 1

-- Compact developer rank, integrated into the horizontal welcome row.
-- It automatically follows usernames of different widths, has perfectly
-- square corners (no UICorner) and matches the dark inset footer styling.
local developerBadge = create("Frame", {Parent = welcomeRow, 
    Name = "DeveloperRankBadge",
    Size = UDim2.fromOffset(130, 36),
    BackgroundColor3 = Color3.fromRGB(27, 27, 29),
    BorderSizePixel = 0,
    LayoutOrder = 3,
    ZIndex = 6,
})
edge(developerBadge, Color3.fromRGB(11, 11, 12), 2)
local developerInnerBorder = create("UIStroke", {Parent = developerBadge, 
    Name = "RankInnerEdge",
    Color = Color3.fromRGB(64, 64, 67),
    Transparency = 0.45,
    Thickness = 1,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})
local developerText = label(developerBadge, "Developer", 5, 0, 120, 36, 20,
    Color3.fromRGB(207, 207, 211), 8)
developerText.Name = "DeveloperRankText"
developerText.TextXAlignment = Enum.TextXAlignment.Center
developerText.TextTruncate = Enum.TextTruncate.None

-- Bracketed actual game/place name, aligned to the far-right edge.
-- The override is optional and can be changed near MENU_SCALE above.
local function nonemptyName(value)
    if type(value) ~= "string" then return nil end
    local cleaned = value:gsub("^%s+", ""):gsub("%s+$", "")
    if cleaned == "" or cleaned == "Game" then return nil end
    return cleaned
end
local initialGameName = nonemptyName(GAME_NAME_OVERRIDE)
    or nonemptyName(game.Name) or "Game Name"
-- Keep brackets PURE WHITE; only the name between them uses the accent.
-- A right-aligned horizontal layout keeps all three pieces together even
-- if the game's title changes after the MarketplaceService lookup.
local gameNameRow = rect(profile, 755, 12, 458, 48, C.sidebar, 5)
gameNameRow.Name = "GameNameRow"
gameNameRow.BackgroundTransparency = 1
create("UIListLayout", {Parent = gameNameRow, 
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
})
local openingBracket = setHeadingFont(label(gameNameRow, "[ ",
    0, 0, 0, 46, 23, Color3.fromRGB(255, 255, 255), 6))
openingBracket.LayoutOrder = 1
openingBracket.AutomaticSize = Enum.AutomaticSize.X
openingBracket.TextTruncate = Enum.TextTruncate.None
local gameNameText = setHeadingFont(label(gameNameRow, initialGameName,
    0, 0, 0, 46, 23, C.accent, 6))
gameNameText.Name = "AccentGameName"
gameNameText.LayoutOrder = 2
gameNameText.AutomaticSize = Enum.AutomaticSize.X
gameNameText.TextTruncate = Enum.TextTruncate.AtEnd
gameNameText.TextWrapped = false
create("UISizeConstraint", {Parent = gameNameText, MaxSize = Vector2.new(376, 46)})
local closingBracket = setHeadingFont(label(gameNameRow, " ]",
    0, 0, 0, 46, 23, Color3.fromRGB(255, 255, 255), 6))
closingBracket.LayoutOrder = 3
closingBracket.AutomaticSize = Enum.AutomaticSize.X
closingBracket.TextTruncate = Enum.TextTruncate.None

task.spawn(function()
    if nonemptyName(GAME_NAME_OVERRIDE) or game.PlaceId <= 0 then return end
    -- GetProductInfo gives us the real place title on published games;
    -- no blocking HTTP call is required before the menu first appears.
    local MarketplaceService = game:GetService("MarketplaceService")
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if ok and type(info) == "table" then
        local name = nonemptyName(info.Name)
        if name and gameNameText.Parent then
            gameNameText.Text = name
        end
    end
end)

-- Build an outfit-complete rig. V13 anchored the body/accessory handles
-- BEFORE the WorldModel simulated their AccessoryWelds and then destroyed
-- those welds. That is why hats/hair/layered clothing disappeared or floated
-- offscreen. The model is assembled first, with welds INTACT, and frozen only
-- after accessories have been fitted. Every visible part then rotates around
-- the same stationary torso axis; the camera never moves.
task.spawn(function()
    local function createOutfitModel()
        -- New Roblox avatar APIs, with backwards compatibility for older builds.
        local ok, result = pcall(function()
            return Players:CreateHumanoidModelFromUserIdAsync(player.UserId)
        end)
        if ok and result then return result end

        local okDesc, description = pcall(function()
            return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
        end)
        if okDesc and description then
            local rigType = Enum.HumanoidRigType.R15
            local liveHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if liveHumanoid then rigType = liveHumanoid.RigType end
            local okModel, built = pcall(function()
                return Players:CreateHumanoidModelFromDescriptionAsync(description, rigType)
            end)
            if okModel and built then return built end
        end
        local okOld, oldModel = pcall(function()
            return Players:CreateHumanoidModelFromUserId(player.UserId)
        end)
        if okOld then return oldModel end
        return nil
    end

    local model = createOutfitModel()
    if not model or not gui.Parent then
        if model then model:Destroy() end
        warn("[violet.lol] The viewport avatar could not load.")
        return
    end
    model.Name = "RotatingAvatar"
    local scriptDescendants = model:GetDescendants()
    for childIndex = 1, #scriptDescendants do
        local child = scriptDescendants[childIndex]
        if child:IsA("Script") or child:IsA("LocalScript") then
            child:Destroy()
        end
    end
    local bodyRoot = model:FindFirstChild("HumanoidRootPart", true)
        or model:FindFirstChild("UpperTorso", true)
        or model:FindFirstChild("Torso", true)
    -- Anchor ONLY the central root during the rig's initial settle phase.
    -- Leave accessory handles unanchored until their welds have positioned them.
    if bodyRoot then bodyRoot.Anchored = true end
    model.Parent = world
    for _ = 1, 4 do RunService.Heartbeat:Wait() end
    if not model.Parent or not gui.Parent then
        model:Destroy()
        return
    end

    -- Position accessory handles explicitly from their matching attachments.
    -- This also covers Roblox clients that don't fully simulate WorldModel
    -- welds during their initial frame. Preserve all extra parts of each item.
    local fittedAccessories = 0
    local attachmentByName = {}
    local rigDescendants = model:GetDescendants()
    for i = 1, #rigDescendants do
        local part = rigDescendants[i]
        if part:IsA("Attachment") and part.Parent:IsA("BasePart")
            and not part:FindFirstAncestorOfClass("Accessory")
            and not attachmentByName[part.Name] then
            attachmentByName[part.Name] = part
        end
    end
    local avatarChildren = model:GetChildren()
    for accessoryIndex = 1, #avatarChildren do
        local accessory = avatarChildren[accessoryIndex]
        if accessory:IsA("Accessory") then
            local handle = accessory:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local desired
                local handleDescendants = handle:GetDescendants()
                for attachmentIndex = 1, #handleDescendants do
                    local localAttach = handleDescendants[attachmentIndex]
                    if localAttach:IsA("Attachment") then
                        local rigAttach = attachmentByName[localAttach.Name]
                        if rigAttach then
                            desired = rigAttach.WorldCFrame * localAttach.CFrame:Inverse()
                        end
                    end
                    if desired then break end
                end
                -- The existing AccessoryWeld is a reliable fallback for
                -- unusual rigid/layered accessories with no named attachment.
                if not desired then
                    local weld = handle:FindFirstChild("AccessoryWeld")
                    if weld and weld:IsA("Weld") then
                        if weld.Part0 == handle and weld.Part1 then
                            desired = weld.Part1.CFrame * weld.C1 * weld.C0:Inverse()
                        elseif weld.Part1 == handle and weld.Part0 then
                            desired = weld.Part0.CFrame * weld.C0 * weld.C1:Inverse()
                        end
                    end
                end
                if desired then
                    local change = desired * handle.CFrame:Inverse()
                    local accessoryParts = accessory:GetDescendants()
                    for partIndex = 1, #accessoryParts do
                        local part = accessoryParts[partIndex]
                        if part:IsA("BasePart") then
                            part.CFrame = change * part.CFrame
                        end
                    end
                    fittedAccessories += 1
                end
            end
        end
    end

    local parts = {}
    local avatarDescendants = model:GetDescendants()
    for partIndex = 1, #avatarDescendants do
        local descendant = avatarDescendants[partIndex]
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            parts[#parts + 1] = descendant
        end
    end
    -- Keep welds and layered clothing instances present; the static anchored
    -- rig doesn't need them to perform motion, but deleting them can remove
    -- the accessory binding that Roblox needs for display.
    local bounds, dimensions = model:GetBoundingBox()
    local centerRoot = bodyRoot and bodyRoot.Position or bounds.Position
    local axisPosition = Vector3.new(centerRoot.X, centerRoot.Y + 0.25, centerRoot.Z)
    local axisInverse = CFrame.new(-axisPosition)
    local localPartCFrames = {}
    for i = 1, #parts do
        local part = parts[i]
        localPartCFrames[i] = axisInverse * part.CFrame
    end
    local function setAvatarAngle(angle)
        local spin = CFrame.Angles(0, angle, 0)
        for i = 1, #parts do
            local part = parts[i]
            part.CFrame = spin * localPartCFrames[i]
        end
    end
    -- Pure body-centered framing, rather than using accessory-inflated bounds
    -- to move the camera sideways as the model rotates.
    local bodyHeight = math.clamp(dimensions.Y, 4.5, 8.5)
    local distance = math.max(5.2, bodyHeight * 1.75)
    avatarCamera.CameraType = Enum.CameraType.Scriptable
    avatarCamera.FieldOfView = 35
    local fixedCameraCFrame = CFrame.lookAt(
        Vector3.new(0, bodyHeight * 0.02, distance), Vector3.zero)
    avatarCamera.CFrame = fixedCameraCFrame
    avatar:SetAttribute("SpinMode", "fitted accessories / stationary body axis")
    avatar:SetAttribute("CameraIsStationary", true)
    avatar:SetAttribute("AccessoryCount", fittedAccessories)
    fallbackAvatar.Visible = false
    local angle = math.pi
    setAvatarAngle(angle)
    local connection
    connection = connect(RunService.RenderStepped, function(dt)
        if not avatar.Parent or not gui.Parent or not model.Parent then
            connection:Disconnect()
            return
        end
        if not window.Visible then return end
        angle = (angle + dt * 0.95) % (math.pi * 2)
        setAvatarAngle(angle)
    end)
end)

-- The original screenshot had a config dropdown and Quick Save in this area.
-- Both have been removed; the panels occupy the freed space.
-- Outer frame surrounding the three sections. Previously almost invisible
-- because both parent/child were almost identical charcoal and only 1px wide.
-- The 2px backing rim and the inset edge use separate shades without a heavy
-- all-black outline. Main's interior coordinates are UNCHANGED from V4.
local mainSurround = rect(window, 295, 77, 968, 766,
    Color3.fromRGB(45, 45, 45), 2)
directionalInset(mainSurround, 3, {
    top = Color3.fromRGB(16, 16, 16), left = Color3.fromRGB(16, 16, 16),
    bottom = Color3.fromRGB(77, 77, 77), right = Color3.fromRGB(66, 66, 66),
})
local main = rect(window, 297, 79, 964, 762, C.window, 3)
directionalInset(main, 4, {
    top = Color3.fromRGB(20, 20, 20), left = Color3.fromRGB(19, 19, 19),
    bottom = Color3.fromRGB(66, 66, 66), right = Color3.fromRGB(58, 58, 58),
    insideBottom = Color3.fromRGB(52, 52, 52),
})

local function makePane(x, y, w, h, heading)
    local pane = rect(main, x, y, w, h, C.pane, 3)
    -- Dark inset header sections, less contrast than the outer frame.
    gloss(pane, Color3.fromRGB(36, 36, 36), Color3.fromRGB(33, 33, 33))
    directionalInset(pane, 4, {
        top = Color3.fromRGB(21, 21, 21), left = Color3.fromRGB(21, 21, 21),
        bottom = Color3.fromRGB(63, 63, 63), right = Color3.fromRGB(53, 53, 53),
        insideTop = Color3.fromRGB(30, 30, 30),
        insideBottom = Color3.fromRGB(45, 45, 45),
    })
    local head = rect(pane, 2, 2, w - 4, 45, C.paneHeader, 5)
    gloss(head, Color3.fromRGB(27, 27, 27), Color3.fromRGB(21, 21, 21))
    rect(head, 0, 0, w - 4, 1, Color3.fromRGB(43, 43, 43), 6)
    rect(head, 0, 44, w - 4, 1, Color3.fromRGB(12, 12, 12), 6)
    -- Slightly smaller headings; the window title remains at its V6 size.
    setHeadingFont(label(pane, heading, 12, 3, w - 25, 41, 19, C.textBright, 7))
    local body = create("ScrollingFrame", {Parent = pane,
        Name = "SectionScroll", Position = UDim2.fromOffset(0, 49),
        Size = UDim2.fromOffset(w, h - 49),
        CanvasSize = UDim2.fromOffset(0, h - 49),
        BackgroundColor3 = C.pane, BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 5, ScrollBarImageColor3 = C.textDim,
        ScrollBarImageTransparency = 0.35, ZIndex = 4,
    })
    return body, pane:FindFirstChildOfClass("TextLabel")
end

-- Coordinates are relative to the main surface.
local leftBody, leftHeading = makePane(22, 18, 447, 724, "left")
local topBody, topHeading = makePane(493, 18, 448, 359, "top")
local bottomBody, bottomHeading = makePane(493, 398, 448, 344, "bottom")

-- Full-window overlay ensures popups aren't clipped behind panel borders.
local cover = create("TextButton", {Parent = window, 
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromOffset(W, H),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Visible = false,
    ZIndex = 50,
})
local activePopup
local nestedParentPopup
local activePopupArrow
local pickerMove
local function closePopup(immediate)
    pickerMove = nil
    if activePopupArrow and activePopupArrow.Parent then
        animate(activePopupArrow, {Rotation = 0, TextColor3 = C.textDim}, TWEEN_DURATION)
    end
    activePopupArrow = nil
    cover.Visible = false
    local panel = activePopup
    activePopup = nil
    if nestedParentPopup then
        local parent=nestedParentPopup
        nestedParentPopup=nil
        if immediate then parent:Destroy()
        elseif parent.Parent then activePopup=parent; cover.Visible=true end
    end
    if panel then
        if immediate then
            panel:Destroy()
        else
            animate(panel, {
                GroupTransparency = 1,
                Position = panel.Position + UDim2.fromOffset(0, -6),
            }, FADE_DURATION)
            task.delay(FADE_DURATION + 0.02, function()
                if panel.Parent then panel:Destroy() end
            end)
        end
    end
end
cover.MouseButton1Click:Connect(function() closePopup(false) end)
local function showPopup(anchor)
    if anchor and activePopup and anchor:IsDescendantOf(activePopup) then
        nestedParentPopup=activePopup
        activePopup=nil
        activePopupArrow=nil
        cover.Visible=true
        return
    end
    -- Only one popup at a time. Dismiss older popup immediately if another
    -- swatch/dropdown opens, but animate when dismissed normally.
    closePopup(true)
    cover.Visible = true
end
local function positionNear(control, popupWidth, popupHeight, preferLeft)
    local x = (control.AbsolutePosition.X - window.AbsolutePosition.X) / scaleNow
    local y = (control.AbsolutePosition.Y + control.AbsoluteSize.Y - window.AbsolutePosition.Y) / scaleNow + 5
    if preferLeft then x = x - popupWidth + control.AbsoluteSize.X / scaleNow end
    if x + popupWidth > W - 8 then x = W - popupWidth - 8 end
    if x < 8 then x = 8 end
    if y + popupHeight > H - 8 then
        y = (control.AbsolutePosition.Y - window.AbsolutePosition.Y) / scaleNow - popupHeight - 5
    end
    return x, math.max(8, y)
end
local function popupFrame(x, y, w, h, layer)
    layer=layer or 60
    -- CanvasGroup smoothly fades the complete popup, including option text,
    -- bevel details, and RGB/SV picker content, without washing out its colors.
    local panel = create("CanvasGroup", {Parent = window, 
        Position = UDim2.fromOffset(x, y + 6),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = layer,
    })
    gloss(panel, Color3.fromRGB(39, 39, 39), Color3.fromRGB(27, 27, 27))
    bevel(panel, true, layer+1)
    referenceSlice(panel, layer+2, 0.45)
    activePopup = panel
    animate(panel, {
        Position = UDim2.fromOffset(x, y), GroupTransparency = 0,
    }, FADE_DURATION)
    return panel
end

local function checkbox(parent, name, x, y, default, key, active)
    key = key or name
    local value = ensureSetting(key, default)
    local hit = create("TextButton", {Parent = parent, 
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(306, 34),
        Text = "", BackgroundTransparency = 1,
        AutoButtonColor = false, ZIndex = 6,
    })
    local square = rect(hit, 0, 3, 28, 28, Color3.fromRGB(29, 29, 29), 6)
    square.ClipsDescendants = true
    gloss(square, Color3.fromRGB(24, 24, 24), Color3.fromRGB(32, 32, 32))
    bevel(square, false, 7)
    referenceSlice(square, 8, 0.55)
    local check = create("ImageLabel", {Parent = square, 
        Name = "Checkmark",
        Position = UDim2.fromOffset(-2, -2),
        Size = UDim2.fromOffset(32, 32),
        BackgroundTransparency = 1,
        Image = "rbxassetid://18926561608",
        ImageColor3 = C.accent,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 10,
    })
    local nameLabel = label(hit, name, 42, 0, 259, 34, 21, C.text, 6)
    visibleCheckmarks[#visibleCheckmarks + 1] = check
    local firstRender = true
    local revision = 0
    local function render(on)
        revision += 1
        local thisRevision = revision
        local desiredColor = (on or active ~= false) and C.text or C.textDim
        if firstRender then
            firstRender = false
            check.Visible = on
            check.ImageTransparency = on and 0 or 1
            check.Size = on and UDim2.fromOffset(32, 32) or UDim2.fromOffset(24, 24)
            nameLabel.TextColor3 = desiredColor
        else
            check.Visible = true
            animate(check, {
                ImageTransparency = on and 0 or 1,
                Size = on and UDim2.fromOffset(32, 32) or UDim2.fromOffset(24, 24),
            }, TWEEN_DURATION)
            animate(nameLabel, {TextColor3 = desiredColor}, TWEEN_DURATION)
            if not on then
                task.delay(TWEEN_DURATION + 0.02, function()
                    if revision == thisRevision and check.Parent then
                        check.Visible = false
                    end
                end)
            end
        end
    end
    updaters[key] = render
    render(value)
    hit.MouseButton1Click:Connect(function()
        setSetting(key, not state[key])
    end)
    return hit
end

local sliderDrag
local function slider(parent, name, x, y, w, min, max, default, key, increment, suffix)
    key = key or name
    increment = increment or 1
    local current = ensureSetting(key, default)
    label(parent, name, x, y, w - 64, 28, 21, C.text, 6)
    local amount = label(parent, "", x + w - 61, y, 61, 28, 20, C.textDim, 6)
    amount.TextXAlignment = Enum.TextXAlignment.Right
    local rail = create("TextButton", {Parent = parent, 
        Position = UDim2.fromOffset(x, y + 30),
        Size = UDim2.fromOffset(w, 29),
        Text = "", BackgroundTransparency = 1,
        AutoButtonColor = false, ZIndex = 7,
    })
    -- Reference-style 8-10px slider rather than V8's nearly invisible 2px fill.
    local groove = rect(rail, 0, 10, w, 10, Color3.fromRGB(19, 19, 19), 7)
    bevel(groove, false, 8, true)
    local fill = rect(rail, 2, 12, 0, 6, C.accent, 9)
    local knob = rect(rail, 0, 2, 18, 25, Color3.fromRGB(48, 48, 48), 10)
    gloss(knob, Color3.fromRGB(67, 67, 67), Color3.fromRGB(35, 35, 35))
    bevel(knob, true, 11)
    referenceSlice(knob, 12, 0.25)
    local thumbAccent = rect(knob, 6, 5, 6, 15, C.accent, 13)
    visibleSliders[#visibleSliders + 1] = {fill = fill, thumbAccent = thumbAccent}
    local firstRender = true
    local function render(v)
        local range = max - min
        local fraction = range == 0 and 0 or math.clamp((v - min) / range, 0, 1)
        local dx = math.floor(fraction * (w - 18) + 0.5)
        local goalPos = UDim2.fromOffset(dx, 2)
        local goalFill = UDim2.fromOffset(math.max(0, dx + 9), 6)
        amount.Text = tostring(v) .. (suffix or "")
        if firstRender then
            firstRender = false
            knob.Position = goalPos
            fill.Size = goalFill
        else
            animate(knob, {Position = goalPos}, 0.11, Enum.EasingStyle.Quart)
            animate(fill, {Size = goalFill}, 0.11, Enum.EasingStyle.Quart)
        end
    end
    updaters[key] = render
    render(current)
    local function changeFromInput(input)
        local fractional = math.clamp((input.Position.X - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
        local raw = min + fractional * (max - min)
        local stepped = math.floor(raw / increment + 0.5) * increment
        local value = math.clamp(stepped, min, max)
        if state[key] ~= value then setSetting(key, value) end
    end
    rail.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            sliderDrag = changeFromInput
            changeFromInput(input)
        end
    end)
    return rail
end

connect(UserInputService.InputChanged, function(input)
    if sliderDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or
                       input.UserInputType == Enum.UserInputType.Touch) then
        sliderDrag(input)
    end
    if pickerMove and (input.UserInputType == Enum.UserInputType.MouseMovement or
                       input.UserInputType == Enum.UserInputType.Touch) then
        pickerMove(input)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        sliderDrag = nil
        pickerMove = nil
    end
end)

local function dropdown(parent, name, x, y, w, options, default, key, multi)
    key = key or name
    label(parent, name, x, y, w, 28, 21, C.text, 6)
    -- A single inset field: no separate framed arrow button on the right.
    local display = create("TextButton", {Parent = parent, 
        Position = UDim2.fromOffset(x, y + 32),
        Size = UDim2.fromOffset(w, 40),
        Text = "", BackgroundColor3 = C.input,
        BorderSizePixel = 0, AutoButtonColor = false,
        ZIndex = 6,
    })
    gloss(display, Color3.fromRGB(25, 25, 25), Color3.fromRGB(34, 34, 34))
    bevel(display, false, 7)
    referenceSlice(display, 8, 0.28)
    local current = ensureSetting(key, default)
    local selected = {}
    if multi then
        for item in string.gmatch(tostring(current), "[^,]+") do
            local trimmed = item:match("^%s*(.-)%s*$")
            selected[trimmed] = true
        end
    end
    local shown = label(display, "", 8, 0, w - 42, 40, 21, C.text, 9)
    local arrow = label(display, "▼", w - 35, 0, 27, 40, 17, C.textDim, 9)
    arrow.TextXAlignment = Enum.TextXAlignment.Center
    display.MouseEnter:Connect(function()
        animate(arrow, {TextColor3 = C.accent}, TWEEN_DURATION)
    end)
    display.MouseLeave:Connect(function()
        if activePopupArrow ~= arrow then
            animate(arrow, {TextColor3 = C.textDim}, TWEEN_DURATION)
        end
    end)
    local function render(value)
        shown.Text = tostring(value)
        if multi then
            -- Keep internal selections aligned after loading a saved profile.
            table.clear(selected)
            for item in string.gmatch(tostring(value), "[^,]+") do
                selected[item:match("^%s*(.-)%s*$")] = true
            end
        end
    end
    updaters[key] = render
    render(current)
    display.MouseButton1Click:Connect(function()
        if activePopup and activePopupArrow == arrow then
            closePopup(false)
            return
        end
        local h = math.min(#options * 35 + 8,window.Size.Y.Offset-24)
        local px, py = positionNear(display, w, h, false)
        showPopup(display)
        activePopupArrow = arrow
        animate(arrow, {Rotation = 180, TextColor3 = C.accent}, TWEEN_DURATION)
        local dropdownPanel = popupFrame(px, py, w, h,100)
        dropdownPanel.Name="DropdownPopup"
        local list=create("ScrollingFrame",{Parent=dropdownPanel,Name="Options",
            Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),
            BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
            ScrollBarImageColor3=C.accent,CanvasSize=UDim2.fromOffset(0,#options*35+8),ZIndex=102})
        for i = 1, #options do
            local item = options[i]
            local finalY=4+(i-1)*35
            local choice = create("TextButton", {Parent = list,
                Position = UDim2.fromOffset(10, finalY+5),
                Size = UDim2.fromOffset(w - 8, 33),
                BackgroundColor3 = Color3.fromRGB(36, 36, 36),
                BorderSizePixel = 0,
                Text = item,
                TextSize = 19,
                Font = FONT,
                TextColor3 = (multi and selected[item]) or (not multi and state[key] == item)
                    and C.textBright or C.text,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                ZIndex = 103,
            })
            choice.TextTransparency=1
            animate(choice,{Position=UDim2.fromOffset(4,finalY),TextTransparency=0},.16+math.min(i,6)*.018,Enum.EasingStyle.Quart)
            create("UIPadding", {Parent = choice, PaddingLeft = UDim.new(0, 9)})
            rect(choice, 0, 32, w - 8, 1, Color3.fromRGB(24, 24, 24), 104)
            choice.MouseEnter:Connect(function()
                animate(choice, {BackgroundColor3 = Color3.fromRGB(52, 52, 52)}, TWEEN_DURATION)
            end)
            choice.MouseLeave:Connect(function()
                animate(choice, {BackgroundColor3 = Color3.fromRGB(36, 36, 36)}, TWEEN_DURATION)
            end)
            choice.MouseButton1Click:Connect(function()
                if multi then
                    selected[item] = not selected[item]
                    local chosen = {}
                    for _index_13 = 1, #options do
                        local nameOption = options[_index_13]
                        if selected[nameOption] then table.insert(chosen, nameOption) end
                    end
                    setSetting(key, #chosen > 0 and table.concat(chosen, ", ") or "none")
                    choice.TextColor3 = selected[item] and C.textBright or C.text
                else
                    setSetting(key, item)
                    closePopup()
                end
            end)
        end
    end)
    return display
end

local function clampChannel(n)
    return math.clamp(math.floor(tonumber(n) or 0), 0, 255)
end
local function rgbHex(color)
    return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end
local function parseHex(s)
    s = tostring(s):gsub("#", ""):gsub("%s", "")
    if #s ~= 6 or not s:match("^%x+$") then return nil end
    return Color3.fromRGB(tonumber(s:sub(1, 2), 16),
        tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
end

local function picker(parent, name, x, y, w, default, key)
    key = key or name
    local value = ensureSetting(key, default)
    label(parent, name, x, y, w - 55, 40, 21, C.text, 6)
    -- Use the reference library's tintable color-wheel icon instead of a
    -- solid square swatch; clicking still opens our full HSV/HEX/RGB picker.
    local swatch = create("ImageButton", {Parent = parent, 
        Name = "ColorPickerIcon_" .. tostring(key),
        Position = UDim2.fromOffset(x + w - 41, y + 1),
        Size = UDim2.fromOffset(39, 39),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Image = COLOR_PICKER_ICON,
        ImageColor3 = value,
        ImageTransparency = 0,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 8,
    })
    -- Chain permanent updaters (the header gradient uses these) so changing
    -- either end of the gradient refreshes immediately as the user drags.
    local priorPermanentUpdater = permanentUpdaters[key]
    local function render(c)
        if swatch.Parent then swatch.ImageColor3 = c end
        if priorPermanentUpdater then priorPermanentUpdater(c) end
    end
    updaters[key] = render
    if parent == topBody then permanentUpdaters[key] = render end
    swatch.MouseEnter:Connect(function()
        animate(swatch, {ImageTransparency = 0.12}, 0.10)
    end)
    swatch.MouseLeave:Connect(function()
        animate(swatch, {ImageTransparency = 0}, 0.10)
    end)
    swatch.MouseButton1Click:Connect(function()
        showPopup()
        local popupW, popupH = 304, 283
        local px, py = positionNear(swatch, popupW, popupH, true)
        local panel = popupFrame(px, py, popupW, popupH)
        label(panel, name, 12, 4, 245, 27, 18, C.textBright, 64)
        rect(panel, 12, 33, popupW - 24, 1, C.separator, 62)

        local hsvH, hsvS, hsvV = state[key]:ToHSV()
        local sv = rect(panel, 12, 44, 225, 164, Color3.fromHSV(hsvH, 1, 1), 62)
        sv.Active = true
        local white = rect(sv, 0, 0, 225, 164, Color3.new(1, 1, 1), 63)
        white.Active = true
        create("UIGradient", {Parent = white, 
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)
            }), Rotation = 0,
        })
        local black = rect(sv, 0, 0, 225, 164, Color3.new(0, 0, 0), 64)
        black.Active = true
        create("UIGradient", {Parent = black, 
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)
            }), Rotation = 90,
        })
        local svMarker = rect(sv, 0, 0, 11, 11, Color3.new(1, 1, 1), 67)
        svMarker.AnchorPoint = Vector2.new(0.5, 0.5)
        create("UICorner", {Parent = svMarker, CornerRadius = UDim.new(1, 0)})
        edge(svMarker, Color3.new(0, 0, 0), 2)
        -- IMPORTANT: gradients MULTIPLY BackgroundColor3. The old red base
        -- blacked out greens/blues; pure white displays the full rainbow.
        local hueTrack = rect(panel, 247, 44, 23, 164, Color3.new(1, 1, 1), 62)
        hueTrack.Active = true
        create("UIGradient", {Parent = hueTrack, 
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
                ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
                ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
                ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
                ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
                ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
            }),
        })
        local hueMarker = rect(panel, 243, 44, 31, 4, C.textBright, 67)
        edge(hueMarker, C.border, 1)
        local hex = textBox(panel, "#RRGGBB", 12, 222, 103, 31, 66)
        hex.TextSize = math.floor(17 * TEXT_SCALE + 0.5)
        local channels = {}
        local rgbLetters = {"R", "G", "B"}
        for i = 1, #rgbLetters do
            local letter = rgbLetters[i]
            label(panel, letter, 120 + (i - 1) * 55, 223, 17, 30, 16, C.textDim, 65)
            local field = textBox(panel, "0", 137 + (i - 1) * 55, 222, 39, 31, 66)
            field.TextSize = math.floor(14 * TEXT_SCALE + 0.5)
            channels[i] = field
        end
        label(panel, "Drag to select · click outside to close", 12, 259, 280, 17, 13, C.textDim, 65)
        local updatingFields = false
        local function updateFields()
            updatingFields = true
            local c = Color3.fromHSV(hsvH, hsvS, hsvV)
            hex.Text = rgbHex(c)
            channels[1].Text = tostring(math.floor(c.R * 255 + 0.5))
            channels[2].Text = tostring(math.floor(c.G * 255 + 0.5))
            channels[3].Text = tostring(math.floor(c.B * 255 + 0.5))
            sv.BackgroundColor3 = Color3.fromHSV(hsvH, 1, 1)
            animate(svMarker, {
                Position = UDim2.fromOffset(hsvS * 225, (1 - hsvV) * 164),
            }, 0.12, Enum.EasingStyle.Quart)
            animate(hueMarker, {
                Position = UDim2.fromOffset(243, 44 + hsvH * 160),
            }, 0.12, Enum.EasingStyle.Quart)
            updatingFields = false
        end
        local function publish()
            setSetting(key, Color3.fromHSV(hsvH, hsvS, hsvV))
            updateFields()
        end
        local function colorFromSV(input)
            hsvS = math.clamp((input.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
            hsvV = 1 - math.clamp((input.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
            publish()
        end
        local function colorFromHue(input)
            hsvH = math.clamp((input.Position.Y - hueTrack.AbsolutePosition.Y) / hueTrack.AbsoluteSize.Y, 0, 1)
            publish()
        end
        local pickerLayers = {sv, white, black}
        for i = 1, #pickerLayers do
            local hit = pickerLayers[i]
            hit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or
                   input.UserInputType == Enum.UserInputType.Touch then
                    pickerMove = colorFromSV
                    colorFromSV(input)
                end
            end)
        end
        hueTrack.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                pickerMove = colorFromHue
                colorFromHue(input)
            end
        end)
        local function updateHSV(c)
            hsvH, hsvS, hsvV = c:ToHSV()
            publish()
        end
        hex.FocusLost:Connect(function()
            if updatingFields then return end
            local parsed = parseHex(hex.Text)
            if parsed then updateHSV(parsed) else updateFields() end
        end)
        for _index_16 = 1, #channels do
            local field = channels[_index_16]
            field.FocusLost:Connect(function()
                if updatingFields then return end
                updateHSV(Color3.fromRGB(
                    clampChannel(channels[1].Text),
                    clampChannel(channels[2].Text),
                    clampChannel(channels[3].Text)
                ))
            end)
        end
        updateFields()
    end)
    return swatch
end

-- The reference-style library owns the widget definitions and values.
-- Window and Section objects below decide which existing draw functions to call.

-- The existing tab-button appearance is reused for the seven categorized subtabs.
-- Only the ACTIVE icon is accent-colored; inactive icons are neutral gray.
-- Genuine declarative UI schema. Controls are defined once and created by
-- their owning Section when its Tab is shown (not loose direct constructor calls).
-- The existing primitives below retain the exact V20 pixel positions and styling.
local createKeybindControl
local WindowMethods = {}
local TabMethods = {}
local CategoryMethods = {}
local SectionMethods = {}
local ControlMethods = {}
WindowMethods.__index = WindowMethods
TabMethods.__index = TabMethods
CategoryMethods.__index = CategoryMethods
SectionMethods.__index = SectionMethods
ControlMethods.__index = ControlMethods

local windowApi = setmetatable({
    Gui = gui, Frame = window, MenuKey = options.MenuKey or Enum.KeyCode.RightShift,
    TitlePrefix = options.TitlePrefix or "violet", TitleSuffix = options.TitleSuffix or ".lol",
    Sections = {}, Categories = {},
}, WindowMethods)
self.window = windowApi

function WindowMethods:Tab(data)
    data = data or {}
    local tab = setmetatable({
        Name = data.Name, Icon = data.Icon, name = data.Name, icon = data.Icon,
        Category = data.Category, NavY = data.NavY,
        DefaultSubTabName = data.DefaultSubTabName,
        Window = self, Sections = {},
    }, TabMethods)
    library.tabs[tab.Name] = tab
    return tab
end
-- Categories own subtabs as in the supplied reference library; the sidebar
-- renders each category label with its children directly underneath.
function WindowMethods:Category(data)
    data = data or {}
    local cat = setmetatable({Name=data.Name, Window=self, Tabs={}}, CategoryMethods)
    self.Categories[#self.Categories + 1] = cat
    return cat
end
function CategoryMethods:SubTab(data)
    data = data or {}
    data.Category = self.Name
    local tab = self.Window:Tab(data)
    tab.ParentCategory = self
    self.Tabs[#self.Tabs + 1] = tab
    return tab
end
function WindowMethods:Section(data)
    data = data or {}
    local section = setmetatable({
        Name = data.Name, Side = data.Side, Body = data.Body or topBody,
        Window = self, Tab = nil, Controls = {}, YCursor = 14,
    }, SectionMethods)
    self.Sections[#self.Sections + 1] = section
    return section
end
function TabMethods:Section(data)
    data = data or {}
    local side = data.Side or "Left"
    local body = data.Body or ((side == "Top" or side == "Right") and topBody
        or (side == "Bottom" and bottomBody) or leftBody)
    local section = setmetatable({
        Name = data.Name, Side = side, Body = body,
        Window = self.Window, Tab = self, Controls = {}, YCursor = 14,
    }, SectionMethods)
    self.Sections[#self.Sections + 1] = section
    return section
end

function ControlMethods:Get()
    if self.Flag then return state[self.Flag] end
    return nil
end
function ControlMethods:Set(value)
    if not self.Flag then return end
    if self.Kind == "Toggle" then
        value = value == true
    elseif self.Kind == "Slider" then
        local lo, hi = self.Min or 0, self.Max or 100
        local step = self.Step or 1
        value = math.clamp(tonumber(value) or lo, lo, hi)
        if step > 0 then value = math.clamp(math.floor((value - lo) / step + 0.5) * step + lo, lo, hi) end
    elseif self.Kind == "Colorpicker" then
        if typeof(value) ~= "Color3" then return end
    elseif self.Kind == "Keybind" then
        if typeof(value) == "EnumItem" then value = value.Name end
        value = tostring(value)
    elseif self.Kind == "Textbox" then
        value = tostring(value or "")
    elseif self.Kind == "Dropdown" then
        if type(value) == "table" then value = table.concat(value, ", ") end
        value = tostring(value)
    end
    if state[self.Flag] ~= value then setSetting(self.Flag, value) end
end
function ControlMethods:SetVisibility(visible)
    self.Visible = visible == true
    if self.Elements then
        for i = 1, #self.Elements do
            local element = self.Elements[i]
            if element.Parent and element:IsA("GuiObject") then
                element.Visible = self.Visible
            end
        end
    end
end
function ControlMethods:Refresh(newOptions)
    if self.Kind ~= "Dropdown" or type(newOptions) ~= "table" then return end
    -- Mutate the options table captured by the original dropdown renderer.
    local list = self.Options
    table.clear(list)
    for i = 1, #newOptions do list[i] = newOptions[i] end
    if #list > 0 and not table.find(list, self:Get()) and not self.Multi then
        self:Set(list[1])
    end
end
function ControlMethods:Keybind(data)
    assert(self.Kind == "Toggle", "Only toggle controls may own a keybind")
    data = data or {}
    data.ParentToggle = self
    local nested = self.Section:_add("Keybind", data)
    self.BoundKey = nested
    if nested.Mode == "Always" and nested.ToggleTarget ~= false then self:Set(true) end
    return nested
end
function ControlMethods:Colorpicker(data)
    data = data or {}
    data.X = data.X or ((self.X or 20) + (self.Width or 405) - 66)
    data.Y = data.Y or self.Y
    data.Width = data.Width or 65
    data.Name = data.Name or ""
    return self.Section:_add("Colorpicker", data)
end

-- Toggle settings are real Section objects with their own flagged child
-- controls. The small gear opens the children without altering parent layout.
function ControlMethods:Settings()
    assert(self.Kind == "Toggle", "Only a toggle can own a settings group")
    if self.SettingsGroup then return self.SettingsGroup end
    local group = setmetatable({
        Name = self.Name .. " settings", ParentControl = self,
        Window = self.Window, Tab = self.Tab, Body = nil,
        Controls = {}, YCursor = 14,
    }, SectionMethods)
    self.SettingsGroup = group
    return group
end

function SectionMethods:_add(kind, data)
    data = data or {}
    if not data.Flag and kind ~= "Button" and kind ~= "Label" then data.Flag = "integrated."..tostring(#library.controls+1) end
    local name = data.Name or kind
    local default = data.Default
    if default == nil then
        if kind == "Toggle" then default = false
        elseif kind == "Slider" then default = data.Min or 0
        elseif kind == "Textbox" then default = ""
        elseif kind == "Keybind" then default = Enum.KeyCode.Insert end
    end
    local flag = data.Flag
    local autoHeight = ({Toggle = 36, Slider = 74, Dropdown = 78,
        Colorpicker = 44, Textbox = 54, Button = 48, Label = 30,
        Keybind = 0})[kind] or 44
    local autoY = data.Y
    if autoY == nil then
        autoY = self.YCursor or 14
        -- Attached keybinds share their toggle's line, not a separate row.
        if kind == "Keybind" and data.ParentToggle then
            autoY = data.ParentToggle.Y
            data.X = data.X or 332
        else
            self.YCursor = autoY + autoHeight
        end
    else
        if kind ~= "Keybind" then
            self.YCursor = math.max(self.YCursor or 14, autoY + autoHeight)
        end
    end
    local ctrl = setmetatable({
        Name = name, Kind = kind, Section = self, Window = self.Window,
        Tab = self.Tab, Flag = flag, Default = default,
        Callback = data.Callback, Changed = data.Changed,
        X = data.X or 20, Y = autoY,
        Width = data.Width or 405, Height = data.Height,
        TextSize = data.TextSize, Color = data.Color,
        Min = data.Min, Max = data.Max,
        Step = data.Step or (data.Decimals and 10 ^ (-data.Decimals)) or 1,
        Suffix = data.Suffix, Options = data.Options or data.Items or {},
        Multi = data.Multi, Active = data.Active,
        Mode = data.Mode or "Toggle", ParentToggle = data.ParentToggle,
        ToggleTarget = data.ToggleTarget,
        Placeholder = data.Placeholder, OnMount = data.OnMount,
        Visible = data.Visible ~= false,
    }, ControlMethods)
    self.Controls[#self.Controls + 1] = ctrl
    library.controls[#library.controls + 1] = ctrl
    if flag then
        library.options[flag] = ctrl
        local old = state[flag]
        if old == nil or options.Integration then
            if kind == "Keybind" and typeof(default) == "EnumItem" then default = default.Name end
            ctrl.Default = default
            ensureSetting(flag, default)
        end
        if kind == "Keybind" then
            library.keybinds[#library.keybinds + 1] = ctrl
        end
        if ctrl.Callback and kind ~= "Keybind" then
            local listeners = library.callbacks[flag]
            if not listeners then listeners = {}; library.callbacks[flag] = listeners end
            listeners[#listeners + 1] = ctrl
            local ok, err = pcall(ctrl.Callback, state[flag], ctrl)
            if not ok then warn("[violet.lol] Initial callback failed: " .. tostring(err)) end
        end
    end
    return ctrl
end
function SectionMethods:Toggle(data) return self:_add("Toggle", data) end
function SectionMethods:Slider(data) return self:_add("Slider", data) end
function SectionMethods:Dropdown(data) return self:_add("Dropdown", data) end
function SectionMethods:Colorpicker(data) return self:_add("Colorpicker", data) end
function SectionMethods:Keybind(data) return self:_add("Keybind", data) end
function SectionMethods:Textbox(data) return self:_add("Textbox", data) end
function SectionMethods:Button(data) return self:_add("Button", data) end
function SectionMethods:Label(data) return self:_add("Label", data) end

function ControlMethods:Mount()
    local spec = self
    local host = self.Section.Body
    local kind = self.Kind
    local instance
    local existing = {}
    local childrenBefore = host:GetChildren()
    for i = 1, #childrenBefore do existing[childrenBefore[i]] = true end
    if kind == "Toggle" then
        instance = checkbox(host, self.Name, self.X, self.Y, self.Default,
            self.Flag, self.Active)
        if self.SettingsGroup then
            local gear = create("ImageButton", {Parent = host,
                Name = "Settings_" .. (self.Flag or self.Name),
                Position = UDim2.fromOffset(self.X + (self.BoundKey and 282 or 358), self.Y + 2),
                Size = UDim2.fromOffset(29, 29),
                Image = "rbxassetid://80758916183665", ImageColor3 = C.textDim,
                BackgroundTransparency = 1, BorderSizePixel = 0,
                ScaleType = Enum.ScaleType.Fit, AutoButtonColor = false, ZIndex = 8,
            })
            self.SettingsGear = gear
            gear.MouseEnter:Connect(function() animate(gear, {ImageColor3=C.accent}, 0.12) end)
            gear.MouseLeave:Connect(function() animate(gear, {ImageColor3=C.textDim}, 0.12) end)
            gear.MouseButton1Click:Connect(function()
                if not self.Section.Body or not gui.Parent then return end
                showPopup()
                local group = self.SettingsGroup
                local height = math.min(480, math.max(155, (group.YCursor or 80) + 26))
                local pw = 435
                local px, py = positionNear(gear, pw, height, true)
                local panel = popupFrame(px, py, pw, height)
                panel.Name = "ToggleSettingsPopup"
                local caption = setHeadingFont(label(panel, group.Name,
                    14, 6, pw - 28, 27, 19, C.textBright, 68))
                local scroll = create("ScrollingFrame", {Parent=panel,
                    Position=UDim2.fromOffset(6, 39), Size=UDim2.fromOffset(pw-12, height-45),
                    CanvasSize=UDim2.fromOffset(0, math.max(height-45, group.YCursor+10)),
                    BackgroundTransparency=1, BorderSizePixel=0,
                    ScrollBarThickness=4, ScrollBarImageColor3=C.textDim,
                    ZIndex=65,
                })
                group.Body = scroll
                group:Mount()
                -- ScreenGui.Global ZIndex: raise each nested visual above the popup surface.
                local function raise(node)
                    if node:IsA("GuiObject") then node.ZIndex = node.ZIndex + 65 end
                    local children = node:GetChildren()
                    for j=1,#children do raise(children[j]) end
                end
                local children = scroll:GetChildren()
                for j=1,#children do raise(children[j]) end
            end)
        end
    elseif kind == "Slider" then
        instance = slider(host, self.Name, self.X, self.Y, self.Width,
            self.Min, self.Max, self.Default, self.Flag, self.Step, self.Suffix)
    elseif kind == "Dropdown" then
        instance = dropdown(host, self.Name, self.X, self.Y, self.Width,
            self.Options, self.Default, self.Flag, self.Multi)
    elseif kind == "Colorpicker" then
        instance = picker(host, self.Name, self.X, self.Y, self.Width,
            self.Default, self.Flag)
    elseif kind == "Keybind" then
        instance = createKeybindControl(host, self)
    elseif kind == "Button" then
        instance = button(host, self.Name, self.X, self.Y, self.Width,
            self.Height or 40, 6)
        instance.MouseButton1Click:Connect(function()
            if spec.Callback then
                local ok, err = pcall(spec.Callback, spec)
                if not ok then warn("[violet.lol] Button action failed: " .. tostring(err)) end
            end
        end)
    elseif kind == "Textbox" then
        instance = textBox(host, self.Placeholder or "", self.X, self.Y,
            self.Width, self.Height or 40, 6)
        instance.Text = tostring(self:Get() or "")
        updaters[self.Flag] = function(value)
            if instance.Parent and instance.Text ~= tostring(value) then
                instance.Text = tostring(value)
            end
        end
        if self.Tab == nil then permanentUpdaters[self.Flag] = updaters[self.Flag] end
        instance:GetPropertyChangedSignal("Text"):Connect(function()
            if self:Get() ~= instance.Text then self:Set(instance.Text) end
        end)
    elseif kind == "Label" then
        instance = label(host, self.Name, self.X, self.Y, self.Width,
            self.Height or 28, self.TextSize or 17, self.Color or C.text, 6)
    end
    self.Instance = instance
    local elements = {}
    local childrenAfter = host:GetChildren()
    for i = 1, #childrenAfter do
        local child = childrenAfter[i]
        if not existing[child] and child:IsA("GuiObject") then
            elements[#elements + 1] = child
        end
    end
    self.Elements = elements
    if not self.Visible then self:SetVisibility(false) end
    if self.OnMount then self.OnMount(instance, self) end
    return instance
end
function SectionMethods:Mount()
    for i = 1, #self.Controls do self.Controls[i]:Mount() end
end
function TabMethods:Mount()
    local offsets = {}
    for _, section in ipairs(self.Sections) do
        local offset = offsets[section.Body] or 0
        for _, c in ipairs(section.Controls) do c.Y = c.Y + offset end
        section:Mount()
        for _, c in ipairs(section.Controls) do c.Y = c.Y - offset end
        offsets[section.Body] = offset + (section.YCursor or 14) + 28
        section.Body.CanvasSize = UDim2.fromOffset(0, offsets[section.Body]+24)
    end
end

-- Four category labels and seven subtabs, using TahomaBold like the logo
-- and pane headings. The original sidebar dimensions and inset are retained.
local categoryData = {
    {Name="Combat", Tabs={{Name="Main", Icon="12716344256"}}},
    {Name="Visuals", Tabs={{Name="ESP", Icon="133911389227055"},
        {Name="Gadgets", Icon="105322023029633"},
        {Name="World", Icon="96232528933854"},
        {Name="Local Player", Icon="133911389227055"}}},
    {Name="Other", Tabs={{Name="Misc", Icon="17181101929"}}},
    {Name="Settings", Tabs={{Name="Config", Icon="9405931578"}}},
}
local tabs = {}
local tabButtons = {}
local currentTab = "Main"
local navY = 10
for categoryIndex=1,#categoryData do
    local cat = categoryData[categoryIndex]
    local category=windowApi:Category({Name=cat.Name})
    local heading = setHeadingFont(label(sidebar, cat.Name, 19, navY, 213, 33,
        22, C.textBright, 7))
    heading.Name = "Category_" .. cat.Name
    heading.TextXAlignment = Enum.TextXAlignment.Left
    navY = navY + 40
    for i=1,#cat.Tabs do
        local spec=cat.Tabs[i]
        local tab=category:SubTab({Name=spec.Name, Icon=spec.Icon, NavY=navY})
        tabs[#tabs+1]=tab
        navY=navY+60
    end
    navY=navY+14
end
local INACTIVE_ICON_COLOR = Color3.fromRGB(139, 139, 139)
-- Native UIShadow was released for GUI elements in 2026. In case this menu
-- is opened by an older Roblox client, the inset colored duplicate icon
-- below still supplies a soft, recognizable glow on its own.
local function nativeIconGlow(imageObject, active)
    local success, shadow = pcall(function()
        return Instance.new("UIShadow")
    end)
    if not success or not shadow then return nil end
    local configured = pcall(function()
        shadow.Name = "AccentIconGlow"
        shadow.Color = C.accent
        shadow.BlurRadius = UDim.new(0, 12)
        shadow.Offset = UDim2.fromOffset(0, 0)
        shadow.Spread = UDim2.fromOffset(2, 2)
        shadow.Transparency = active and 0.57 or 0.95
        shadow.Parent = imageObject
    end)
    if not configured then
        shadow:Destroy()
        return nil
    end
    return shadow
end
for index = 1, #tabs do
    local tab = tabs[index]
    local y = tab.NavY
    local tabHit = create("TextButton", {Parent = sidebar,
        Name = tab.name .. "Tab",
        Position = UDim2.fromOffset(9, y),
        Size = UDim2.fromOffset(237, 57),
        Text = "", BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 5,
    })
    -- Aim's uploaded art has considerably more transparent padding than
    -- the other images, so its image bounds are intentionally larger.
    local isAim = tab.name == "Aim"
    local iconPosition = isAim and UDim2.fromOffset(-1, 2) or UDim2.fromOffset(6, 9)
    local iconSize = isAim and UDim2.fromOffset(52, 52) or UDim2.fromOffset(39, 39)
    local selectedInitially = tab.name == currentTab
    -- Faint enlarged duplicate follows the IMAGE silhouette, not a rectangle.
    local iconHalo = create("ImageLabel", {Parent = tabHit, 
        Name = tab.name .. "Halo",
        Position = iconPosition + UDim2.fromOffset(-3, -3),
        Size = iconSize + UDim2.fromOffset(6, 6),
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tab.icon,
        ImageColor3 = selectedInitially and C.accent or INACTIVE_ICON_COLOR,
        ImageTransparency = selectedInitially and 0.79 or 0.96,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 6,
    })
    local symbol = create("ImageLabel", {Parent = tabHit, 
        Name = tab.name .. "Icon",
        Position = iconPosition,
        Size = iconSize,
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tab.icon,
        ImageColor3 = selectedInitially and C.accent or INACTIVE_ICON_COLOR,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 8,
    })
    local iconShadow = nativeIconGlow(symbol, selectedInitially)
    local wording = label(tabHit, tab.name, 57, 1, 169, 55, 24, C.text, 8)
    -- The active tab is inset INTO the sidebar: dark, thick top/left shadow,
    -- minimal lighter return at the bottom. Hide each stripe when not selected.
    local selectionEdges = directionalInset(tabHit, 7, {
        top = Color3.fromRGB(7, 7, 7), left = Color3.fromRGB(6, 6, 6),
        bottom = Color3.fromRGB(52, 52, 52), right = Color3.fromRGB(41, 41, 41),
        insideTop = Color3.fromRGB(16, 16, 16),
        insideLeft = Color3.fromRGB(14, 14, 14),
        insideBottom = Color3.fromRGB(37, 37, 37),
        insideRight = Color3.fromRGB(31, 31, 31),
    })
    for i = 1, #selectionEdges do
        selectionEdges[i].Visible = false
    end
    tabButtons[tab.name] = {
        button=tabHit, text=wording, icon=symbol, shadow=selectionEdges,
        halo=iconHalo, iconShadow=iconShadow,
    }
    tabHit.MouseEnter:Connect(function()
        if currentTab ~= tab.name then
            animate(wording, {TextColor3 = C.textBright}, TWEEN_DURATION)
        end
    end)
    tabHit.MouseLeave:Connect(function()
        if currentTab ~= tab.name then
            animate(wording, {TextColor3 = C.text}, TWEEN_DURATION)
        end
    end)
end

refreshAccent = function(keepTabTextTween)
    titleSuffix.TextColor3 = C.accent
    titleSuffix.TextStrokeColor3 = C.accent
    titleGlowOuter.Color = C.accent
    titleGlowInner.Color = C.accent
    -- User name keeps the current accent, but has no glow or glimmer.
    usernameText.TextColor3 = C.accent
    gameNameText.TextColor3 = C.accent
    -- Brackets and greeting deliberately remain pure white.
    for tabName, item in pairs(tabButtons) do
        local selected = tabName == currentTab
        local iconColor = selected and C.accent or INACTIVE_ICON_COLOR
        item.halo.ImageColor3 = iconColor
        if item.iconShadow then item.iconShadow.Color = iconColor end
        if not keepTabTextTween then
            item.text.TextColor3 = selected and C.accent or C.text
            item.icon.ImageColor3 = iconColor
        end
    end
    for _index_19 = 1, #visibleCheckmarks do
        local check = visibleCheckmarks[_index_19]
        if check.Parent then check.ImageColor3 = C.accent end
    end
    for _index_20 = 1, #visibleSliders do
        local item = visibleSliders[_index_20]
        if item.fill.Parent then item.fill.BackgroundColor3 = C.accent end
        if item.thumbAccent.Parent then item.thumbAccent.BackgroundColor3 = C.accent end
    end
end
-- Use one initial accent source across every themed element.
ensureSetting("theme.accent", C.accent)
refreshAccent()

-- A keybind is a component owned by a toggle, with independent Flag,
-- mode and Changed callback. The visual capture field stays precisely V20.
local capturingKeybind
local keybindAnimationSerial = 0
local keyNames = {
    LeftControl="L Ctrl", RightControl="R Ctrl", LeftShift="L Shift",
    RightShift="R Shift", MouseButton1="Mouse1", MouseButton2="Mouse2",
}
local function displayKey(value)
    return "[" .. (keyNames[tostring(value)] or tostring(value)) .. "]"
end
createKeybindControl = function(parent, spec)
    ensureSetting(spec.Flag.."_mode",spec.Mode)
    spec.Mode=state[spec.Flag.."_mode"]
    local hit = create("TextButton", {Parent = parent,
        Name="Keybind_"..spec.Flag,
        Position = UDim2.fromOffset(spec.X, spec.Y),
        Size = UDim2.fromOffset(103, 35),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = displayKey(spec:Get()), TextColor3 = C.text,
        TextSize = 21, Font = FONT, AutoButtonColor = false, ZIndex = 7,
    })
    local flag = spec.Flag
    updaters[flag] = function(value)
        if hit.Parent and capturingKeybind ~= spec then hit.Text = displayKey(value) end
    end
    hit.MouseButton1Click:Connect(function()
        capturingKeybind = spec
        keybindAnimationSerial = keybindAnimationSerial + 1
        local serial = keybindAnimationSerial
        hit.TextColor3 = C.accent
        task.spawn(function()
            local frame = 0
            while capturingKeybind == spec and keybindAnimationSerial == serial
                and hit.Parent and gui.Parent do
                frame = frame % 3 + 1
                hit.Text = "[" .. string.rep(".", frame) .. string.rep(" ", 3 - frame) .. "]"
                task.wait(0.28)
            end
        end)
    end)
    local function modeMenu()
        capturingKeybind=nil
        keybindAnimationSerial=keybindAnimationSerial+1
        hit.Text=displayKey(spec:Get())
        local x,y=positionNear(hit,180,113,true)
        showPopup(hit)
        local panel=popupFrame(x,y,180,113,100)
        panel.Name="KeybindModePopup"
        for index,mode in ipairs({"Toggle","Hold","Always"}) do
            local button=create("TextButton",{Parent=panel,Name=mode,
                Position=UDim2.fromOffset(4,4+(index-1)*35),Size=UDim2.fromOffset(172,33),
                BackgroundColor3=C.input,BorderSizePixel=0,Text=mode,TextSize=19,
                TextColor3=spec.Mode==mode and C.accent or C.text,AutoButtonColor=false,ZIndex=103})
            button.MouseButton1Click:Connect(function()
                setSetting(spec.Flag.."_mode",mode)
                closePopup(false)
            end)
        end
    end
    hit.MouseButton2Click:Connect(modeMenu)
    hit.TouchLongPress:Connect(function(_,phase) if phase==Enum.UserInputState.Begin then modeMenu() end end)
    return hit
end

local configTab = library.tabs.Config

-- Example-only controls from the supplied reference UI. These change UI flags
-- and display state, but deliberately do not hook any game services or weapons.
-- Controls are declared through Section methods, including nested Settings().
local function examples(tab, name, side, entries)
    if options.Integration then return end
    local section = tab:Section({Name=name, Side=side})
    for i=1,#entries do
        local item=entries[i]
        if item.Kind == "Heading" then
            section:Label({Name=item.Name, Height=28, TextSize=17,
                Color=C.textBright})
        else
            local data = {
                Name=item.Name, Flag=item.Flag, Default=item.Default,
                Min=item.Min, Max=item.Max, Step=item.Step,
                Suffix=item.Suffix, Options=item.Options,
                Placeholder=item.Placeholder, Multi=item.Multi,
                Active=true,
            }
            local ctrl = section[item.Kind](section, data)
            if item.Keybind and item.Kind == "Toggle" then
                ctrl:Keybind({Flag=item.Keybind, Default=item.KeyDefault or Enum.KeyCode.F9,
                    Mode="Toggle", ToggleTarget=true})
            end
            if item.Colors and item.Kind == "Toggle" then
                -- The reference associates palettes with their owning toggle.
                local group = ctrl:Settings()
                for colorIndex=1,#item.Colors do
                    local c=item.Colors[colorIndex]
                    group:Colorpicker({Name=c.Name, Default=c.Default, Flag=c.Flag})
                end
            end
            if item.Settings and item.Kind == "Toggle" then
                local group=ctrl:Settings()
                for childIndex=1,#item.Settings do
                    local child=item.Settings[childIndex]
                    local handler=group[child.Kind]
                    if handler then handler(group, child) end
                end
            end
            -- Reference gadget/grenade rows each have icon, name and distance
            -- palette settings. Make those editable examples too.
            if item.Kind == "Toggle" and type(item.Flag) == "string" and
                item.Flag:sub(-8) == "_enabled" and
                (item.Flag:sub(1,7) == "gadget_" or
                 item.Flag:sub(1,8) == "grenade_") and
                item.Flag ~= "gadget_esp_enabled" and
                item.Flag ~= "grenade_esp_enabled" then
                local prefix=item.Flag:sub(1,-9)
                local group=ctrl:Settings()
                group:Colorpicker({Name="Icon Color",Flag=prefix.."_icon_color",
                    Default=Color3.new(1,1,1)})
                group:Colorpicker({Name="Name Color",Flag=prefix.."_name_color",
                    Default=C.accent})
                group:Colorpicker({Name="Distance Color",Flag=prefix.."_distance_color",
                    Default=Color3.fromRGB(215,215,220)})
            end
        end
    end
    return section
end
local function T(name, flag, default, more)
    local obj={Kind="Toggle",Name=name,Flag=flag,Default=default==true}
    if more then for k,v in pairs(more) do obj[k]=v end end
    return obj
end
local function S(name, flag, min, max, default, suffix, step)
    return {Kind="Slider",Name=name,Flag=flag,Min=min,Max=max,
        Default=default,Suffix=suffix,Step=step}
end
local function D(name, flag, optionsList, default)
    return {Kind="Dropdown",Name=name,Flag=flag,Options=optionsList,Default=default}
end
local function H(name)
    return {Kind="Heading",Name=name}
end
local BLUE = Color3.fromRGB(77, 154, 255)
local PINK = Color3.fromRGB(226, 94, 202)
local GREEN = Color3.fromRGB(72, 225, 134)
local YELLOW = Color3.fromRGB(244, 207, 81)
local RED = Color3.fromRGB(248, 81, 91)
local function colorEntry(name,flag,default)
    return {Name=name,Flag=flag,Default=default}
end

-- COMBAT / AIM: targeting controls from the reference's Aim Options.
local aimMain = examples(library.tabs.Aim,"Aim Options","Left",{
    T("Aimbot","aim_active",false,{Keybind="aim_active_key",KeyDefault=Enum.KeyCode.F9,
        Settings={T("Team Check","team_check"), T("Visible Check","visible_check")}}),
    D("Aim Method","aim_method",{"Silent","Camera"},"Silent"),
    D("Target Part","target_part",{"Head","Torso"},"Head"),
    S("Aim Smoothing","aim_smoothing",0,100,20,"%"),
    S("Hit Chance","hit_chance",0,100,100,"%"),
    T("Visible Check","visible_check_quick"),
    T("Team Check","team_check_quick"),
})
examples(library.tabs.Aim,"FOV Circle","Top",{
    T("FOV Circle","use_fov",false,{Keybind="fov_key",KeyDefault=Enum.KeyCode.F10,
        Colors={colorEntry("Gradient Left","fov_gradient_left",Color3.fromRGB(0,0,0)),
            colorEntry("Gradient Right","fov_gradient_right",PINK)},
        Settings={S("FOV Radius","fov_radius",50,500,200," px"),
            T("Fill FOV","fov_fill",true),S("FOV Transparency","fov_transparency",0,1,0.5,"",0.01),
            T("FOV Glow","fov_glow",true), S("Gradient Speed","grad_speed",0.1,5,1.5,"",0.1),
            T("Rotate FOV","fov_rotate",true)}}),
    S("FOV Radius","fov_radius_quick",50,500,200," px"),
    T("Fill FOV","fov_fill_quick",true),
})
examples(library.tabs.Aim,"Target Options","Bottom",{
    T("Multipoints","aim_multipoints"),
    S("Point Scale","aim_point_scale",0.1,1.5,0.85,"",0.05),
    D("Target Priority","aim_priority",{"Closest","Lowest Health","Nearest Crosshair"},"Closest"),
})

-- COMBAT / RAGEBOT: manipulate/FOV and other advanced example flags.
examples(library.tabs.Ragebot,"Manipulation","Left",{
    T("Manipulation","manipulate",false,{Settings={
        S("Max Manipulate Shift","max_shift",1,15,11," studs"),
        T("Multipoints","multipoints"),
        S("Point Scale","point_scale",0.1,1.5,0.85,"",0.05),
    }}),
    S("Max Manipulate Shift","max_shift_quick",1,15,11," studs"),
    T("Multipoints","multipoints_quick"),
    S("Point Scale","point_scale_quick",0.1,1.5,0.85,"",0.05),
    T("Silent Aim","rage_silent_aim"),
    T("Auto Fire","rage_auto_fire"),
    S("Hit Chance","rage_hit_chance",0,100,100,"%"),
    D("Target Part","rage_target_part",{"Head","Torso"},"Head"),
})
examples(library.tabs.Ragebot,"Rage FOV","Top",{
    T("Use FOV","rage_use_fov"),
    T("Fill FOV","rage_fov_fill",true),
    T("FOV Glow","rage_fov_glow",true),
    S("FOV Radius","rage_fov_radius",50,500,200," px"),
})
examples(library.tabs.Ragebot,"Advanced","Bottom",{
    S("FOV Transparency","rage_fov_alpha",0,1,0.5,"",0.01),
    S("Gradient Speed","rage_grad_speed",0.1,5,1.5,"",0.1),
    T("Rotate FOV","rage_fov_rotate",true),
})

-- COMBAT / WEAPON: names, limits, defaults from Weapon Mods reference.
examples(library.tabs.Weapon,"Weapon Mods","Left",{
    T("No Recoil","no_recoil",false,{Settings={S("Recoil Percent","recoil_percent",0,100,0,"%")}}),
    T("No Spread","no_spread",false,{Settings={S("Spread Percent","spread_percent",0,100,0,"%")}}),
    T("Rapid Fire","rapid_fire",false,{Settings={S("Fire Rate (ms)","fire_rate",100,2000,1000," ms")}}),
    T("Instant ADS","instant_ads",false,{Settings={S("ADS Speed","ads_speed",0.001,0.5,0.001,"",0.001)}}),
    T("Force Auto","force_auto"),
})
examples(library.tabs.Weapon,"Weapon Tuning","Top",{
    S("Recoil Percent","recoil_percent_quick",0,100,0,"%"),
    S("Spread Percent","spread_percent_quick",0,100,0,"%"),
    S("Fire Rate (ms)","fire_rate_quick",100,2000,1000," ms"),
})
examples(library.tabs.Weapon,"Handling","Bottom",{
    S("ADS Speed","ads_speed_quick",0.001,0.5,0.001,"",0.001),
})

-- VISUALS / ESP: player rendering, box/health/text settings from reference.
examples(library.tabs.ESP,"Player ESP","Left",{
    T("ESP Enabled","esp_enabled",true,{Keybind="esp_enabled_key",KeyDefault=Enum.KeyCode.V,
        Settings={T("Team Check","esp_team_check"),
            S("Distance Limit","esp_distance_limit",50,3000,500," st"),
            T("Gradient","esp_gradient",true)}}),
    T("Boxes","esp_boxes",true,{Colors={colorEntry("Box Top","esp_box_gradient_top",BLUE),
        colorEntry("Box Bottom","esp_box_gradient_bottom",PINK)},Settings={
        T("Bounding Box","esp_bounding_box",true),
        T("Include Accessories","esp_include_accessories"),
        S("Padding X","esp_box_padding_x",0,30,0),S("Padding Y","esp_box_padding_y",0,30,2),
        T("Box Glow","esp_box_glow",true),T("Box Fill","esp_box_fill",true),
        S("Left Transparency","esp_box_glow_top_alpha",0,100,85,"%"),
        S("Right Transparency","esp_box_glow_bottom_alpha",0,100,85,"%"),
        S("Left Transparency","esp_box_fill_top_alpha",0,100,85,"%"),
        S("Right Transparency","esp_box_fill_bottom_alpha",0,100,85,"%"),
    }}),
    T("Health Bar","esp_health_bar",true,{Colors={
        colorEntry("Top","esp_health_top",GREEN),
        colorEntry("Middle","esp_health_middle",YELLOW),
        colorEntry("Bottom","esp_health_bottom",RED)},
        Settings={T("Health Text","esp_health_text",true)}}),
    T("Skeleton","esp_skeleton",false,{Colors={colorEntry("Skeleton","esp_skeleton_left",BLUE)},
        Settings={S("Thickness","esp_skeleton_thickness",1,2,1,"",0.1)}}),
    S("Distance Limit","esp_distance_limit_quick",50,3000,500," st"),
    T("Team Check","esp_team_check_quick"),
    T("Gradient","esp_gradient_quick",true),
})
examples(library.tabs.ESP,"Text ESP","Top",{
    T("Name","esp_name",true,{Colors={colorEntry("Name Top","esp_name_top",BLUE),
        colorEntry("Name Bottom","esp_name_bottom",PINK)},
        Settings={T("Display Name","esp_name_display_name",true)}}),
    T("Distance","esp_distance",true,{Colors={colorEntry("Distance Top","esp_distance_top",BLUE),
        colorEntry("Distance Bottom","esp_distance_bottom",PINK)}}),
    T("Weapon","esp_weapon",true,{Settings={
        T("Weapon Icon","esp_weapon_icon",true),
        S("Weapon Icon Size","esp_weapon_icon_size",24,100,56," px"),
        {Kind="Textbox",Name="Preview Weapon Icon ID",Flag="esp_preview_weapon_icon_id",
            Default="87030448114840",Placeholder="asset id"},
    }}),
    T("Flags","esp_flags",true),
    T("Icon","esp_name_icon",false,{Settings={
        {Kind="Textbox",Name="Icon Asset ID",Flag="esp_name_icon_id",
            Default="117005477469687",Placeholder="asset id"},
    }}),
})
examples(library.tabs.ESP,"Preview & Colors","Bottom",{
    T("Box Glow","esp_box_glow_quick",true),
    T("Box Fill","esp_box_fill_quick",true),
    S("Box Padding X","esp_padding_x_quick",0,30,0),
    S("Skeleton Thickness","esp_thickness_quick",1,2,1,"",0.1),
})

-- Lucide assets: Footagesus/Icons lucide/dist/Icons.lua (Lucide ISC license).
-- All overlay state uses the existing profile store and SettingChanged event.
local overlayUI = (function()
    local icons = {
        eye="100033680381365", settings="80758916183665", keyboard="121474456068237",
        location="84279202219901", clock="121808839832144", game="92483947987410",
        user="81589895647169", code="107380207681249", activity="94212016861936",
        wifi="104669375183960", timer="85473888890506", down="134243273101015",
        close="110786993356448", profile="116544501716299",
        check="93898873302694",loader="116535712789945",lock="78672912777756",
    }
    local IMAGE_URL = "https://files.catbox.moe/25ygks.png"
    local api, cachedImages = {}, {}
    local shimmerEffects={}
    local function shimmerText(target,period)
        if target.TextColor3==Color3.new(1,1,1) then
            target.TextColor3=Color3.fromRGB(210,218,241)
        end
        local shine=target:Clone()
        for _,child in ipairs(shine:GetChildren()) do child:Destroy() end
        shine.Name="NameShimmer"
        shine.Parent=target
        shine.Position=UDim2.fromOffset(0,0)
        shine.AnchorPoint=Vector2.zero
        shine.Size=UDim2.new(0,0,1,0)
        shine.AutomaticSize=Enum.AutomaticSize.X
        shine.BackgroundTransparency=1
        shine.TextColor3=Color3.new(1,1,1)
        shine.TextTransparency=.06
        shine.TextStrokeTransparency=1
        shine.ZIndex=target.ZIndex+1
        local gradient=create("UIGradient",{Parent=shine,Rotation=15,Offset=Vector2.new(-1.4,0),
            Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),
                NumberSequenceKeypoint.new(.34,1),NumberSequenceKeypoint.new(.5,.12),
                NumberSequenceKeypoint.new(.66,1),NumberSequenceKeypoint.new(1,1)})})
        for _,property in ipairs({"Text","TextSize","FontFace"}) do
            target:GetPropertyChangedSignal(property):Connect(function() shine[property]=target[property] end)
        end
        shimmerEffects[#shimmerEffects+1]={gradient=gradient,time=0,period=period or 5}
    end
    local popup, refreshPreview, previewPosition
    local watermark, bindsPanel, previewSettings, previewHeaderGradient,mobileToggle
    local region = game:GetService("LocalizationService").RobloxLocaleId
    local started = os.clock()
    local executorName="Unknown"
    for _,identify in ipairs({identifyexecutor or false,getexecutorname or false}) do
        if type(identify)=="function" then
            local ok,name=pcall(identify)
            if ok and type(name)=="string" and name~="" then
                executorName=name:gsub("[\r\n]"," "):sub(1,24)
                break
            end
        end
    end
    local frames, elapsed, fps = 0, 0, 60
    local backdrop=rect(gui,0,0,0,0,Color3.new(1,1,1),0)
    backdrop.Name="MenuBackdrop"
    backdrop.Size=UDim2.fromScale(1,1)
    backdrop.BackgroundTransparency=1
    backdrop.Visible=false
    create("UIGradient",{Parent=backdrop,Rotation=35,Color=ColorSequence.new(
        Color3.fromRGB(12,14,23),Color3.fromRGB(26,18,34))})
    local menuBlur=create("BlurEffect",{Parent=game:GetService("Lighting"),
        Name="VioletMenuBlur",Size=0,Enabled=true})
    gui.Destroying:Connect(function() if menuBlur.Parent then menuBlur:Destroy() end end)
    local backdropRevision=0
    local function syncBackdrop()
        backdropRevision=backdropRevision+1
        local revision=backdropRevision
        local showing=unlocked and window.Visible and state["hud.backdrop"]~=false
        if showing then backdrop.Visible=true end
        animate(backdrop,{BackgroundTransparency=showing
            and (1-(state["hud.backdrop_dim"] or 40)/100) or 1},.25)
        animate(menuBlur,{Size=not unlocked and 12
            or (showing and (state["hud.backdrop_blur"] or 14) or 0)},.3)
        if not showing then task.delay(.27,function()
            if revision==backdropRevision and backdrop.Parent then backdrop.Visible=false end
        end) end
    end
    connect(window:GetPropertyChangedSignal("Visible"),syncBackdrop)
    shimmerText(mainTitle,5)
    shimmerText(titleSuffix,5)
    local function round(object, radius)
        if object:IsA("ImageLabel") and not object:FindFirstChildOfClass("UICorner") then
            create("UICorner", {Parent=object,CornerRadius=UDim.new(0,radius or 6)})
        end
    end
    local function text(parent,value,x,y,w,h,color,size,z)
        local t=label(parent,value,x,y,w,h,size or 11,color or C.textBright,z or 42)
        t.FontFace=fontFace
        t.TextSize=size or 11
        return t
    end
    local function icon(parent,name,x,y,size,z,buttonIcon)
        local im=create(buttonIcon and "ImageButton" or "ImageLabel",{
            Parent=parent,Name=buttonIcon and "Settings" or ("Lucide_"..name),
            Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),
            Image="rbxassetid://"..(icons[name] or icons.settings),
            ImageColor3=C.textBright,ImageTransparency=0,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z or 43})
        if buttonIcon then
            im.AutoButtonColor=false
            im.MouseEnter:Connect(function() im.ImageColor3=C.accent end)
            im.MouseLeave:Connect(function() im.ImageColor3=C.textBright end)
        end
        return im
    end
    local glowEntries={}
    local function refreshGlow()
        for _,entry in ipairs(glowEntries) do
            if entry.shadow.Parent then
                entry.shadow.Color=state["theme.glow_color"] or C.accent
                entry.shadow.BlurRadius=UDim.new(0,state["theme.header_glow_blur"] or 12)
                entry.shadow.Offset=UDim2.fromOffset(0,0)
                entry.shadow.Spread=UDim2.fromOffset(2,2)
                entry.shadow.Transparency=state["theme.outline_glow"] and
                    1-math.clamp(state["theme.glow_strength"] or 60,0,100)/100*.72 or 1
            end
        end
    end
    local function attachGlow(target)
        -- The same native shadow used by the active sidebar icons.
        local shadow=nativeIconGlow(target,true)
        if not shadow then return end
        shadow.Name="OuterBorderGlow"
        glowEntries[#glowEntries+1]={shadow=shadow}
        refreshGlow()
    end
    local function surface(parent,name,x,y,w,h,z)
        local f=rect(parent,x,y,w,h,C.window,z or 40)
        f.Name=name
        gloss(f,Color3.fromRGB(38,38,38),Color3.fromRGB(33,33,33))
        directionalInset(f,(z or 40)+1)
        if name=="Watermark" or name=="KeybindList" or name=="ESPPreviewPanel" then attachGlow(f) end
        return f
    end
    local function themeHeader(header)
        gloss(header,Color3.fromRGB(27,27,27),Color3.fromRGB(21,21,21))
        rect(header,0,0,header.Size.X.Offset,1,Color3.fromRGB(43,43,43),42)
        rect(header,0,header.Size.Y.Offset-1,header.Size.X.Offset,1,C.border,42)
    end
    local function drag(frame,handle,onMoved)
        handle.Active=true
        local origin, position, pointer
        handle.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1
                or input.UserInputType==Enum.UserInputType.Touch then
                origin=input.Position
                position=frame.Position
                pointer=input
            end
        end)
        local move=UserInputService.InputChanged:Connect(function(input)
            if not pointer or not frame.Parent then return end
            if input.UserInputType~=Enum.UserInputType.MouseMovement and input~=pointer then return end
            local delta=input.Position-origin
            local view=workspace.CurrentCamera.ViewportSize
            local x=math.clamp(position.X.Offset+delta.X,8,math.max(8,view.X-frame.AbsoluteSize.X-8))
            local y=math.clamp(position.Y.Offset+delta.Y,8,math.max(8,view.Y-frame.AbsoluteSize.Y-8))
            frame.Position=UDim2.fromOffset(x,y)
            if onMoved then onMoved(Vector2.new(x,y)) end
        end)
        local stop=UserInputService.InputEnded:Connect(function(input)
            if input==pointer or input.UserInputType==Enum.UserInputType.MouseButton1 then pointer=nil end
        end)
        frame.Destroying:Connect(function() move:Disconnect(); stop:Disconnect() end)
    end
    local function closeSettings()
        if popup then popup:Destroy(); popup=nil end
    end
    local function settings(anchor,title,height,build)
        if popup and popup:GetAttribute("Owner")==title then closeSettings(); return end
        closeSettings()
        local cover=create("TextButton",{Parent=gui,Name="OverlaySettings",
            Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,
            BorderSizePixel=0,ZIndex=90})
        cover:SetAttribute("Owner",title)
        popup=cover
        local view=workspace.CurrentCamera.ViewportSize
        local x=math.clamp(anchor.AbsolutePosition.X-258,8,math.max(8,view.X-290))
        local y=anchor.AbsolutePosition.Y+anchor.AbsoluteSize.Y+10
        if y+height>view.Y-8 then y=math.max(8,anchor.AbsolutePosition.Y-height-10) end
        local panel=surface(cover,"SettingsPopover",x,y,282,height,91)
        local header=text(panel,title,14,6,244,30,C.textBright,12,94)
        setHeadingFont(header)
        icon(panel,"settings",248,13,15,94)
        rect(panel,12,41,258,1,C.separator,93)
        cover.MouseButton1Click:Connect(closeSettings)
        -- Consume empty-space clicks so only the outside backdrop dismisses.
        local block=create("TextButton",{Parent=panel,Size=UDim2.fromScale(1,1),
            BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=92})
        block.Name="SettingsBackground"
        build(panel)
    end
    local function check(parent,name,key,y)
        local hit=create("TextButton",{Parent=parent,Name=key,Position=UDim2.fromOffset(12,y),
            Size=UDim2.fromOffset(258,27),BackgroundTransparency=1,Text="",ZIndex=94})
        local box=surface(hit,"Check",0,6,14,14,95)
        local mark=text(box,"",0,-1,14,15,C.accent,12,97)
        mark.TextXAlignment=Enum.TextXAlignment.Center
        local caption=text(hit,name,24,0,230,27,C.text,11,96)
        local function update() mark.Text=state[key] and "✓" or "" end
        update()
        hit.MouseButton1Click:Connect(function() setSetting(key,not state[key]); update() end)
        return caption
    end
    local function field(parent,name,key,y,onCommit)
        text(parent,name,14,y,250,22,C.textDim,10,94)
        local bg=surface(parent,"Input",12,y+24,258,31,94)
        local input=create("TextBox",{Parent=bg,Position=UDim2.fromOffset(8,0),
            Name=key,
            Size=UDim2.new(1,-16,1,0),BackgroundTransparency=1,BorderSizePixel=0,
            Text=tostring(state[key] or ""),TextColor3=C.textBright,
            PlaceholderText="Enter value",ClearTextOnFocus=false,TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left,ZIndex=96})
        input.FontFace=fontFace
        bevel(bg,false,95)
        input.FocusLost:Connect(function()
            setSetting(key,input.Text)
            if onCommit then onCommit(input.Text) end
        end)
        return input
    end
    local function select(parent,name,key,options,y,onSelect)
        text(parent,name,14,y,250,22,C.textDim,10,94)
        local hit=create("TextButton",{Parent=parent,Name="SourceDropdown",
            Position=UDim2.fromOffset(12,y+24),Size=UDim2.fromOffset(258,31),
            BackgroundColor3=C.input,BorderSizePixel=0,Text="",AutoButtonColor=false,ZIndex=96})
        gloss(hit,Color3.fromRGB(25,25,25),Color3.fromRGB(34,34,34))
        bevel(hit,false,97)
        local caption=text(hit,tostring(state[key]),10,0,222,31,C.textBright,11,97)
        icon(hit,"down",234,9,13,98)
        local list
        hit.MouseButton1Click:Connect(function()
            if list then list:Destroy(); list=nil; return end
            list=surface(parent,"DropdownOptions",12,y+58,258,#options*30+6,110)
            for i,value in ipairs(options) do
                local option=create("TextButton",{Parent=list,Name="Option_"..value,
                    Position=UDim2.fromOffset(3,3+(i-1)*30),Size=UDim2.fromOffset(252,29),
                    BackgroundColor3=C.inputLight,BackgroundTransparency=value==state[key] and 0 or 1,
                    BorderSizePixel=0,Text="",AutoButtonColor=false,ZIndex=111})
                text(option,value,9,0,232,29,value==state[key] and C.accent or C.text,11,112)
                option.MouseButton1Click:Connect(function()
                    setSetting(key,value); caption.Text=value
                    list:Destroy(); list=nil
                    if onSelect then onSelect(value) end
                end)
            end
        end)
    end
    local defaults={
        ["theme.outline_glow"]=true,["theme.glow_panels"]=true,
        ["theme.glow_color"]=C.accent,["theme.header_glow_blur"]=12,["theme.glow_strength"]=60,
        esp_preview_source="Player Model",esp_preview_image_url=IMAGE_URL,esp_preview_asset_id="",
        ["hud.preview"]=true,["hud.watermark"]=true,["hud.keybinds"]=true,
        ["hud.backdrop"]=true,["hud.backdrop_dim"]=40,["hud.backdrop_blur"]=14,
        ["watermark.script"]=true,["watermark.fps"]=true,["watermark.ping"]=true,
        ["watermark.session"]=true,["watermark.clock"]=false,["watermark.location"]=false,
        ["watermark.game"]=false,["watermark.profile"]=false,["watermark.player"]=true,
        ["watermark.executor"]=true,
        ["watermark.avatar"]=true,
        ["keybinds.active_only"]=false,["keybinds.show_mode"]=true,["keybinds.show_menu"]=true,
    }
    for key,value in pairs(defaults) do ensureSetting(key,value) end
    attachGlow(window)
    connect(scaler:GetPropertyChangedSignal("Scale"),refreshGlow)
    task.defer(refreshGlow)
    function api.CloseSettings() closeSettings() end

    function api.MountPreview()
        if previewPanel then return end
        previewPanel=surface(gui,"ESPPreviewPanel",0,0,PREVIEW_PANEL_W,PREVIEW_PANEL_H,40)
        previewPanel.Visible=window.Visible and state["hud.preview"]
        previewScaler=create("UIScale",{Parent=previewPanel,Scale=1})
        local header=rect(previewPanel,2,2,336,26,Color3.fromRGB(30,30,30),41)
        header.Name="PreviewHeader"
        header.BackgroundColor3=Color3.new(1,1,1)
        previewHeaderGradient=create("UIGradient",{Parent=header,Color=ColorSequence.new(
            state["theme.header_left"] or HEADER_GRADIENT_LEFT_DEFAULT,
            state["theme.header_right"] or HEADER_GRADIENT_RIGHT_DEFAULT)})
        local topEdge=rect(header,0,0,336,1,Color3.new(1,1,1),42)
        topEdge.BackgroundTransparency=.64
        rect(header,0,25,336,1,Color3.fromRGB(30,26,68),42)
        for i,x in ipairs({138,162,186,210,234,258,278}) do
            create("ImageLabel",{Parent=header,Name="HeaderStar"..i,
                AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(x,i%2==0 and 18 or 7),
                Size=UDim2.fromOffset(i%2==0 and 13 or 11,i%2==0 and 13 or 11),Rotation=i%2==0 and 94 or -12,
                Image=HEADER_STAR_IMAGE,ImageTransparency=i%2==0 and .29 or .17,BackgroundTransparency=1,ZIndex=42})
        end
        icon(header,"eye",11,6,14,43)
        local previewTitle=setHeadingFont(text(header,"ESP Preview",32,0,190,26,Color3.new(1,1,1),11,43))
        shimmerText(previewTitle,5)
        local modeLabel=text(header,"IMAGE",230,0,47,26,C.textDim,9,43)
        modeLabel.Visible=false
        modeLabel.TextXAlignment=Enum.TextXAlignment.Right
        local gear=icon(header,"settings",289,6,14,44,true)
        gear.Name="PreviewSettings"
        local close=icon(header,"close",313,6,14,44,true)
        close.Name="ClosePreview"
        close.MouseButton1Click:Connect(function() setSetting("hud.preview",false) end)
        drag(previewPanel,header,function(pos)
            previewPosition=pos
            previewPanel:SetAttribute("Detached",true)
            previewPanel:SetAttribute("DragX",pos.X)
            previewPanel:SetAttribute("DragY",pos.Y)
        end)
        rect(previewPanel,12,29,316,1,C.separator,42)
        local stage=rect(previewPanel,10,38,320,368,Color3.new(1,1,1),41)
        stage.Name="ESPPreviewStage"
        create("UIGradient",{Parent=stage,Rotation=90,Color=ColorSequence.new(
            Color3.fromRGB(36,36,36),Color3.fromRGB(33,33,33))})
        bevel(stage,false,42,true)
        local img=create("ImageLabel",{Parent=stage,Name="PreviewImage",
            Position=UDim2.fromOffset(10,28),Size=UDim2.fromOffset(300,300),
            BackgroundTransparency=1,Image="",ScaleType=Enum.ScaleType.Fit,ZIndex=42})
        local viewport=create("ViewportFrame",{Parent=stage,Name="PreviewPlayerModel",
            Position=UDim2.fromOffset(24,24),Size=UDim2.fromOffset(272,300),
            BackgroundTransparency=1,Ambient=Color3.fromRGB(200,200,200),
            LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-0.5,-1,-1),
            BorderSizePixel=0,ZIndex=42})
        local worldModel=create("WorldModel",{Parent=viewport})
        local camera=create("Camera",{Parent=viewport,FieldOfView=32})
        viewport.CurrentCamera=camera
        local status=text(stage,"Loading preview...",25,150,270,48,C.textDim,11,48)
        status.Name="PreviewStatus"
        status.TextWrapped=true; status.TextXAlignment=Enum.TextXAlignment.Center
        local fill=rect(stage,48,35,224,286,Color3.new(1,1,1),43)
        local fillGradient=create("UIGradient",{Parent=fill,Rotation=90})
        local glow=rect(stage,48,35,224,286,C.accent,44); glow.BackgroundTransparency=1
        local glowStroke=edge(glow,C.accent,4); glowStroke.Transparency=0.85
        local box=rect(stage,48,35,224,286,Color3.new(1,1,1),45); box.BackgroundTransparency=1
        local stroke=edge(box,C.accent,1)
        local boxGradient=create("UIGradient",{Parent=stroke,Rotation=90})
        local health=rect(stage,42,35,3,286,C.border,45)
        local healthFill=rect(health,0,29,3,257,Color3.new(1,1,1),46)
        local healthGradient=create("UIGradient",{Parent=healthFill,Rotation=90})
        local healthText=text(stage,"90",19,51,22,16,C.textBright,9,47)
        local name=text(stage,player.DisplayName,32,9,256,21,Color3.new(1,1,1),11,47)
        name.TextXAlignment=Enum.TextXAlignment.Center
        local nameGradient=create("UIGradient",{Parent=name,Rotation=90})
        local distance=text(stage,"125 st",90,324,140,14,Color3.new(1,1,1),10,47)
        distance.TextXAlignment=Enum.TextXAlignment.Center
        local distanceGradient=create("UIGradient",{Parent=distance,Rotation=90})
        local weapon=text(stage,"Rifle",105,339,100,13,C.textDim,9,47)
        weapon.TextXAlignment=Enum.TextXAlignment.Center
        local flags=text(stage,"Idle",276,80,40,17,C.textDim,9,47)
        local weaponIcon=create("ImageLabel",{Parent=stage,Position=UDim2.fromOffset(190,337),
            Size=UDim2.fromOffset(20,16),BackgroundTransparency=1,ZIndex=48})
        local nameIcon=create("ImageLabel",{Parent=stage,Position=UDim2.fromOffset(68,12),
            Size=UDim2.fromOffset(14,14),BackgroundTransparency=1,ZIndex=48})
        local bones={}
        for _,p in ipairs({{.5,.12,.5,.32},{.5,.32,.5,.57},{.5,.32,.22,.44},
            {.22,.44,.13,.6},{.5,.32,.78,.44},{.78,.44,.87,.6},
            {.5,.57,.32,.78},{.32,.78,.28,.98},{.5,.57,.68,.78},{.68,.78,.72,.98}}) do
            local dx,dy=(p[3]-p[1])*160,(p[4]-p[2])*280
            local bone=rect(stage,80+(p[1]+p[3])*80,35+(p[2]+p[4])*140,
                math.sqrt(dx*dx+dy*dy),1,C.accent,47)
            bone.AnchorPoint=Vector2.new(.5,.5); bone.Rotation=math.deg(math.atan2(dy,dx))
            bones[#bones+1]=bone
        end
        local hint=text(previewPanel,"",13,414,314,26,C.textDim,10,43)
        hint.Visible=false
        local model,basePivot,center,size,yaw,zoom
        local previewPlayer=player
        local modelSource=nil
        local renderLiveOverlay
        local modelKind,renderKind,sourceReady=nil,"image",false
        yaw,zoom=0,1
        local function layoutBounds()
            local x,y,w,h=48,35,224,286
            if renderKind=="model" and model then
                local bounds,dimensions=model:GetBoundingBox()
                local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
                local focal=300/(2*math.tan(math.rad(camera.FieldOfView)/2))
                for a=-1,1,2 do for b=-1,1,2 do for c=-1,1,2 do
                    local point=bounds:PointToWorldSpace(Vector3.new(
                        dimensions.X*a/2,dimensions.Y*b/2,dimensions.Z*c/2))
                    local p=camera.CFrame:PointToObjectSpace(point)
                    if p.Z<-.01 then
                        local px,py=160+p.X*focal/-p.Z,174-p.Y*focal/-p.Z
                        minX=math.min(minX,px); maxX=math.max(maxX,px)
                        minY=math.min(minY,py); maxY=math.max(maxY,py)
                    end
                end end end
                if minX<math.huge then
                    x=math.clamp(minX,18,280); y=math.clamp(minY,30,290)
                    w=math.clamp(maxX-x,20,302-x); h=math.clamp(maxY-y,20,319-y)
                end
            end
            local pad=(state.esp_box_padding_x or 0)+(state.esp_padding_x_quick or 0)
            box.Position=UDim2.fromOffset(x-pad,y); box.Size=UDim2.fromOffset(w+pad*2,h)
            fill.Position=box.Position; fill.Size=box.Size; glow.Position=box.Position; glow.Size=box.Size
            health.Position=UDim2.fromOffset(x-pad-6,y); health.Size=UDim2.fromOffset(3,h)
            healthFill.Position=UDim2.fromOffset(0,h*.1); healthFill.Size=UDim2.fromOffset(3,h*.9)
            healthText.Position=UDim2.fromOffset(x-pad-29,y+h*.1-6)
            flags.Position=UDim2.fromOffset(x+w+pad+4,y+45)
        end
        local function updateCamera()
            if not model then return end
            local tangent=math.tan(math.rad(camera.FieldOfView)/2)
            local distance=math.max(size.Y/(2*tangent),size.X/(2*tangent*(272/300)))
                +size.Z/2
            camera.CFrame=CFrame.lookAt(center+Vector3.new(0,0,-distance*1.06*zoom),center)
            model:PivotTo(CFrame.new(center)*CFrame.Angles(0,yaw,0)*CFrame.new(-center)*basePivot)
            layoutBounds()
            if renderLiveOverlay then task.defer(renderLiveOverlay) end
        end
        local interaction=create("TextButton",{Parent=stage,Name="RotateZoomSurface",
            Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=49})
        local rotating,lastX
        interaction.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1
                or input.UserInputType==Enum.UserInputType.Touch then rotating=input; lastX=input.Position.X end
        end)
        interaction.InputChanged:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseWheel then
                zoom=math.clamp(zoom-input.Position.Z*.08,.65,1.6); updateCamera()
            end
        end)
        local move=UserInputService.InputChanged:Connect(function(input)
            if rotating and (input.UserInputType==Enum.UserInputType.MouseMovement or input==rotating) then
                yaw=yaw+(input.Position.X-lastX)*.015; lastX=input.Position.X; updateCamera()
            end
        end)
        local ended=UserInputService.InputEnded:Connect(function(input)
            if input==rotating or input.UserInputType==Enum.UserInputType.MouseButton1 then rotating=nil end
        end)
        previewPanel.Destroying:Connect(function() move:Disconnect(); ended:Disconnect() end)
        local function parseID(value)
            local input=tostring(value or ""):match("^%s*(.-)%s*$")
            return input:match("^rbxassetid://(%d+)")
                or input:match("[?&]id=(%d+)")
                or input:match("/catalog/(%d+)") or input:match("/library/(%d+)")
                or input:match("/asset/(%d+)") or input:match("^%d+$")
        end
        local function asset(value)
            local id=parseID(value)
            return id and "rbxassetid://"..id or ""
        end
        local lastSource,serial=nil,0
        local function pickInGameModel()
            local characters=require(game.ReplicatedStorage.Modules.StateObject).classes.Character
            if characters then
                for _,character in pairs(characters.objects) do
                    local owner=character.owner
                    local viewmodel=character.values and character.values.viewmodels
                    if owner and owner:get()==player and viewmodel and viewmodel.Parent then
                        return viewmodel,player
                    end
                end
            end
            local custom=workspace:FindFirstChild('VioletTungTungSahur')
            if custom and custom:IsA('Model') then return custom,player end
            local function fullCharacter(model)
                if not model or not model:IsA('Model') then return false end
                local count=0
                for _,item in ipairs(model:GetDescendants()) do
                    if item:IsA('BasePart') and item.Name~='HumanoidRootPart' and item.Name~='collision' then
                        count+=1
                        if count>=6 then return true end
                    end
                end
                return false
            end
            local worldCharacter=workspace:FindFirstChild(player.Name)
            if fullCharacter(worldCharacter) then return worldCharacter,player end
            if fullCharacter(player.Character) then return player.Character,player end
            return nil,player
        end
        local function visualMode()
            viewport.Visible=renderKind=="model"
            img.Visible=not viewport.Visible
            modeLabel.Text=viewport.Visible and "3D" or "IMAGE"
            hint.Text=""
        end
        local function finish(version,message)
            if version~=serial or not stage.Parent then return end
            sourceReady=message==nil
            previewPanel:SetAttribute("LoadState",sourceReady and "Ready" or "Error")
            status.Text=message or ""
            status.Visible=message~=nil
            visualMode()
            if refreshPreview then refreshPreview() end
        end
        local function prepareModel(candidate,kind,version)
            if version~=serial or not worldModel.Parent then candidate:Destroy(); return end
            local parts=0
            for _,item in ipairs(candidate:GetDescendants()) do
                if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
                    item:Destroy()
                elseif item:IsA('Motor6D') or item:IsA('Bone') then
                    item.Transform=CFrame.identity
                elseif item:IsA("BasePart") then
                    parts=parts+1
                    item.Anchored=true; item.CanCollide=false; item.CanTouch=false; item.CanQuery=false
                    item.LocalTransparencyModifier=0
                    if item.Name~='HumanoidRootPart' and item.Name~='collision' then item.Transparency=0 end
                end
            end
            if parts==0 then candidate:Destroy(); finish(version,"This asset has no visible 3D parts."); return end
            if model then model:Destroy() end
            model=candidate; modelKind=kind
            local bounds=model:GetBoundingBox()
            local facing=model:FindFirstChild('HumanoidRootPart',true)
                or model:FindFirstChild('torso',true) or model:FindFirstChild('UpperTorso',true)
            local flat=facing and Vector3.new(facing.CFrame.LookVector.X,0,facing.CFrame.LookVector.Z)
            local origin=(flat and flat.Magnitude>.001)
                and CFrame.lookAt(bounds.Position,bounds.Position+flat.Unit) or CFrame.new(bounds.Position)
            for _,part in ipairs(model:GetDescendants()) do
                if part:IsA('BasePart') then part.CFrame=origin:ToObjectSpace(part.CFrame) end
            end
            model.Parent=worldModel
            local bounds
            bounds,size=model:GetBoundingBox()
            center=bounds.Position; basePivot=model:GetPivot(); yaw=0; zoom=1
            renderKind="model"
            updateCamera()
            viewport:SetAttribute("ModelLoaded",true)
            viewport:SetAttribute("AssetSource",kind)
            finish(version)
        end
        local function loadImageContent(content,version)
            renderKind="image"; img.Image=content; visualMode()
            if content=="" then finish(version,"Enter a Roblox asset ID in the gear menu."); return end
            task.spawn(function()
                local ok=pcall(function() game:GetService("ContentProvider"):PreloadAsync({img}) end)
                if version~=serial or not img.Parent then return end
                if ok and img.IsLoaded then finish(version)
                else finish(version,"Image could not load. Check its ID and access permissions.") end
            end)
            task.delay(8,function()
                if version==serial and img.Parent and not sourceReady and not img.IsLoaded then
                    finish(version,"Image unavailable. Check its ID and access permissions.")
                end
            end)
        end
        local function loadAsset(id,version)
            if not id then finish(version,"Enter a numeric asset ID or a Roblox asset URL."); return end
            task.spawn(function()
                local ok,info=pcall(function()
                    return game:GetService("MarketplaceService"):GetProductInfo(tonumber(id))
                end)
                if version~=serial or not stage.Parent then return end
                if ok and info.AssetTypeId==1 then
                    loadImageContent("rbxassetid://"..id,version)
                    return
                end
                -- Inspect decals and models without executing any asset scripts.
                local imported,objects=pcall(function() return game:GetObjects("rbxassetid://"..id) end)
                if version~=serial or not stage.Parent then
                    if imported then for _,object in ipairs(objects) do object:Destroy() end end
                    return
                end
                if not imported then
                    if ok and info.AssetTypeId==13 then
                        loadImageContent("rbxthumb://type=Asset&id="..id.."&w=420&h=420",version)
                    else
                        finish(version,"Asset could not load. Check its ID and access permissions.")
                    end
                    return
                end
                local container=Instance.new("Model")
                container.Name="PreviewAsset_"..id
                local texture
                for _,object in ipairs(objects) do
                    if object:IsA("Decal") or object:IsA("Texture") then texture=object.Texture end
                    object.Parent=container
                end
                if texture then
                    container:Destroy()
                    loadImageContent(texture,version)
                else
                    prepareModel(container,"asset:"..id,version)
                end
            end)
        end
        local function loadSource(mode)
            local inGameModel,inGamePlayer=pickInGameModel()
            local value=mode=="Image" and tostring(state.esp_preview_image_url)
                or tostring(state.esp_preview_asset_id)
            local source=mode..value
            if source==lastSource and (mode~='Player Model' or modelSource==inGameModel) then return end
            lastSource=source; serial=serial+1
            local version=serial
            sourceReady=false
            previewPanel:SetAttribute("LoadState","Loading")
            renderKind=mode=="Player Model" and "model" or "image"
            status.Visible=true; status.Text="Loading preview..."
            img.Image=""
            visualMode()
            if mode=="Player Model" then
                modelSource=inGameModel
                previewPlayer=inGamePlayer or player
                task.spawn(function()
                    local ok,result=pcall(function()
                        local character=inGameModel
                        if character then
                            local wasArchivable=character.Archivable
                            character.Archivable=true
                            local success,clone=pcall(function() return character:Clone() end)
                            character.Archivable=wasArchivable
                            if success and clone then return clone end
                        end
                        return game:GetService('Players'):CreateHumanoidModelFromUserId(player.UserId)
                    end)
                    if not ok or not result then finish(version,"Could not load your player model."); return end
                    prepareModel(result,inGameModel and "player" or "avatar",version)
                end)
            elseif mode=="Asset ID" then
                loadAsset(parseID(value),version)
            elseif cachedImages[value] then
                loadImageContent(cachedImages[value],version)
            else
                task.spawn(function()
                    local ok,result=pcall(function()
                        if type(getcustomasset)~="function" then error("Use a published Roblox asset ID") end
                        if value:match("^https?://") then
                            local bytes=game:HttpGet(value)
                            if bytes:sub(2,4)~="PNG" then error("Choose a PNG image") end
                            local path="violetlol_preview_"..tostring(math.floor(os.clock()*1000))..".png"
                            writefile(path,bytes)
                            return getcustomasset(path)
                        end
                        return getcustomasset(value)
                    end)
                    if version~=serial or not img.Parent then return end
                    if ok then cachedImages[value]=result; loadImageContent(result,version)
                    else finish(version,"Image unavailable. Choose a PNG URL or a Roblox asset ID.") end
                end)
            end
        end
        local liveOverlay=create('Frame',{Parent=stage,Name='LiveESPOverlay',Size=UDim2.fromScale(1,1),
            BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=false,ZIndex=50})
        local previewData,previewController
        local function previewPoint(position)
            local localPoint=camera.CFrame:PointToObjectSpace(position)
            local depth=-localPoint.Z
            if depth<=.03 then return end
            local scale=previewScaler.Scale
            local viewSize=viewport.AbsoluteSize/scale
            local offset=(viewport.AbsolutePosition-stage.AbsolutePosition)/scale
            local focal=viewSize.Y/(2*math.tan(math.rad(camera.FieldOfView)/2))
            return Vector2.new(offset.X+viewSize.X/2+localPoint.X*focal/depth,
                offset.Y+viewSize.Y/2-localPoint.Y*focal/depth)
        end
        local function previewBox()
            local bounds,dimensions=model:GetBoundingBox()
            local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
            for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                local point=previewPoint(bounds:PointToWorldSpace(Vector3.new(
                    dimensions.X*x/2,dimensions.Y*y/2,dimensions.Z*z/2)))
                if point then
                    minX=math.min(minX,point.X); minY=math.min(minY,point.Y)
                    maxX=math.max(maxX,point.X); maxY=math.max(maxY,point.Y)
                end
            end end end
            if minX==math.huge then return end
            local cfg=previewController.Table.Boxes['Bounding Box']
            local padX=cfg.BoxX or 0
            local padY=cfg.BoxY or 0
            return math.floor(minX-padX),math.floor(minY-padY),
                math.max(1,math.ceil(maxX-minX+padX*2)),math.max(1,math.ceil(maxY-minY+padY*2))
        end
        local function gradient(top,bottom)
            return ColorSequence.new({ColorSequenceKeypoint.new(0,top),ColorSequenceKeypoint.new(1,bottom)})
        end
        local function ensureLiveOverlay()
            local environment=(getgenv and getgenv()) or _G
            local runtime=environment.Violets and environment.Violets.Library or environment.Library
            local controller=runtime and runtime.ESPController
            if not controller or not controller.Holder then return end
            if previewController==controller and previewData and previewData.Objects.TargetHolder.Parent then
                return controller,previewData
            end
            if previewData and previewData.Objects.TargetHolder then previewData.Objects.TargetHolder:Destroy() end
            previewController=controller
            previewData={Objects={},SkeletonSegments={},SkeletonPoints={},Health=100,MaxHealth=100,
                Armor=0,MaxArmor=100,Alive=true,WalkActive=false,JumpActive=false}
            controller:InitEsp(previewData,liveOverlay)
            local holder=previewData.Objects.TargetHolder
            holder.Name='LiveESPPreviewObjects'
            holder.ZIndex=51
            for _,object in ipairs(holder:GetDescendants()) do
                if object:IsA('GuiObject') then object.ZIndex=math.max(object.ZIndex+50,51) end
            end
            return controller,previewData
        end
        renderLiveOverlay=function()
            local controller,data=ensureLiveOverlay()
            if not controller or not data then return end
            local objects=data.Objects
            if not sourceReady or not model or not model.Parent or not controller.Table.Enabled then
                objects.TargetHolder.Visible=false
                return
            end
            local x,y,w,h=previewBox()
            if not x then objects.TargetHolder.Visible=false; return end
            local cfg=controller.Table
            local boxes=cfg.Boxes
            local texts=cfg.Texts
            local bars=cfg.Bars
            local actual=controller.Cache[previewPlayer]
            data.Character=model
            data.Health=actual and actual.Health or 100
            data.MaxHealth=actual and actual.MaxHealth or 100
            data.CurrentTool=actual and actual.CurrentTool or 'none'
            data.WalkActive=actual and actual.WalkActive or false
            data.JumpActive=actual and actual.JumpActive or false
            if data.SkeletonModel~=model then
                data.SkeletonModel=model
                data.SkeletonSegments=controller:BuildSkeletonSegments(model)
                table.clear(data.SkeletonPoints)
            end
            controller:ApplyLayout(data)
            local target=objects.TargetHolder
            target.Visible=true
            target.Position=UDim2.fromOffset(x,y)
            target.Size=UDim2.fromOffset(w,h)
            objects.BoxGlow.Size=UDim2.fromOffset(w,h)
            objects.BoxOutlineHolder.Size=UDim2.fromOffset(w,h)
            objects.BoxInlineHolder.Size=UDim2.fromOffset(w+2,h+2)
            objects.BoxFill.Size=UDim2.fromOffset(w,h)
            objects.BoxGlow.ImageTransparency=boxes.Enabled and boxes['Box Glow'].Enabled and 0 or 1
            objects.BoxOutlineHolder.Visible=boxes.Enabled
            objects.BoxInlineHolder.Visible=boxes.Enabled
            objects.BoxFill.Visible=boxes.Enabled and boxes.Filled.Enabled
            objects.BoxInlineGradient.Color=gradient(boxes.Gradients.Top,boxes.Gradients.Bot)
            objects.BoxGlowGradient.Color=gradient(boxes['Box Glow'].Top,boxes['Box Glow'].Bot)
            objects.BoxGlowGradient.Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,boxes['Box Glow'].Transparency[1]),
                NumberSequenceKeypoint.new(1,boxes['Box Glow'].Transparency[2])})
            objects.BoxFillGradient.Color=gradient(boxes.Filled.Top,boxes.Filled.Bot)
            objects.BoxFillGradient.Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,boxes.Filled.Transparency[1]),
                NumberSequenceKeypoint.new(1,boxes.Filled.Transparency[2])})
            local skeleton=cfg.Skeleton
            objects.SkeletonHolder.Visible=skeleton.Enabled
            for i,line in ipairs(objects.SkeletonLines) do
                local segment=data.SkeletonSegments[i]
                line.BackgroundColor3=skeleton.Color
                if skeleton.Enabled and segment then
                    local a=controller:ResolveSkeletonNode(segment[1])
                    local b=controller:ResolveSkeletonNode(segment[2])
                    controller:SetSkeletonLine(line,a and previewPoint(a),b and previewPoint(b),x,y,skeleton.Thickness)
                else line.Visible=false end
            end
            local nameCfg=texts.Name
            local avatar='rbxthumb://type=AvatarHeadShot&id='..tostring(previewPlayer.UserId)..'&w=48&h=48'
            data.IconUrl=avatar
            objects.NameRow.Visible=nameCfg.Enabled or nameCfg.Icon
            objects.TargetName.Visible=nameCfg.Enabled
            objects.TargetName.Text=nameCfg.UseDisplay and (previewPlayer.DisplayName..' (@'..previewPlayer.Name..')') or previewPlayer.Name
            objects.TargetNameGradient.Color=gradient(nameCfg.Top,nameCfg.Bot)
            objects.PlayerIcon.Visible=nameCfg.Icon
            objects.PlayerIcon.Image=avatar
            local distanceCfg=texts.Distance
            objects.Distance.Visible=distanceCfg.Enabled
            local root=actual and actual.RootPart
            objects.Distance.Text=root and string.format('%dst',math.floor((workspace.CurrentCamera.CFrame.Position-root.Position).Magnitude)) or '--st'
            objects.DistanceGradient.Color=gradient(distanceCfg.Top,distanceCfg.Bot)
            local weaponCfg=texts.Weapon
            objects.Weapon.Visible=weaponCfg.Enabled
            objects.Weapon.Text=data.CurrentTool
            objects.WeaponGradient.Color=gradient(weaponCfg.Top,weaponCfg.Bot)
            if objects.WeaponImage then objects.WeaponImage.Visible=false end
            local flagsCfg=texts.Flags
            objects.FlagsRow.Visible=flagsCfg.Enabled
            objects.WalkFlag.Visible=flagsCfg.Enabled and data.WalkActive
            objects.JumpFlag.Visible=flagsCfg.Enabled and data.JumpActive
            objects.IdleFlag.Visible=flagsCfg.Enabled and not data.WalkActive and not data.JumpActive
            for _,entry in ipairs({{objects.WalkFlagGradient,flagsCfg},{objects.JumpFlagGradient,flagsCfg},
                {objects.IdleFlagGradient,flagsCfg}}) do entry[1].Color=gradient(entry[2].Top,entry[2].Bot) end
            local healthCfg=bars['Health Bar']
            local ratio=math.clamp(data.Health/math.max(data.MaxHealth,1),0,1)
            objects.HealthBarOutline.Visible=healthCfg.Enabled
            if healthCfg.Enabled then
                controller:UpdateBarLayout(data,'HealthBar',ratio,w,h)
                objects.HealthBarGradient.Color=ColorSequence.new({
                    ColorSequenceKeypoint.new(0,healthCfg.Top),ColorSequenceKeypoint.new(.5,healthCfg.Mid),
                    ColorSequenceKeypoint.new(1,healthCfg.Bot)})
                objects.HealthBarText.Visible=healthCfg.Text
                objects.HealthBarText.Text=tostring(math.floor(data.Health+.5))
            end
            objects.ArmorBarOutline.Visible=false
            objects.ArmorBarText.Visible=false
        end
        previewSettings=function()
            settings(gear,"ESP Preview settings",285,function(panel)
                text(panel,"Shows an active in-game player model.",14,51,250,40,C.textDim,11,94)
                text(panel,"ESP colors and layout use the live settings.",14,105,250,40,C.textDim,11,94)
            end)
        end
        gear.MouseButton1Click:Connect(previewSettings)
        refreshPreview=function()
            if not previewPanel or not previewPanel.Parent then return end
            loadSource('Player Model')
            visualMode()
            for _,element in ipairs({box,fill,glow,health,healthText,name,distance,weapon,flags,nameIcon,weaponIcon}) do
                element.Visible=false
            end
            for _,bone in ipairs(bones) do bone.Visible=false end
            renderLiveOverlay()
        end
        local refreshElapsed=0
        local previewConnection=RunService.RenderStepped:Connect(function(dt)
            if not previewPanel or not previewPanel.Parent then return end
            refreshElapsed+=dt
            if refreshElapsed<.1 then return end
            refreshElapsed=0
            if previewPanel.Visible then refreshPreview() end
        end)
        previewPanel.Destroying:Connect(function() previewConnection:Disconnect() end)
        if previewPosition then previewPanel.Position=UDim2.fromOffset(previewPosition.X,previewPosition.Y)
            previewPanel:SetAttribute("Detached",true) end
        resize(); refreshPreview()
    end
    function api.HidePreview()
        closeSettings()
        if previewPanel then previewPanel:Destroy() end
        previewPanel,previewScaler,refreshPreview,previewSettings,previewHeaderGradient=nil,nil,nil,nil,nil
        resize()
    end
    function api.SyncVisibility()
        if mobileToggle then mobileToggle.Visible=unlocked and (UserInputService.TouchEnabled or state["hud.mobile_toggle"]==true) end
        if previewPanel then previewPanel.Visible=unlocked and window.Visible and currentTab=="ESP" and state["hud.preview"] end
        syncBackdrop()
    end

    local watermarkFields={
        {"script","Script name","code"},
        {"fps","FPS","activity"},{"ping","Ping","wifi"},{"executor","Executor","cpu"},
        {"session","Session time","timer"},{"clock","Local clock","clock"},
        {"location","Client region","location"},{"game","Game","game"},
        {"profile","Profile","profile"},{"player","Player name","user"},{"avatar","Avatar","user"},
    }
    icons.cpu="77549309870247"
    watermark=surface(gui,"Watermark",20,20,500,32,40)
    if UserInputService.TouchEnabled then watermark.Position=UDim2.fromOffset(8,64) end
    watermark.Visible=unlocked and state["hud.watermark"]
    local watermarkScale=create("UIScale",{Parent=watermark,Scale=1})
    local watermarkDrag=rect(watermark,0,0,500,32,C.input,41)
    watermarkDrag.BackgroundTransparency=1
    local accentBar=rect(watermark,2,1,496,1,Color3.new(1,1,1),46)
    local accentGradient=create("UIGradient",{Parent=accentBar,Color=ColorSequence.new(
        state["theme.header_left"] or HEADER_GRADIENT_LEFT_DEFAULT,
        state["theme.header_right"] or HEADER_GRADIENT_RIGHT_DEFAULT)})
    local cells={}
    for _,entry in ipairs(watermarkFields) do
        local cell=rect(watermark,0,0,70,32,C.input,42)
        cell.Name="Watermark_"..entry[1]; cell.BackgroundTransparency=1
        local image=icon(cell,entry[3],8,10,12,44)
        image.ImageColor3=C.textDim
        local caption=text(cell,"",26,0,500,32,C.textBright,11,44)
        caption.TextTruncate=Enum.TextTruncate.None
        local divider=rect(cell,0,10,1,12,C.subtleBorder,43)
        cells[entry[1]]={frame=cell,image=image,text=caption,divider=divider}
    end
    local watermarkGear=icon(watermark,"settings",0,10,12,45,true)
    watermarkGear.Name="WatermarkSettings"
    drag(watermark,watermarkDrag)
    watermarkGear.MouseButton1Click:Connect(function()
        settings(watermarkGear,"Watermark settings",358,function(panel)
            for i,entry in ipairs(watermarkFields) do
                check(panel,entry[2],"watermark."..entry[1],48+(i-1)*27)
            end
        end)
    end)
    local watermarkAvatar="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=48&h=48"
    local function layoutWatermark()
        if not watermark.Parent then return end
        local x=3
        for _,entry in ipairs(watermarkFields) do
            local key=entry[1]; local cell=cells[key]
            local visible=state["watermark."..key]
            cell.frame.Visible=visible
            if visible then
                local width
                if key=="avatar" then
                    width=28
                    cell.image.Image=watermarkAvatar
                    cell.image.Position=UDim2.fromOffset(4,6)
                    cell.image.Size=UDim2.fromOffset(20,20)
                    cell.image.ImageColor3=Color3.new(1,1,1)
                    round(cell.image,10); cell.text.Visible=false
                else
                    local textWidth=cell.text.TextBounds.X
                    if textWidth==0 then textWidth=#cell.text.Text*5 end
                    width=math.ceil(textWidth)+(key=="script" and 14 or 34)
                end
                cell.frame.Position=UDim2.fromOffset(x,0)
                cell.frame.Size=UDim2.fromOffset(width,32)
                cell.divider.Visible=x>3
                x=x+width
            end
        end
        watermarkGear.Position=UDim2.fromOffset(x+7,10)
        watermark.Size=UDim2.fromOffset(x+26,32)
        watermarkDrag.Size=watermark.Size
        accentBar.Size=UDim2.new(1,-4,0,1)
        local view=workspace.CurrentCamera.ViewportSize
        watermarkScale.Scale=math.min(1,(view.X-16)/(x+26))
        watermark.Position=UDim2.fromOffset(math.clamp(watermark.Position.X.Offset,8,
            math.max(8,view.X-(x+26)*watermarkScale.Scale-8)),watermark.Position.Y.Offset)
    end
    for _,entry in ipairs(watermarkFields) do
        cells[entry[1]].text:GetPropertyChangedSignal("TextBounds"):Connect(layoutWatermark)
    end
    cells.script.image.Visible=false
    cells.script.text.Position=UDim2.fromOffset(5,0)
    cells.script.text.TextColor3=C.accent
    setHeadingFont(cells.script.text)
    shimmerText(cells.script.text,5)
    local function updateWatermark()
        watermark.Visible=unlocked and state["hud.watermark"]
        local seconds=math.floor(os.clock()-started)
        local ping="--"
        pcall(function()
            ping=tostring(math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()+.5))
        end)
        local values={
            script=windowApi.TitlePrefix..windowApi.TitleSuffix,fps=tostring(fps).." FPS",
            ping=ping.." ms",executor=executorName,
            session=string.format("%02d:%02d",math.floor(seconds/60),seconds%60),
            clock=os.date("%H:%M"),location=region,game=gameNameText.Text,
            profile=state["config.profile_name"] or "default",player=player.Name,avatar="",
        }
        for _,entry in ipairs(watermarkFields) do
            local value=tostring(values[entry[1]] or "")
            if #value>32 then value=value:sub(1,29).."..." end
            cells[entry[1]].text.Text=value
        end
        cells.script.text.TextColor3=C.accent
        accentGradient.Color=ColorSequence.new(
            state["theme.header_left"] or HEADER_GRADIENT_LEFT_DEFAULT,
            state["theme.header_right"] or HEADER_GRADIENT_RIGHT_DEFAULT)
        layoutWatermark()
    end

    bindsPanel=surface(gui,"KeybindList",20,82,236,80,40)
    if UserInputService.TouchEnabled then bindsPanel.Position=UDim2.fromOffset(8,108) end
    local bindsScale=create("UIScale",{Parent=bindsPanel,Scale=1})
    local function fitBinds()
        local view=workspace.CurrentCamera.ViewportSize
        bindsScale.Scale=math.min(1,(view.X-16)/236,(view.Y-24)/math.max(80,bindsPanel.Size.Y.Offset))
    end
    connect(bindsPanel:GetPropertyChangedSignal("Size"),fitBinds)
    connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fitBinds)
    fitBinds()
    local bindsHeader=rect(bindsPanel,2,2,232,26,C.input,41)
    themeHeader(bindsHeader)
    icon(bindsHeader,"keyboard",10,6,14,43)
    setHeadingFont(text(bindsHeader,"Keybinds",32,0,150,26,C.textBright,11,43))
    local activeCount=text(bindsHeader,"",167,0,27,26,C.textDim,10,43)
    activeCount.TextXAlignment=Enum.TextXAlignment.Right
    local bindsGear=icon(bindsHeader,"settings",207,6,14,44,true); bindsGear.Name="KeybindSettings"
    rect(bindsPanel,12,29,212,1,C.separator,42)
    drag(bindsPanel,bindsHeader)
    local bindRows={}
    local lastBindsSignature
    local function updateBinds()
        bindsPanel.Visible=unlocked and state["hud.keybinds"]
        local list={}
        if state["keybinds.show_menu"] then list[#list+1]={name="Menu",key=windowApi.MenuKey.Name,mode="Toggle",active=window.Visible} end
        for _,spec in ipairs(library.keybinds) do
            if spec.ParentToggle then
                local active=spec.ParentToggle:Get()==true
                if active or not state["keybinds.active_only"] then
                    list[#list+1]={name=spec.ParentToggle.Name,key=tostring(spec:Get()),mode=spec.Mode,active=active}
                end
            end
        end
        local signature={tostring(state["keybinds.show_mode"]),tostring(C.accent)}
        local active=0
        for _,item in ipairs(list) do
            signature[#signature+1]=item.name..item.key..item.mode..tostring(item.active)
            if item.active then active=active+1 end
        end
        activeCount.Text=tostring(active)
        local key=table.concat(signature,"|")
        if key==lastBindsSignature then return end
        lastBindsSignature=key
        for _,row in ipairs(bindRows) do row:Destroy() end
        table.clear(bindRows)
        if #list==0 then list={{name="No active binds",key="",mode="",active=false}} end
        for i,item in ipairs(list) do
            local row=rect(bindsPanel,10,35+(i-1)*25,216,24,C.input,42); row.BackgroundTransparency=1
            rect(row,1,7,2,10,item.active and C.accent or C.separator,43)
            text(row,item.name,10,0,112,24,item.active and C.textBright or C.textDim,11,44)
            text(row,state["keybinds.show_mode"] and item.mode:lower() or "",
                121,0,44,24,C.textDim,9,44)
            local badge=rect(row,165,3,48,18,C.input,43)
            bevel(badge,false,44,true)
            local caption=text(badge,item.key~="" and displayKey(item.key) or "—",1,0,46,18,
                item.active and C.accent or C.textDim,10,45)
            caption.TextXAlignment=Enum.TextXAlignment.Center
            bindRows[#bindRows+1]=row
        end
        bindsPanel.Size=UDim2.fromOffset(236,41+#list*25)
    end
    bindsGear.MouseButton1Click:Connect(function()
        settings(bindsGear,"Keybind list settings",148,function(panel)
            check(panel,"Show active binds only","keybinds.active_only",49)
            check(panel,"Show bind mode","keybinds.show_mode",77)
            check(panel,"Include menu key","keybinds.show_menu",105)
        end)
    end)
    -- Supplied toast behavior: typed icons, animated stack, timed progress and dismissal.
    ensureSetting("hud.notifications",true)
    ensureSetting("notifications.duration",4)
    ensureSetting("notifications.keybinds",true)
    ensureSetting("hud.status",true)
    ensureSetting("status.player","No target")
    if state["status.player"]=="Local player" then setSetting("status.player","No target") end
    ensureSetting("status.avatar",true)
    ensureSetting("status.distance",true)
    ensureSetting("status.target_mode","Nearest crosshair")
    ensureSetting("status.max_distance",3000)
    ensureSetting("status.team_check",false)
    local toasts={}
    icons.info="7072717857"; icons.alert="7072978559"; icons.folder="7072716775"
    icons.sword="7485051715"; icons.target="7072723337"
    local toastTypes={
        info={icon="info"},success={icon="check",color=GREEN},
        warning={icon="alert",color=YELLOW},error={icon="close",color=RED},
        combat={icon="sword",color=RED},config={icon="folder"},target={icon="target"},
    }
    local function arrangeToasts()
        local view=workspace.CurrentCamera.ViewportSize
        for index,toast in ipairs(toasts) do
            toast.Size=UDim2.fromOffset(math.min(toast:GetAttribute("NaturalWidth") or 160,view.X-40),24)
            TweenService:Create(toast,TweenInfo.new(.3,Enum.EasingStyle.Exponential,Enum.EasingDirection.InOut),
                {Position=UDim2.fromOffset(20,math.min(100+(index-1)*28,math.max(8,view.Y-32)))}):Play()
        end
    end
    function api.Notify(options)
        if not gui.Parent or not unlocked or not state["hud.notifications"] then return end
        options=type(options)=="table" and options or {text=tostring(options)}
        local style=toastTypes[options.type or "info"] or toastTypes.info
        local color=options.color or style.color or C.accent
        local duration=math.clamp(tonumber(options.time or options.duration or state["notifications.duration"]) or 4,1,20)
        local message=options.text or options.name or (options.title and options.message and tostring(options.title)..": "..tostring(options.message))
            or options.message or options.title or "Notification"
        local view=workspace.CurrentCamera.ViewportSize
        local measured=game:GetService("TextService"):GetTextSize(tostring(message),12,FONT,Vector2.new(4096,24)).X
        local naturalWidth=math.max(85,math.ceil(measured)+42)
        local toast=create("CanvasGroup",{Parent=gui,Name="Notification",Size=UDim2.fromOffset(math.min(naturalWidth,view.X-40),24),
            AnchorPoint=Vector2.new(1,0),Position=UDim2.fromOffset(20,100),BackgroundColor3=Color3.fromRGB(8,8,8),BorderSizePixel=0,
            GroupTransparency=1,ZIndex=110})
        toast:SetAttribute("NaturalWidth",naturalWidth)
        local inline=rect(toast,1,1,0,22,Color3.fromRGB(58,58,58),111); inline.Size=UDim2.new(1,-2,1,-2)
        local background=rect(inline,1,1,0,20,Color3.new(1,1,1),112); background.Size=UDim2.new(1,-2,1,-2)
        gloss(background,Color3.fromRGB(22,22,22),Color3.fromRGB(13,13,13))
        rect(toast,2,2,2,20,color,113)
        local symbol=icon(toast,style.icon,9,5,14,114); symbol.ImageColor3=color
        symbol.ImageTransparency=0
        local caption=text(toast,tostring(message),28,1,1024,20,Color3.fromRGB(200,200,200),12,114)
        caption.TextTruncate=Enum.TextTruncate.None
        task.delay(.03,function()
            if not toast.Parent then return end
            toast:SetAttribute("NaturalWidth",math.max(85,math.ceil(caption.TextBounds.X)+40))
            caption.Size=UDim2.new(1,-38,1,-4)
            caption.TextTruncate=Enum.TextTruncate.AtEnd
            arrangeToasts()
        end)
        local progress=rect(toast,2,21,0,1,color,114)
        local dismissed=false
        local function dismiss()
            if dismissed then return end
            dismissed=true
            local index=table.find(toasts,toast)
            if index then table.remove(toasts,index) end
            arrangeToasts()
            if toast.Parent then
                animate(toast,{AnchorPoint=Vector2.new(1,0),GroupTransparency=1},.35,Enum.EasingStyle.Quint)
                task.delay(.37,function() if toast.Parent then toast:Destroy() end end)
            end
        end
        toast:SetAttribute("Message",tostring(message))
        toasts[#toasts+1]=toast
        if #toasts>4 then local old=table.remove(toasts,1); old:Destroy() end
        arrangeToasts()
        animate(toast,{GroupTransparency=0,AnchorPoint=Vector2.new(0,0)},.45,Enum.EasingStyle.Quint)
        animate(progress,{Size=UDim2.new(1,-4,0,1)},duration,Enum.EasingStyle.Linear)
        task.delay(duration,dismiss)
        return {Dismiss=dismiss,Instance=toast}
    end
    library.notify=function(_,options) return api.Notify(options) end
    library.notification=library.notify
    windowApi.Notify=function(_,options) return api.Notify(options) end
    -- Target HUD uses the supplied compact ProfileRow + HealthRow arrangement.
    local statusPanel=surface(gui,"TargetHUDContainer",20,275,280,134,40)
    attachGlow(statusPanel)
    local statusScale=create("UIScale",{Parent=statusPanel,Scale=1})
    local statusHeader=rect(statusPanel,2,2,276,28,Color3.new(1,1,1),41)
    local statusHeaderGradient=create("UIGradient",{Parent=statusHeader,Color=ColorSequence.new(
        Color3.fromRGB(33,33,37),Color3.fromRGB(22,22,25))})
    local targetIcon=icon(statusHeader,"target",10,6,16,43)
    targetIcon.ImageColor3=Color3.new(1,1,1); targetIcon.ImageTransparency=0
    local statusTitle=setHeadingFont(text(statusHeader,"Target HUD",34,0,168,28,C.textBright,13,43))
    local headerAccent=rect(statusHeader,0,27,276,1,C.accent,43)
    local statusGear=icon(statusHeader,"settings",229,7,15,44,true)
    statusGear.ImageColor3=C.textBright
    statusGear.Name="TargetHUDSettings"
    statusGear.MouseButton1Click:Connect(function()
        settings(statusGear,"Target HUD settings",255,function(panel)
            local names={"No target"}
            for _,other in ipairs(Players:GetPlayers()) do names[#names+1]=other.Name end
            select(panel,"Detection","status.target_mode",{"Nearest crosshair","Nearest player","Manual"},49)
            select(panel,"Manual target","status.player",names,111)
            check(panel,"Show avatar","status.avatar",180)
            check(panel,"Team check","status.team_check",208)
        end)
    end)
    local statusClose=icon(statusHeader,"close",254,7,15,44,true)
    statusClose.ImageColor3=C.textBright
    statusClose.MouseButton1Click:Connect(function() setSetting("hud.status",false) end)
    drag(statusPanel,statusHeader,function(pos)
        setSetting("status.x",pos.X); setSetting("status.y",pos.Y)
    end)
    local profileInset=rect(statusPanel,8,37,264,88,Color3.fromRGB(8,8,8),41)
    local profileCard=rect(profileInset,1,1,262,86,Color3.new(1,1,1),42)
    gloss(profileCard,Color3.fromRGB(22,22,22),Color3.fromRGB(13,13,13))
    local avatar=create("ImageLabel",{Parent=statusPanel,Name="PlayerAvatar",Position=UDim2.fromOffset(16,43),
        Size=UDim2.fromOffset(46,46),BackgroundColor3=Color3.fromRGB(13,13,13),BorderSizePixel=0,ZIndex=43})
    create("UICorner",{Parent=avatar,CornerRadius=UDim.new(0,5)})
    create("UIStroke",{Parent=avatar,Color=Color3.fromRGB(8,8,8),Thickness=1,Transparency=.35})
    local title=setHeadingFont(text(statusPanel,"No target",74,44,188,20,C.textBright,14,44)); title.Name="PlayerName"
    title.TextTruncate=Enum.TextTruncate.AtEnd
    local userName=text(statusPanel,"",58,42,170,16,C.textDim,10,44); userName.Visible=false
    local playerStatus=text(statusPanel,"Searching for players",74,67,188,16,C.text,11,44)
    playerStatus.Name="PlayerStatus"
    local distance=text(statusPanel,"",16,91,160,16,C.text,10,43)
    local hpText=text(statusPanel,"--",193,91,69,17,C.textBright,11,46); hpText.Name="HealthText"
    hpText.TextXAlignment=Enum.TextXAlignment.Right
    local track=rect(statusPanel,16,113,246,6,Color3.fromRGB(8,8,8),43)
    local healthGlow=create("ImageLabel",{Parent=statusPanel,Name="HealthGlow",
        Position=UDim2.fromOffset(8,106),Size=UDim2.fromOffset(260,20),
        BackgroundTransparency=1,BorderSizePixel=0,Image="rbxassetid://5028857084",
        ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(24,24,276,276),
        ImageColor3=GREEN,ImageTransparency=.48,ZIndex=42})
    create("UICorner",{Parent=track,CornerRadius=UDim.new(1,0)})
    local healthTrack=rect(track,1,1,244,4,Color3.fromRGB(13,13,13),44)
    create("UICorner",{Parent=healthTrack,CornerRadius=UDim.new(1,0)})
    healthTrack.ClipsDescendants=true
    local hpBar=rect(healthTrack,0,0,244,4,Color3.new(1,1,1),45); hpBar.Name="HealthBar"
    create("UICorner",{Parent=hpBar,CornerRadius=UDim.new(1,0)})
    local hpGradient=create("UIGradient",{Parent=hpBar,Rotation=90,Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,.4),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,.4)})})
    local targetHUD={target=nil,status_flags={},status_demo=false,Items={Container=statusPanel,PlayerAvatar=avatar,
        Title=title,PlayerStatus=playerStatus,PlayerDistance=distance,HealthText=hpText,HealthBar=hpBar}}
    local avatarId
    function targetHUD.set_target(target)
        if target~=nil and (typeof(target)~="Instance" or not target:IsA("Player")) then return false end
        targetHUD.target=target
        setSetting("status.target_mode",target and "Manual" or "Nearest crosshair")
        setSetting("status.player",target and target.Name or "No target")
        return true
    end
    function targetHUD.set_visible(visible) setSetting("hud.status",visible==true) end
    function targetHUD.flag_status(target,kind,duration)
        if target then targetHUD.status_flags[target.UserId]={state=kind,expires=os.clock()+(duration or 1)} end
    end
    library.active_target_hud=targetHUD
    library.target_hud=function(_,options)
        if options and options.default~=nil then targetHUD.set_visible(options.default) end
        if options and typeof(options.position)=="UDim2" then
            statusPanel.Position=options.position
            setSetting("status.x",options.position.X.Offset); setSetting("status.y",options.position.Y.Offset)
        end
        return targetHUD
    end
    windowApi.StatusViewer=targetHUD
    local function fitStatus()
        local view=workspace.CurrentCamera.ViewportSize
        statusScale.Scale=math.min(1,(view.X-16)/280,(view.Y-16)/134)
        local x=tonumber(state["status.x"]) or statusPanel.Position.X.Offset
        local y=tonumber(state["status.y"]) or statusPanel.Position.Y.Offset
        statusPanel.Position=UDim2.fromOffset(math.clamp(x,8,math.max(8,view.X-280*statusScale.Scale-8)),
            math.clamp(y,8,math.max(8,view.Y-134*statusScale.Scale-8)))
    end
    local function updateStatus()
        if not statusPanel.Parent then return end
        statusPanel.Visible=unlocked and state["hud.status"]==true
        if not statusPanel.Visible then return end
        local target
        if state["status.target_mode"]=="Manual" then
            target=Players:FindFirstChild(state["status.player"] or "")
        else
            local cam=workspace.CurrentCamera
            local ownRoot=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local origin=ownRoot and ownRoot.Position or cam.CFrame.Position
            local screenCenter=cam.ViewportSize/2
            local bestScore=math.huge
            for _,candidate in ipairs(Players:GetPlayers()) do
                if candidate~=player and (not state["status.team_check"] or player.Team==nil or candidate.Team~=player.Team) then
                    local character=candidate.Character
                    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
                    local root=character and character:FindFirstChild("HumanoidRootPart")
                    if root and humanoid and humanoid.Health>0 then
                        local dist=(root.Position-origin).Magnitude
                        if dist<=(state["status.max_distance"] or 3000) then
                            local screen,onScreen=cam:WorldToViewportPoint(root.Position)
                            local score=state["status.target_mode"]=="Nearest player" and dist
                                or (onScreen and (Vector2.new(screen.X,screen.Y)-screenCenter).Magnitude or 100000+dist)
                            if score<bestScore then bestScore=score; target=candidate end
                        end
                    end
                end
            end
        end
        targetHUD.target=target
        statusPanel:SetAttribute("TargetUserId",target and target.UserId or 0)
        statusPanel:SetAttribute("DetectionMode",state["status.target_mode"])
        local character=target and target.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local ownRoot=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local health=humanoid and humanoid.Health or 0
        local maximum=humanoid and humanoid.MaxHealth or 0
        local fraction=maximum>0 and math.clamp(health/maximum,0,1) or 0
        hpText.Text=humanoid and tostring(math.floor(health)).." HP" or "-- HP"
        local healthColor=fraction>.5 and YELLOW:Lerp(GREEN,(fraction-.5)*2) or RED:Lerp(YELLOW,fraction*2)
        hpBar.BackgroundColor3=healthColor
        healthGlow.Visible=humanoid~=nil and health>0
        animate(healthGlow,{ImageColor3=healthColor,Size=UDim2.fromOffset(244*fraction+16,20)},.18)
        animate(hpBar,{Size=UDim2.new(fraction,0,1,0)},.18)
        title.Text=target and target.DisplayName or "No target"
        userName.Text=target and "@"..target.Name or "Choose a player in settings"
        avatar.Visible=state["status.avatar"]==true and target~=nil
        title.Position=UDim2.fromOffset(avatar.Visible and 74 or 16,44)
        playerStatus.Position=UDim2.fromOffset(avatar.Visible and 74 or 16,67)
        title.Size=UDim2.fromOffset(avatar.Visible and 188 or 246,20)
        playerStatus.Size=UDim2.fromOffset(avatar.Visible and 188 or 246,16)
        if target and avatarId~=target.UserId then
            avatarId=target.UserId
            avatar.Image="rbxthumb://type=AvatarHeadShot&id="..target.UserId.."&w=150&h=150"
        end
        distance.Visible=state["status.distance"]~=false
        distance.Text=root and ownRoot and tostring(math.floor((root.Position-ownRoot.Position).Magnitude)).." studs" or "-- studs"
        local caption,color="Searching for players",C.text
        if humanoid then
            caption,color=health<=0 and "Dead" or target==player and "Local player" or "Visible",health<=0 and RED or GREEN
            if target~=player and root and health>0 then
                local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
                local excluded={character}; if player.Character then excluded[#excluded+1]=player.Character end
                params.FilterDescendantsInstances=excluded
                local cam=workspace.CurrentCamera
                if workspace:Raycast(cam.CFrame.Position,root.Position-cam.CFrame.Position,params) then caption,color="Occluded",C.textDim end
            end
        end
        local flagged=target and targetHUD.status_flags[target.UserId]
        if flagged then
            if os.clock()<flagged.expires then
                local styles={manipulated={"Manipulated",RED},hitscanned={"Hitscanned",YELLOW},visible={"Visible",GREEN},not_visible={"Occluded",C.textDim}}
                local style=styles[flagged.state]; if style then caption,color=style[1],style[2] end
            else targetHUD.status_flags[target.UserId]=nil end
        end
        playerStatus.Text=caption; playerStatus.TextColor3=color
        headerAccent.BackgroundColor3=C.accent
    end
    connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),function() fitStatus(); arrangeToasts() end)
    connect(changed.Event,function(key)
        if key:sub(1,7)=="status." or key=="hud.status" then fitStatus(); updateStatus() end
    end)
    fitStatus()
    local statusTime=0
    connect(RunService.Heartbeat,function(dt)
        statusTime=statusTime+dt
        if statusTime>=.2 then statusTime=0; updateStatus() end
    end)
    local tickElapsed=0
    local watermarkMotion=0
    connect(RunService.RenderStepped,function(dt)
        frames=frames+1; elapsed=elapsed+dt; tickElapsed=tickElapsed+dt
        for i=#shimmerEffects,1,-1 do
            local effect=shimmerEffects[i]
            if not effect.gradient.Parent then table.remove(shimmerEffects,i)
            else
                effect.time=effect.time+dt
                local phase=(effect.time%effect.period)/effect.period
                effect.gradient.Offset=Vector2.new(phase<.25 and (-1.4+phase*11.2) or 1.4,0)
            end
        end
        if watermark.Visible then
            watermarkMotion=watermarkMotion+dt
            accentGradient.Offset=Vector2.new(math.sin(watermarkMotion*.6)*.12,0)
        end
        if elapsed>=.5 then fps=math.floor(frames/elapsed+.5); frames=0; elapsed=0 end
        if tickElapsed>=1 then tickElapsed=0; updateWatermark(); updateBinds() end
    end)
    connect(changed.Event,function(key)
        if key=="theme.outline_glow" or key=="theme.header_glow_blur" or key:sub(1,11)=="theme.glow_" then refreshGlow() end
        if previewHeaderGradient and previewHeaderGradient.Parent
            and (key=="theme.header_left" or key=="theme.header_right") then
            previewHeaderGradient.Color=ColorSequence.new(
                state["theme.header_left"],state["theme.header_right"])
        end
        if key:sub(1,12)=="hud.backdrop" then syncBackdrop() end
        if key=="theme.accent" then updateWatermark(); updateBinds() end
        if key:sub(1,4)=="esp_" and refreshPreview then refreshPreview() end
        if key=="hud.preview" then
            if state[key] and currentTab=="ESP" and not previewPanel then api.MountPreview() end
            api.SyncVisibility()
        end
        if key:sub(1,10)=="watermark." or key=="hud.watermark" or key=="config.profile_name" then updateWatermark() end
        if key:sub(1,9)=="keybinds." or key=="hud.keybinds" or key:find("_key$") or key:find("_mode$") or type(state[key])=="boolean" then updateBinds() end
    end)
    task.spawn(function()
        local ok,value=pcall(function()
            return game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(player)
        end)
        if ok then region=value; if watermark.Parent then updateWatermark() end end
    end)
    function api.Refresh() updateWatermark(); updateBinds(); api.SyncVisibility() end
    local mobileUpdate
    function api.ToggleMenu()
        if not unlocked then return end
        closeSettings(); closePopup(true)
        window.Visible=not window.Visible
        api.SyncVisibility()
        resize()
        if mobileToggle then
            mobileToggle:SetAttribute("MenuOpen",window.Visible)
            if mobileUpdate then mobileUpdate() end
        end
    end
    mobileToggle=create("TextButton",{Parent=gui,Name="MobileMenuToggle",
        Position=UDim2.fromOffset(0,10),Size=UDim2.fromOffset(48,48),
        BackgroundColor3=Color3.fromRGB(25,25,29),BorderSizePixel=0,
        Text="",Font=FONT,TextSize=14,TextColor3=C.textBright,
        AutoButtonColor=false,ZIndex=120,Visible=false})
    gloss(mobileToggle,Color3.fromRGB(37,36,43),Color3.fromRGB(20,20,24))
    create("UICorner",{Parent=mobileToggle,CornerRadius=UDim.new(0,10)})
    local mobileBorder=create("UIStroke",{Parent=mobileToggle,Thickness=1,Color=C.accent,Transparency=.35})
    local mobileBars={}
    for index=1,3 do
        local bar=rect(mobileToggle,24,17+(index-1)*7,20,2,C.textBright,122)
        bar.AnchorPoint=Vector2.new(.5,.5)
        create("UICorner",{Parent=bar,CornerRadius=UDim.new(1,0)})
        mobileBars[index]=bar
    end
    local mobileDot=rect(mobileToggle,37,8,4,4,C.accent,122)
    create("UICorner",{Parent=mobileDot,CornerRadius=UDim.new(1,0)})
    mobileUpdate=function()
        local showing=window.Visible
        mobileToggle:SetAttribute("Action",showing and "Hide UI" or "Open UI")
        mobileDot.BackgroundColor3=showing and C.accent or C.textDim
        animate(mobileBorder,{Color=showing and C.accent or C.subtleBorder,Transparency=showing and .2 or .1},.18)
        animate(mobileBars[1],{Position=UDim2.fromOffset(24,showing and 24 or 17),Rotation=showing and 45 or 0},.2,Enum.EasingStyle.Quart)
        animate(mobileBars[2],{BackgroundTransparency=showing and 1 or 0},.12)
        animate(mobileBars[3],{Position=UDim2.fromOffset(24,showing and 24 or 31),Rotation=showing and -45 or 0},.2,Enum.EasingStyle.Quart)
    end
    mobileUpdate()
    mobileToggle.MouseEnter:Connect(function() animate(mobileBorder,{Transparency=0},.12) end)
    mobileToggle.MouseLeave:Connect(function() animate(mobileBorder,{Transparency=.25},.12) end)
    local mobilePointer,mobileOrigin,mobilePosition,mobileMoved
    local suppressTapUntil=0
    local function clampToggle()
        local view=workspace.CurrentCamera.ViewportSize
        mobileToggle.Position=UDim2.fromOffset(math.clamp(mobileToggle.Position.X.Offset,8,math.max(8,view.X-56)),
            math.clamp(mobileToggle.Position.Y.Offset,8,math.max(8,view.Y-56)))
    end
    mobileToggle.Position=UDim2.fromOffset(math.max(8,(workspace.CurrentCamera.ViewportSize.X-48)/2),10)
    mobileToggle.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        mobilePointer=input; mobileOrigin=input.Position; mobilePosition=mobileToggle.Position; mobileMoved=false
    end)
    connect(UserInputService.InputChanged,function(input)
        if not mobilePointer or not (input==mobilePointer or input.UserInputType==Enum.UserInputType.MouseMovement and mobilePointer.UserInputType~=Enum.UserInputType.Touch) then return end
        local delta=input.Position-mobileOrigin
        if delta.Magnitude>7 then mobileMoved=true; suppressTapUntil=os.clock()+.3 end
        if mobileMoved then mobileToggle.Position=mobilePosition+UDim2.fromOffset(delta.X,delta.Y); clampToggle() end
    end)
    connect(UserInputService.InputEnded,function(input)
        if input~=mobilePointer then return end
        if mobileMoved then suppressTapUntil=os.clock()+.3 end
        mobilePointer=nil
    end)
    mobileToggle.Activated:Connect(function()
        if mobileMoved or os.clock()<suppressTapUntil then return end
        api.ToggleMenu()
    end)
    connect(window:GetPropertyChangedSignal("Visible"),function()
        mobileUpdate()
        mobileToggle:SetAttribute("MenuOpen",window.Visible)
    end)
    connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),clampToggle)
    connect(UserInputService:GetPropertyChangedSignal("TouchEnabled"),api.SyncVisibility)
    connect(changed.Event,function(key) if key=="hud.mobile_toggle" then api.SyncVisibility() end end)
    api.SyncVisibility()
    function api.ShowKeyGate()
        if unlocked then return end
        syncBackdrop()
        gui:SetAttribute("KeyState","Waiting")
        local veil=create("TextButton",{Parent=gui,Name="KeyBackdrop",
            Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),
            BackgroundTransparency=1,Text="",AutoButtonColor=false,BorderSizePixel=0,ZIndex=130})
        animate(veil,{BackgroundTransparency=.4},.25)
        local gate=create("CanvasGroup",{Parent=gui,Name="KeySystem",
            AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,14),
            Size=UDim2.fromOffset(420,286),BackgroundTransparency=1,GroupTransparency=1,ZIndex=140})
        local function gateFit()
            local view=workspace.CurrentCamera.ViewportSize
            return math.min(1,(view.X-24)/420,(view.Y-28)/286)
        end
        local gateScale=create("UIScale",{Parent=gate,Scale=gateFit()*.955})
        local gateResize=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() gateScale.Scale=gateFit() end)
        gate.Destroying:Connect(function() gateResize:Disconnect() end)
        local card=surface(gate,"KeyCard",0,0,420,286,140)
        local header=rect(card,2,2,416,27,Color3.new(1,1,1),142)
        create("UIGradient",{Parent=header,Color=ColorSequence.new(
            state["theme.header_left"] or HEADER_GRADIENT_LEFT_DEFAULT,
            state["theme.header_right"] or HEADER_GRADIENT_RIGHT_DEFAULT)})
        local name=setHeadingFont(text(header,windowApi.TitlePrefix..windowApi.TitleSuffix,12,0,174,27,
            Color3.new(1,1,1),12,144))
        shimmerText(name,4.8)
        local access=text(header,"KEY SYSTEM",295,0,108,27,Color3.new(1,1,1),10,144)
        access.TextXAlignment=Enum.TextXAlignment.Right
        local stars={}
        for i,x in ipairs({127,151,175,199,223,247,271}) do
            stars[i]=create("ImageLabel",{Parent=header,Name="HeaderStar"..i,AnchorPoint=Vector2.new(.5,.5),
                Position=UDim2.fromOffset(x,i%2==0 and 18 or 7),Rotation=i%2==0 and 94 or -12,
                Size=UDim2.fromOffset(i%2==0 and 13 or 11,i%2==0 and 13 or 11),Image=HEADER_STAR_IMAGE,
                ImageColor3=Color3.new(1,1,1),ImageTransparency=.22,BackgroundTransparency=1,ZIndex=143})
        end
        setHeadingFont(text(card,"Enter your access key",22,43,376,28,C.textBright,18,143))
        text(card,"Verify your key to open the interface.",22,73,376,20,C.textDim,11,143)
        text(card,"ACCESS KEY",22,96,376,19,C.text,10,143)
        local inputBack=rect(card,22,118,376,38,C.input,142)
        bevel(inputBack,false,143)
        local inputStroke=edge(inputBack,C.subtleBorder,1)
        inputStroke.Transparency=.4
        icon(inputBack,"keyboard",11,12,15,145)
        local input=create("TextBox",{Parent=inputBack,Name="KeyInput",
            Position=UDim2.fromOffset(35,1),Size=UDim2.fromOffset(329,36),
            BackgroundTransparency=1,BorderSizePixel=0,ClearTextOnFocus=false,
            Text="",PlaceholderText="Paste your key here",PlaceholderColor3=C.textDim,
            TextColor3=C.textBright,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=145})
        input.FontFace=fontFace
        local track=rect(card,22,162,376,1,C.separator,142)
        local progress=rect(track,0,0,0,1,C.accent,144)
        local currentTone=C.accent
        local function gateButton(name,caption,x,width,primary)
            local hit=create("TextButton",{Parent=card,Name=name,
                Position=UDim2.fromOffset(x,174),Size=UDim2.fromOffset(width,36),
                BackgroundColor3=C.input,Text="",AutoButtonColor=false,BorderSizePixel=0,ZIndex=143})
            gloss(hit,primary and Color3.fromRGB(45,45,45) or Color3.fromRGB(39,39,39),Color3.fromRGB(26,26,26))
            bevel(hit,true,144)
            local outline=edge(hit,primary and C.accent or C.subtleBorder,1)
            outline.Transparency=primary and .75 or .9
            local captionLabel=setHeadingFont(text(hit,caption,0,0,width,36,primary and currentTone or C.text,12,146))
            captionLabel.TextXAlignment=Enum.TextXAlignment.Center
            hit.MouseEnter:Connect(function()
                animate(outline,{Transparency=.2},.12)
                if primary then captionLabel.TextColor3=currentTone else captionLabel.TextColor3=C.textBright end
            end)
            hit.MouseLeave:Connect(function()
                animate(outline,{Transparency=primary and .75 or .9},.15)
                captionLabel.TextColor3=primary and currentTone or C.text
                animate(captionLabel,{Position=UDim2.fromOffset(0,0)},.1)
            end)
            hit.MouseButton1Down:Connect(function() animate(captionLabel,{Position=UDim2.fromOffset(0,1)},.08) end)
            hit.MouseButton1Up:Connect(function() animate(captionLabel,{Position=UDim2.fromOffset(0,0)},.1) end)
            return hit,captionLabel
        end
        local verifyButton,verifyCaption=gateButton("VerifyKey","Verify key",22,242,true)
        local getButton=gateButton("GetKey","Get key",274,124,false)
        local feedbackBox=rect(card,22,222,376,44,C.input,142)
        bevel(feedbackBox,false,143,true)
        local feedbackTint=rect(feedbackBox,1,1,374,42,C.accent,144)
        feedbackTint.BackgroundTransparency=1
        local stateIcon=icon(feedbackBox,"lock",11,12,20,146)
        stateIcon.Name="KeyStatusIcon"
        stateIcon.AnchorPoint=Vector2.new(.5,.5)
        stateIcon.Position=UDim2.fromOffset(21,22)
        local iconScale=create("UIScale",{Parent=stateIcon,Scale=1})
        local feedback=setHeadingFont(text(feedbackBox,"Ready to verify",39,5,326,18,C.text,12,146))
        feedback.Name="KeyFeedback"
        local detail=text(feedbackBox,"Enter your key to continue.",39,23,326,16,C.textDim,10,146)
        detail.Name="KeyFeedbackDetail"
        local busy=false
        local red,green=Color3.fromRGB(245,91,112),Color3.fromRGB(104,225,155)
        local function setStatus(kind,message)
            gui:SetAttribute("KeyState",kind)
            stateIcon.Rotation=0
            local color=kind=="Invalid" and red or (kind=="Approved" and green or C.accent)
            local symbol=kind=="Invalid" and "close" or (kind=="Approved" and "check"
                or (kind=="Verifying" and "loader" or "lock"))
            currentTone=color
            stateIcon.Image="rbxassetid://"..icons[symbol]
            animate(stateIcon,{ImageColor3=color},.15)
            iconScale.Scale=.65
            animate(iconScale,{Scale=1},.28,Enum.EasingStyle.Back)
            feedback.Text=kind=="Invalid" and "Wrong key" or (kind=="Approved" and "Approved"
                or (kind=="Verifying" and "Verifying your key..." or "Ready to verify"))
            feedback.TextColor3=(kind=="Waiting") and C.text or color
            detail.Text=message or (kind=="Invalid" and "This key is incorrect. Please try again."
                or (kind=="Approved" and "Access verified. Opening your interface..."
                or (kind=="Verifying" and "Checking access. One moment..." or "Enter your key to continue.")))
            detail.TextColor3=(kind=="Invalid" or kind=="Approved") and color or C.textDim
            verifyCaption.Text=kind=="Invalid" and "Try again" or (kind=="Approved" and "Opening..."
                or (kind=="Verifying" and "Verifying..." or "Verify key"))
            verifyCaption.TextColor3=color
            input.TextColor3=(kind=="Invalid" or kind=="Approved") and color or C.textBright
            feedbackTint.BackgroundColor3=color
            animate(feedbackTint,{BackgroundTransparency=kind=="Waiting" and 1 or .94},.18)
            animate(inputStroke,{Color=kind=="Waiting" and C.subtleBorder or color,
                Transparency=kind=="Waiting" and .4 or .15},.16)
            progress.BackgroundColor3=color
            animate(progress,{Size=UDim2.fromOffset(kind=="Waiting" and 0
                or (kind=="Verifying" and 300 or 376),1)},kind=="Verifying" and .42 or .2)
        end
        local time=0
        local motion=RunService.RenderStepped:Connect(function(dt)
            time=time+dt
            for i,star in ipairs(stars) do star.ImageTransparency=.3+math.sin(time*1.4+i)*.13 end
            if gui:GetAttribute("KeyState")=="Verifying" then stateIcon.Rotation=(time*240)%360 end
        end)
        gate.Destroying:Connect(function() motion:Disconnect() end)
        local function showMain()
            if not gui.Parent then return end
            gate:Destroy(); veil:Destroy()
            unlocked=true
            gui:SetAttribute("AccessGranted",true)
            local position=window.Position
            local reveal=create("CanvasGroup",{Parent=window,Name="ApprovalReveal",
                Size=UDim2.fromScale(1,1),BackgroundTransparency=1,GroupTransparency=1,ZIndex=2})
            local visuals={}
            for _,child in ipairs(window:GetChildren()) do
                if child~=reveal and child:IsA("GuiObject") then
                    visuals[#visuals+1]=child
                    child.Parent=reveal
                end
            end
            window.Position=position+UDim2.fromOffset(0,12)
            window.Visible=true
            scaler.Scale=scaleNow*.97
            animate(scaler,{Scale=scaleNow},.36,Enum.EasingStyle.Quart)
            animate(window,{Position=position},.36,Enum.EasingStyle.Quart)
            animate(reveal,{GroupTransparency=0},.36)
            api.Refresh()
            task.delay(.4,function()
                if not reveal.Parent then return end
                for _,child in ipairs(visuals) do if child.Parent==reveal then child.Parent=window end end
                reveal:Destroy()
            end)
        end
        local function shake()
            task.spawn(function()
                for _,offset in ipairs({-6,5,-3,2,0}) do
                    if not gate.Parent or gui:GetAttribute("KeyState")~="Invalid" then return end
                    animate(gate,{Position=UDim2.new(.5,offset,.5,0)},.055)
                    task.wait(.06)
                end
            end)
        end
        local function verify()
            if busy or not gate.Parent then return end
            local entered=input.Text:match("^%s*(.-)%s*$")
            if entered=="" then setStatus("Invalid","Enter a key first."); shake(); return end
            busy=true; input:ReleaseFocus()
            setStatus("Verifying")
            task.delay(.5,function()
                if not gate.Parent then return end
                -- Configurable local demo validator.
                if entered~=tostring(options.Key or "test") then
                    busy=false; setStatus("Invalid"); shake()
                    return
                end
                setStatus("Approved")
                task.delay(.85,function()
                    if not gate.Parent then return end
                    animate(gate,{GroupTransparency=1,Position=UDim2.new(.5,0,.5,-12)},.27)
                    animate(veil,{BackgroundTransparency=1},.27)
                    task.delay(.28,showMain)
                end)
            end)
        end
        verifyButton.MouseButton1Click:Connect(verify)
        input.Focused:Connect(function()
            if not busy and gui:GetAttribute("KeyState")~="Invalid" then
                animate(inputStroke,{Color=C.accent,Transparency=.1},.15)
            end
        end)
        input:GetPropertyChangedSignal("Text"):Connect(function()
            if not busy and gui:GetAttribute("KeyState")=="Invalid" then
                setStatus("Waiting")
                gate.Position=UDim2.new(.5,0,.5,0)
            end
        end)
        input.FocusLost:Connect(function(enterPressed)
            if enterPressed then verify()
            elseif not busy and gui:GetAttribute("KeyState")=="Waiting" then
                animate(inputStroke,{Color=C.subtleBorder,Transparency=.4},.15)
            end
        end)
        getButton.MouseButton1Click:Connect(function()
            if busy then return end
            local key=tostring(options.Key or "test")
            local copied=type(setclipboard)=="function" and pcall(setclipboard,key)
            setStatus("Waiting",copied and "Test key copied. Paste it above." or ("Your test key is: "..key))
        end)
        animate(gate,{GroupTransparency=0,Position=UDim2.new(.5,0,.5,0)},.3)
        animate(gateScale,{Scale=gateFit()},.34,Enum.EasingStyle.Quart)
    end
    updateWatermark(); updateBinds()
    return api
end)()

-- VISUALS / WORLD: reference Gadget and Grenade ESP examples.
examples(library.tabs.World,"Gadget ESP","Left",{
    T("Gadget ESP","gadget_esp_enabled",true),
    T("Chams","gadget_esp_chams"),
    S("Distance Limit","gadget_esp_distance",50,10000,3000," st"),
    T("Show Name","gadget_esp_show_name",true),
    T("Show Distance","gadget_esp_show_distance",true),
    H("Gadget Types"),
    T("Drone","gadget_drone_enabled"),
    T("Default Camera","gadget_default_camera_enabled"),
    T("Bulletproof Camera","gadget_bulletproof_camera_enabled"),
    T("Sticky Camera","gadget_sticky_camera_enabled"),
    T("Claymore","gadget_claymore_enabled"),
    T("Barbed Wire","gadget_barbed_wire_enabled"),
    T("Shock Battery","gadget_shock_battery_enabled"),
    T("Breach Charge","gadget_breach_charge_enabled"),
    T("Hard Breach Charge","gadget_hard_breach_charge_enabled"),
    T("Thermite Charge","gadget_thermite_charge_enabled"),
    T("Remote C4","gadget_remote_c4_enabled"),
    T("Defuser","gadget_defuser_enabled"),
    T("Proximity Alarm","gadget_proximity_alarm_enabled"),
    T("Signal Disruptor","gadget_signal_disruptor_enabled"),
    T("Deployable Shield","gadget_deployable_shield_enabled"),
})
examples(library.tabs.World,"Grenade ESP","Top",{
    T("Grenade ESP","grenade_esp_enabled",true),
    T("Chams","grenade_esp_chams"),
    S("Distance Limit","grenade_esp_distance",50,10000,3000," st"),
    T("Show Name","grenade_esp_show_name",true),
    T("Show Distance","grenade_esp_show_distance",true),
    H("Grenade Types"),
    T("EMP Grenade","grenade_emp_enabled",true),
    T("Frag Grenade","grenade_frag_enabled",true),
    T("Impact Grenade","grenade_impact_enabled",true),
    T("Smoke Grenade","grenade_smoke_enabled",true),
    T("Incendiary Grenade","grenade_incendiary_enabled",true),
    T("Stun Grenade","grenade_stun_enabled",true),
    T("Toxic Charge","grenade_toxic_charge_enabled",true),
})
examples(library.tabs.World,"Environment","Bottom",{
    T("World Visuals","world_visuals"),
    T("Ambient Tint","world_ambient_tint",false,{Colors={
        colorEntry("Ambient Color","world_ambient_color",BLUE)}}),
    T("Clock Override","world_clock_override"),
    S("Clock Time","world_clock_time",0,24,12," h"),
    D("Weather","world_weather",{"Default","Clear","Overcast"},"Default"),
})

-- OTHER / MISC: reference Miscellaneous, Movement, and Device options.
examples(library.tabs.Misc,"Miscellaneous","Left",{
    T("Unlock All","unlock_all_enabled"),
    T("Instant Lean","instant_lean"),
    T("Instant Crouch","instant_crouch"),
    T("Instant Equip","instant_equip"),
    T("No Smoke","no_smoke"),
    T("No Stun","no_stun"),
    T("Device Spoofer","device_spoofer"),
    D("Spoofed Device","spoofed_device",{"console","mobile","pc"},"console"),
})
examples(library.tabs.Misc,"Movement","Top",{
    T("Fly","movement_fly",false,{Keybind="movement_fly_key",KeyDefault=Enum.KeyCode.F}),
    S("Fly Speed","movement_fly_speed",1,60,10," st/s"),
    T("Grapple Anywhere","movement_grapple_anywhere"),
    T("Grapple Noclip","movement_grapple_noclip"),
    T("Grapple Speed","movement_grapple_speed"),
    S("Repel Speed","movement_repel_speed",1,60,14," st/s"),
    S("Wall Distance","movement_wall_distance",4,40,14," st"),
})
examples(library.tabs.Misc,"Other","Bottom",{
    T("Instant Lean","misc_instant_lean"),
    T("Instant Crouch","misc_instant_crouch"),
    T("Instant Equip","misc_instant_equip"),
    D("Spoofed Device","misc_spoofed_device",{"console","mobile","pc"},"console"),
})

-- Config owns one section per pane: Profiles, Overlay Widgets, and Backgrounds.

-- ========================= PERSISTENT CONFIGS =========================
-- Supports the reference environment's readfile/writefile APIs. In ordinary
-- Roblox, the companion VioletLOLConfigServer Script supplies DataStore access.
-- LocalScripts alone cannot call DataStoreService or write local game files.
local hasFiles = type(readfile) == "function" and type(writefile) == "function"
local configRemote = ReplicatedStorage:FindFirstChild("VioletLOLConfigRPC")
local backendName = hasFiles and "local files"
    or (configRemote and configRemote:IsA("RemoteFunction") and "Roblox DataStore")
    or "unavailable (install config server)"
local selectedProfile = "default"
local configMessage = "ready"
local configStatusLabel
local configProfileInput
local isApplyingConfig = false
local metadataBooting = true
local metaRevision = 0
local settingRevision = 0
local saveQueued = false

local function cleanProfile(value)
    local cleaned = tostring(value or "default")
        :gsub("^%s+", ""):gsub("%s+$", "")
        :gsub("[^%w_%-]", "_"):sub(1, 24)
    return cleaned ~= "" and cleaned or "default"
end

local function configStatus(msg)
    configMessage = tostring(msg)
    if configStatusLabel and configStatusLabel.Parent then
        configStatusLabel.Text = configMessage
    end
end

local function requestStore(operation, name, data)
    if not hasFiles and not configRemote then
        configRemote = ReplicatedStorage:FindFirstChild("VioletLOLConfigRPC")
    end
    name = cleanProfile(name)
    if hasFiles then
        local path = (operation == "readMeta" or operation == "writeMeta")
            and "violetlol_meta.json" or ("violetlol_config_" .. name .. ".json")
        if operation == "readMeta" or operation == "readConfig" then
            local ok, contents = pcall(readfile, path)
            if not ok then return false, "not found" end
            local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, contents)
            if decodeOk and type(decoded) == "table" then return true, decoded end
            return false, "invalid saved JSON"
        elseif operation == "writeMeta" or operation == "writeConfig" then
            local okEncode, payload = pcall(HttpService.JSONEncode, HttpService, data)
            if not okEncode then return false, "cannot serialize config" end
            local ok, err = pcall(writefile, path, payload)
            return ok, ok and true or tostring(err)
        elseif operation == "deleteConfig" then
            if type(delfile) ~= "function" then return false, "delfile unavailable" end
            local ok, err = pcall(delfile, path)
            return ok, ok and true or tostring(err)
        end
    elseif configRemote and configRemote:IsA("RemoteFunction") then
        local ok, response = pcall(function()
            return configRemote:InvokeServer(operation, name, data)
        end)
        if not ok then return false, tostring(response) end
        if type(response) ~= "table" then return false, "invalid server response" end
        return response.ok == true, response.ok and response.value or (response.error or "server error")
    end
    return false, "persistence unavailable; install VioletLOLConfigServer"
end

local function encodeSetting(value)
    if typeof(value) == "Color3" then
        return {__type = "Color3", hex = rgbHex(value)}
    end
    if type(value) == "string" or type(value) == "boolean" or type(value) == "number" then
        return value
    end
    return nil
end

local function decodeSetting(value)
    if type(value) == "table" and value.__type == "Color3" then
        return parseHex(value.hex)
    end
    if type(value) == "string" or type(value) == "boolean" or type(value) == "number" then
        return value
    end
    return nil
end

local function snapshot()
    local values = {}
    for key, value in pairs(state) do
        if key:sub(1, 7) ~= "config." then
            values[key] = encodeSetting(value)
        end
    end
    return {version = 1, settings = values}
end

local function metadata()
    return {
        selected = selectedProfile,
        autoload = state["config.autoload"] == true,
        autosave = state["config.autosave"] == true,
    }
end

local function saveMeta()
    return requestStore("writeMeta", nil, metadata())
end

local function saveProfile(name, quiet)
    name = cleanProfile(name)
    local wasProfile = selectedProfile
    local ok, result = requestStore("writeConfig", name, snapshot())
    if ok then
        selectedProfile = name
        if not quiet then
            configStatus("saved: " .. name)
        else
            configStatus("autosaved: " .. name)
        end
        -- Avoid a second DataStore write on every slider/color change.
        if not quiet or wasProfile ~= name then saveMeta() end
    else
        configStatus((quiet and "autosave failed: " or "save failed: ") .. tostring(result))
    end
    if not quiet then overlayUI.Notify({type=ok and "config" or "error",
        text=ok and ("Saved profile: "..name) or ("Save failed: "..tostring(result))}) end
    return ok
end

local function loadProfile(name, quiet)
    gui:SetAttribute("NotificationQuietUntil",os.clock()+1)
    name = cleanProfile(name)
    local ok, saved = requestStore("readConfig", name)
    if not ok then
        if not quiet then configStatus("load failed: " .. tostring(saved)); overlayUI.Notify({type="error",text="Profile could not load: "..name}) end
        return false
    end
    if type(saved.settings) ~= "table" then
        if not quiet then configStatus("invalid config format") end
        return false
    end
    isApplyingConfig = true
    for key, packed in pairs(saved.settings) do
        if type(key) == "string" and key:sub(1, 7) ~= "config." then
            local value = decodeSetting(packed)
            if value ~= nil then
                local good = pcall(setSetting, key, value)
                if not good then warn("[violet.lol] Could not restore " .. key) end
            end
        end
    end
    isApplyingConfig = false
    selectedProfile = name
    if configProfileInput and configProfileInput.Parent then
        configProfileInput.Text = selectedProfile
    end
    if not quiet then configStatus("loaded: " .. name); overlayUI.Notify({type="config",text="Loaded profile: "..name}) end
    saveMeta()
    return true
end

local function scheduleAutosave()
    settingRevision = settingRevision + 1
    if saveQueued then return end
    saveQueued = true
    task.spawn(function()
        -- Debounce sliders and the HSV picker: never save on every drag frame.
        while true do
            local version = settingRevision
            task.wait(2.5)
            if version == settingRevision then break end
        end
        saveQueued = false
        if not isApplyingConfig and not metadataBooting
            and state["config.autosave"] == true then
            saveProfile(selectedProfile, true)
        end
    end)
end

local function scheduleMetaSave()
    metaRevision = metaRevision + 1
    local revision = metaRevision
    task.delay(0.7, function()
        if revision ~= metaRevision or metadataBooting then return end
        local ok, message = saveMeta()
        if not ok then configStatus("preferences not saved: " .. tostring(message)) end
    end)
end

ensureSetting("config.autoload", true)
ensureSetting("config.autosave", true)
changed.Event:Connect(function(key)
    if isApplyingConfig or metadataBooting then return end
    if key == "config.autoload" or key == "config.autosave" then
        scheduleMetaSave()
    elseif key:sub(1, 7) ~= "config." then
        if state["config.autosave"] == true then scheduleAutosave() end
    end
end)

-- Config uses exactly the same Section methods as the other tabs.
-- Persistent background gallery: URLs and image bytes are stored locally.
local backgrounds = (function()
    local api={entries={},dropdown=nil,statusLabel=nil,message="Add a Catbox image to begin."}
    local manifestPath="violetlol_backgrounds.json"
    local revision,busy=0,false
    local image=create("ImageLabel",{Parent=window,Name="CustomBackgroundImage",
        Position=UDim2.fromOffset(3,56),Size=UDim2.new(1,-6,1,-59),
        BackgroundTransparency=1,BorderSizePixel=0,Image="",ImageTransparency=.55,
        ScaleType=Enum.ScaleType.Crop,Visible=false,ZIndex=2})
    local panels={sidebar,leftBody.Parent,topBody.Parent,bottomBody.Parent,profile}
    local panelFlags={"theme.sidebar_opacity","theme.panel_opacity","theme.panel_opacity","theme.panel_opacity","theme.footer_opacity"}
    ensureSetting("theme.panel_opacity",85)
    ensureSetting("theme.panel_settings",true)
    ensureSetting("theme.sidebar_opacity",95)
    ensureSetting("theme.footer_opacity",95)
    local original={}
    for _,panel in ipairs(panels) do original[panel]=panel.BackgroundTransparency end
    original[main]=main.BackgroundTransparency
    original[mainSurround]=mainSurround.BackgroundTransparency
    local function status(message)
        api.message=message
        gui:SetAttribute("BackgroundStatus",message)
        if api.statusLabel and api.statusLabel.Parent then api.statusLabel.Text=message end
    end
    local function checksum(value)
        local hash=5381
        for i=1,#value do hash=(hash*33+value:byte(i))%4294967296 end
        return string.format("%08x",hash)
    end
    local function formatOf(bytes)
        if type(bytes)~="string" then return nil end
        if bytes:sub(1,8)==string.char(137).."PNG\r\n"..string.char(26).."\n" then return "png" end
        if bytes:sub(1,3)==string.char(255,216,255) then return "jpg" end
        if bytes:sub(1,4)=="RIFF" and bytes:sub(9,12)=="WEBP" then return "webp" end
        return nil
    end
    local function validURL(url)
        local host,path=url:match("^https://([^/]+)/([^?]+)")
        if host~="files.catbox.moe" and host~="litter.catbox.moe" then return false end
        local ext=path and path:match("%.([%a%d]+)$")
        ext=ext and ext:lower()
        return ext=="png" or ext=="jpg" or ext=="jpeg" or ext=="webp"
    end
    local function names()
        local result={"None"}
        for _,entry in ipairs(api.entries) do result[#result+1]=entry.name end
        return result
    end
    function api.Names() return names() end
    local function saveManifest()
        if type(writefile)~="function" then return end
        local ok,message=pcall(function()
            writefile(manifestPath,HttpService:JSONEncode({version=1,images=api.entries,
                selected=state["background.selected"],enabled=state["background.enabled"],
                opacity=state["background.opacity"],mode=state["background.mode"],
                tileWidth=state["background.tile_width"],tileHeight=state["background.tile_height"]}))
        end)
        if not ok then status("Could not save gallery: "..tostring(message)) end
    end
    local saved={}
    if type(readfile)=="function" then
        local ok,result=pcall(function() return HttpService:JSONDecode(readfile(manifestPath)) end)
        if ok and type(result)=="table" then
            saved=result
            for _,entry in ipairs(type(result.images)=="table" and result.images or {}) do
                if type(entry)=="table" and type(entry.name)=="string" and type(entry.url)=="string"
                    and validURL(entry.url) then
                    local format=entry.format
                    if format~="png" and format~="jpg" and format~="webp" then format="png" end
                    entry.id=checksum(entry.url)
                    entry.path="violetlol_bg_"..entry.id.."."..format
                    api.entries[#api.entries+1]=entry
                end
            end
        end
    end
    ensureSetting("background.selected",type(saved.selected)=="string" and saved.selected or "None")
    ensureSetting("background.enabled",saved.enabled==true)
    ensureSetting("background.opacity",tonumber(saved.opacity) or 45)
    ensureSetting("background.mode",type(saved.mode)=="string" and saved.mode or "Fit")
    ensureSetting("background.tile_width",tonumber(saved.tileWidth) or 256)
    ensureSetting("background.tile_height",tonumber(saved.tileHeight) or 256)
    ensureSetting("background.name","")
    ensureSetting("background.url","")
    local function entryByName(name)
        for i,entry in ipairs(api.entries) do if entry.name==name then return entry,i end end
    end
    local function style()
        local visible=state["background.enabled"]==true and entryByName(state["background.selected"])~=nil and image.Image~=""
        image.Visible=visible
        image.ImageTransparency=1-math.clamp(tonumber(state["background.opacity"]) or 45,0,100)/100
        local modes={Fit=Enum.ScaleType.Fit,Fill=Enum.ScaleType.Crop,
            Stretch=Enum.ScaleType.Stretch,Tile=Enum.ScaleType.Tile}
        image.ScaleType=modes[state["background.mode"]] or Enum.ScaleType.Fit
        image.TileSize=UDim2.fromOffset(
            math.clamp(tonumber(state["background.tile_width"]) or 256,64,1024),
            math.clamp(tonumber(state["background.tile_height"]) or 256,64,1024))
        main.BackgroundTransparency=visible and 1 or original[main]
        mainSurround.BackgroundTransparency=visible and 1 or original[mainSurround]
        for index,panel in ipairs(panels) do
            panel.BackgroundTransparency=state["theme.panel_settings"] and
                1-math.clamp(tonumber(state[panelFlags[index]]) or 85,0,100)/100 or original[panel]
        end
    end
    local function cachedAsset(entry)
        if type(getcustomasset)~="function" or type(writefile)~="function" then
            error("This client needs writefile and getcustomasset for Catbox backgrounds.")
        end
        if type(readfile)=="function" and entry.path then
            local ok,bytes=pcall(readfile,entry.path)
            if ok and formatOf(bytes) then return getcustomasset(entry.path) end
        end
        local bytes=game:HttpGet(entry.url)
        local format=formatOf(bytes)
        if not format then error("Choose a PNG, JPG, or WebP image.") end
        if #bytes>12*1024*1024 then error("Choose an image smaller than 12 MB.") end
        entry.format=format
        entry.path="violetlol_bg_"..entry.id.."."..format
        writefile(entry.path,bytes)
        return getcustomasset(entry.path)
    end
    local function applySelected()
        revision=revision+1
        local version=revision
        local entry=entryByName(state["background.selected"])
        if not entry or not state["background.enabled"] then
            style()
            if not entry then image.Visible=false; status("No custom background selected.") end
            return
        end
        status("Loading "..entry.name.."...")
        task.spawn(function()
            local ok,asset=pcall(cachedAsset,entry)
            if version~=revision or not image.Parent then return end
            if not ok then status(tostring(asset):gsub("^.-:%d+: ","")); return end
            image.Image=asset
            image:SetAttribute("Preset",entry.name)
            image:SetAttribute("CachePath",entry.path)
            style()
            saveManifest()
            status("Selected: "..entry.name.." · saved locally")
        end)
    end
    function api.Import()
        if busy then return end
        local url=tostring(state["background.url"] or ""):match("^%s*(.-)%s*$")
        if not validURL(url) then status("Paste a direct Catbox PNG, JPG, or WebP link."); return end
        local name=tostring(state["background.name"] or ""):match("^%s*(.-)%s*$"):sub(1,28)
        if name=="" or name=="None" then name="Background "..tostring(#api.entries+1) end
        local id=checksum(url)
        local existing
        for _,entry in ipairs(api.entries) do if entry.id==id then existing=entry end end
        local duplicate=entryByName(name)
        if duplicate and duplicate~=existing then
            local base=name
            local suffix=2
            repeat name=base:sub(1,24).." "..suffix; suffix=suffix+1 until not entryByName(name)
        end
        local entry=existing or {id=id,url=url,name=name}
        busy=true
        status("Downloading and saving image...")
        task.spawn(function()
            local ok,asset=pcall(cachedAsset,entry)
            busy=false
            if not gui.Parent then return end
            if not ok then status(tostring(asset):gsub("^.-:%d+: ","")); return end
            if not existing then api.entries[#api.entries+1]=entry end
            entry.name=name
            if api.dropdown then api.dropdown:Refresh(names()) end
            image.Image=asset
            setSetting("background.enabled",true)
            setSetting("background.selected",name)
            applySelected()
            saveManifest()
        end)
    end
    function api.Remove()
        local entry,index=entryByName(state["background.selected"])
        if not entry then status("Choose a saved background to remove."); return end
        setSetting("background.selected","None")
        setSetting("background.enabled",false)
        table.remove(api.entries,index)
        if api.dropdown then api.dropdown:Refresh(names()) end
        if type(delfile)=="function" and entry.path then pcall(delfile,entry.path) end
        image.Image=""
        style(); saveManifest(); status("Removed: "..entry.name)
    end
    local restoringPlacement=false
    local function restorePlacement()
        local entry=entryByName(state["background.selected"])
        if not entry then return end
        restoringPlacement=true
        setSetting("background.mode",entry.mode or "Fit")
        setSetting("background.tile_width",entry.tileWidth or 256)
        setSetting("background.tile_height",entry.tileHeight or 256)
        restoringPlacement=false
    end
    connect(changed.Event,function(key)
        if key=="theme.panel_settings" or key=="theme.panel_opacity" or key=="theme.sidebar_opacity" or key=="theme.footer_opacity" then style(); return end
        if key=="background.selected" then restorePlacement(); applySelected(); saveManifest()
        elseif key=="background.enabled" then applySelected(); saveManifest()
        elseif key=="background.opacity" or key=="background.mode"
            or key=="background.tile_width" or key=="background.tile_height" then
            style()
            if not restoringPlacement then
                local entry=entryByName(state["background.selected"])
                if entry then
                    entry.mode=state["background.mode"]
                    entry.tileWidth=state["background.tile_width"]
                    entry.tileHeight=state["background.tile_height"]
                end
                saveManifest()
            end
        end
    end)
    restorePlacement()
    applySelected()
    return api
end)()
-- OnMount lets its status / profile textbox point to their current live instances.
local overlayControls = configTab:Section({Name="Overlay Widgets", Side="Top"})
local watermarkControl = overlayControls:Toggle({Name="Watermark",Flag="hud.watermark",Default=true})
local watermarkOptions = watermarkControl:Settings()
for _,entry in ipairs({{"Script name","script"},{"FPS","fps"},{"Ping","ping"},
    {"Executor","executor"},
    {"Session time","session"},{"Local clock","clock"},{"Client region","location"},
    {"Game","game"},{"Profile","profile"},{"Player name","player"},{"Avatar","avatar"}}) do
    watermarkOptions:Toggle({Name=entry[1],Flag="watermark."..entry[2],
        Default=state["watermark."..entry[2]]})
end
local bindsControl = overlayControls:Toggle({Name="Keybind list",Flag="hud.keybinds",Default=true})
local bindsOptions = bindsControl:Settings()
bindsOptions:Toggle({Name="Active binds only",Flag="keybinds.active_only",Default=false})
bindsOptions:Toggle({Name="Show bind mode",Flag="keybinds.show_mode",Default=true})
bindsOptions:Toggle({Name="Include menu key",Flag="keybinds.show_menu",Default=true})
local notifyControl=overlayControls:Toggle({Name="Notifications",Flag="hud.notifications",Default=true})
local notifyOptions=notifyControl:Settings()
notifyOptions:Slider({Name="Duration",Flag="notifications.duration",Min=1,Max=10,Default=4,Suffix=" s"})
notifyOptions:Toggle({Name="Control and keybind changes",Flag="notifications.keybinds",Default=true})
notifyOptions:Button({Name="Test notification",Callback=function()
    overlayUI.Notify({type="success",text="Notifications are working."})
end})
local statusControl=overlayControls:Toggle({Name="Target HUD",Flag="hud.status",Default=true})
local statusOptions=statusControl:Settings()
local function statusPlayerNames()
    local names={"No target"}
    for _,other in ipairs(Players:GetPlayers()) do names[#names+1]=other.Name end
    return names
end
statusOptions:Dropdown({Name="Detection",Flag="status.target_mode",Default="Nearest crosshair",
    Options={"Nearest crosshair","Nearest player","Manual"}})
local statusPlayerControl=statusOptions:Dropdown({Name="Manual target",Flag="status.player",Default="No target",Options=statusPlayerNames()})
statusOptions:Slider({Name="Detection range",Flag="status.max_distance",Min=100,Max=10000,Default=3000,Suffix=" st"})
statusOptions:Toggle({Name="Team check",Flag="status.team_check",Default=false})
statusOptions:Toggle({Name="Distance",Flag="status.distance",Default=true})
statusOptions:Toggle({Name="Avatar",Flag="status.avatar",Default=true})
statusOptions:Label({Name="Drag the header to move the HUD.",TextSize=16})
connect(Players.PlayerAdded,function() statusPlayerControl:Refresh(statusPlayerNames()) end)
connect(Players.PlayerRemoving,function(leaving)
    if state["status.player"]==leaving.Name then setSetting("status.player","No target") end
    task.defer(function() if gui.Parent then statusPlayerControl:Refresh(statusPlayerNames()) end end)
end)
local previewControl = overlayControls:Toggle({Name="ESP preview",Flag="hud.preview",Default=true})
local previewOptions = previewControl:Settings()
previewOptions:Label({Name="Shows an in-game player model with the live ESP settings."})
overlayControls:Label({Name="Use each widget's gear for settings.",TextSize=17})
local backdropControl=overlayControls:Toggle({Name="Menu backdrop",Flag="hud.backdrop",Default=true})
local backdropOptions=backdropControl:Settings()
backdropOptions:Slider({Name="Dim strength",Flag="hud.backdrop_dim",Min=0,Max=70,Default=40,Suffix="%"})
backdropOptions:Slider({Name="Blur",Flag="hud.backdrop_blur",Min=0,Max=24,Default=14})
local glowControl=overlayControls:Toggle({Name="Outer outline glow",Flag="theme.outline_glow",Default=true})
local glowOptions=glowControl:Settings()
glowOptions:Colorpicker({Name="Glow color",Flag="theme.glow_color",Default=C.accent})
glowOptions:Slider({Name="Glow radius",Flag="theme.header_glow_blur",Min=4,Max=24,Default=12,Suffix=" px"})
glowOptions:Slider({Name="Glow strength",Flag="theme.glow_strength",Min=0,Max=100,Default=60,Suffix="%"})
glowOptions:Label({Name="Window and widget outlines. No inner panel glow.",TextSize=16})
local panelControl=overlayControls:Toggle({Name="Panel settings",Flag="theme.panel_settings",Default=true})
local panelOptions=panelControl:Settings()
panelOptions:Slider({Name="Content panel opacity",Flag="theme.panel_opacity",Min=0,Max=100,Default=85,Suffix="%"})
panelOptions:Slider({Name="Sidebar opacity",Flag="theme.sidebar_opacity",Min=0,Max=100,Default=95,Suffix="%"})
panelOptions:Slider({Name="Footer opacity",Flag="theme.footer_opacity",Min=0,Max=100,Default=95,Suffix="%"})
panelOptions:Label({Name="100% is solid; lower shows the background.",TextSize=16})
overlayControls:Toggle({Name="Show mobile menu button",Flag="hud.mobile_toggle",Default=false})
local backgroundSection=configTab:Section({Name="Custom Backgrounds",Side="Bottom"})
local backgroundControl=backgroundSection:Toggle({Name="Background image",Flag="background.enabled",Default=false,Y=14})
local placementSettings=backgroundControl:Settings()
placementSettings:Dropdown({Name="Placement",Flag="background.mode",Default="Fit",
    Options={"Fit","Fill","Stretch","Tile"}})
placementSettings:Slider({Name="Tile width",Flag="background.tile_width",Min=64,Max=1024,Default=256,Step=16,Suffix=" px"})
placementSettings:Slider({Name="Tile height",Flag="background.tile_height",Min=64,Max=1024,Default=256,Step=16,Suffix=" px"})
placementSettings:Label({Name="Fit keeps the whole image visible.",TextSize=16})
backgrounds.dropdown=backgroundSection:Dropdown({Name="Saved backgrounds",Flag="background.selected",
    Options=backgrounds.Names(),Default="None",Y=58})
backgrounds.dropdown:Refresh(backgrounds.Names())
backgroundSection:Textbox({Name="Preset name",Flag="background.name",Default="",
    Placeholder="Background name",Y=151,Height=36,
    OnMount=function(instance) instance.Name="BackgroundName" end})
backgroundSection:Textbox({Name="Catbox image URL",Flag="background.url",Default="",
    Placeholder="Paste a Catbox image link",Y=198,Height=36,
    OnMount=function(instance) instance.Name="BackgroundURL" end})
backgroundSection:Button({Name="Save & apply",Y=249,X=20,Width=245,Height=38,
    Callback=backgrounds.Import,OnMount=function(instance) instance.Name="ImportBackground" end})
backgroundSection:Button({Name="Remove",Y=249,X=278,Width=147,Height=38,
    Callback=backgrounds.Remove,OnMount=function(instance) instance.Name="RemoveBackground" end})
backgroundSection:Slider({Name="Image opacity",Flag="background.opacity",Min=5,Max=100,
    Default=45,Suffix="%",Y=303})
backgroundSection:Label({Name="",Y=388,Height=44,TextSize=16,
    OnMount=function(instance)
        backgrounds.statusLabel=instance
        instance.Name="BackgroundStatus"
        instance.Text=backgrounds.message
        instance.TextWrapped=true
        instance.TextTruncate=Enum.TextTruncate.None
    end})
backgroundSection:Label({Name="Images are saved on this device for reuse.",Y=443,TextSize=15,Color=C.textDim})
local configMain = configTab:Section({Name="Profiles", Side="Left"})
configMain:Label({Name="config name", X=20, Y=14, Width=405, Height=29,
    OnMount=function(instance) if instance then instance.TextSize = math.floor(21 * TEXT_SCALE + 0.5) end end})
local profileControl = configMain:Textbox({Name="profile", Placeholder="default",
    Default=selectedProfile, Flag="config.profile_name",
    X=20, Y=49, Width=405, Height=39,
    OnMount=function(instance)
        configProfileInput = instance
        if instance then instance.Text = selectedProfile end
    end})
local function profileName()
    local clean = cleanProfile(profileControl:Get())
    profileControl:Set(clean)
    return clean
end
configMain:Button({Name="save", X=20, Y=103, Width=126, Height=40,
    Callback=function()
        local name = profileName()
        configStatus("saving " .. name .. "...")
        task.spawn(function() saveProfile(name, false) end)
    end})
configMain:Button({Name="load", X=159, Y=103, Width=126, Height=40,
    Callback=function()
        local name = profileName()
        configStatus("loading " .. name .. "...")
        task.spawn(function() loadProfile(name, false) end)
    end})
configMain:Button({Name="delete", X=299, Y=103, Width=126, Height=40,
    Callback=function()
        local name = profileName()
        configStatus("deleting " .. name .. "...")
        task.spawn(function()
            local ok, message = requestStore("deleteConfig", name)
            if ok then
                if name == selectedProfile then
                    selectedProfile = "default"
                    saveMeta()
                end
                configStatus("deleted: " .. name)
            else
                configStatus("delete failed: " .. tostring(message))
            end
        end)
    end})
configMain:Toggle({Name="autoload", Default=true,
    Flag="config.autoload", X=20, Y=159})
configMain:Toggle({Name="autosave", Default=true,
    Flag="config.autosave", X=20, Y=202})
configMain:Colorpicker({Name="accent color", Default=C.accent,
    Flag="theme.accent", X=20, Y=269, Width=405})
configMain:Colorpicker({Name="header left", Default=HEADER_GRADIENT_LEFT_DEFAULT,
    Flag="theme.header_left", X=20, Y=315, Width=405})
configMain:Colorpicker({Name="header right", Default=HEADER_GRADIENT_RIGHT_DEFAULT,
    Flag="theme.header_right", X=20, Y=359, Width=405})
configMain:Label({Name="", X=20, Y=432, Width=405, Height=30,
    OnMount=function(instance)
        configStatusLabel = instance
        configStatus(configMessage)
    end})
configMain:Label({Name="storage: " .. backendName, X=20, Y=469,
    Width=405, Height=28,
    OnMount=function(instance)
        if instance then instance.TextSize = math.floor(16 * TEXT_SCALE + 0.5); instance.TextColor3 = C.textDim end
    end})

-- Both copies of a setting control one value, including after profile loads.
local aliases={
    visible_check_quick="visible_check",team_check_quick="team_check",
    fov_radius_quick="fov_radius",fov_fill_quick="fov_fill",
    max_shift_quick="max_shift",multipoints_quick="multipoints",point_scale_quick="point_scale",
    recoil_percent_quick="recoil_percent",spread_percent_quick="spread_percent",
    fire_rate_quick="fire_rate",ads_speed_quick="ads_speed",
    esp_distance_limit_quick="esp_distance_limit",esp_team_check_quick="esp_team_check",
    esp_gradient_quick="esp_gradient",esp_box_glow_quick="esp_box_glow",
    esp_box_fill_quick="esp_box_fill",esp_padding_x_quick="esp_box_padding_x",esp_thickness_quick="esp_skeleton_thickness",
}
for alias,canonical in pairs(aliases) do setSetting(alias,state[canonical]) end
for _,spec in ipairs(library.keybinds) do ensureSetting(spec.Flag.."_mode",spec.Mode) end
local function refreshBindModes(key)
    for _,spec in ipairs(library.keybinds) do
        if key==nil or key==spec.Flag.."_mode" then
            local mode=state[spec.Flag.."_mode"]
            if mode=="Hold" or mode=="Always" or mode=="Toggle" then spec.Mode=mode end
            if spec.Mode=="Always" and spec.ParentToggle and spec.ToggleTarget~=false then spec.ParentToggle:Set(true) end
        end
    end
end
refreshBindModes()
connect(changed.Event,function(key,value)
    local canonical=aliases[key]
    if canonical then
        if state[canonical]~=value then setSetting(canonical,value) end
    else
        for alias,target in pairs(aliases) do
            if target==key and state[alias]~=value then setSetting(alias,value) end
        end
    end
    if key:sub(-5)=="_mode" then refreshBindModes(key) end
    local control=library.options[key]
    if unlocked and not isApplyingConfig and not metadataBooting and not canonical
        and os.clock()>(gui:GetAttribute("NotificationQuietUntil") or 0)
        and state["notifications.keybinds"] and control and control.Kind=="Toggle"
        and key:sub(1,7)~="config." then
        overlayUI.Notify({text=control.Name..(value and " enabled" or " disabled"),type=value and "success" or "info"})
    end
end)
local tabBodyPositions={[leftBody]=leftBody.Position,[topBody]=topBody.Position,[bottomBody]=bottomBody.Position}
local function renderTab(name)
    if not tabButtons[name] then return end
    if currentTab == name and leftBody:FindFirstChild("PageContentReady") then return end
    closePopup(true)
    capturingKeybind = nil
    keybindAnimationSerial = keybindAnimationSerial + 1
    sliderDrag = nil
    updaters = table.clone(permanentUpdaters)
    visibleCheckmarks = {}
    visibleSliders = {}
    configStatusLabel = nil
    configProfileInput = nil
    -- Each subtab owns all three content panes. Clear and remount in place;
    -- the pane frames, bevels, heading fonts, and sidebar never get replaced.
    local bodies = {leftBody, topBody, bottomBody}
    for bodyIndex=1,#bodies do
        local body=bodies[bodyIndex]
        local children=body:GetChildren()
        for childIndex=1,#children do children[childIndex]:Destroy() end
        body.CanvasPosition = Vector2.new(0, 0)
        body.CanvasSize = UDim2.fromOffset(0, body.Size.Y.Offset)
    end
    currentTab = name
    for tabName, item in pairs(tabButtons) do
        local selected = tabName == name
        animate(item.text, {TextColor3 = selected and C.accent or C.text}, TWEEN_DURATION)
        animate(item.icon, {ImageColor3 = selected and C.accent or INACTIVE_ICON_COLOR}, TWEEN_DURATION)
        animate(item.halo, {
            ImageColor3 = selected and C.accent or INACTIVE_ICON_COLOR,
            ImageTransparency = selected and 0.79 or 0.96,
        }, TWEEN_DURATION)
        if item.iconShadow then
            animate(item.iconShadow, {
                Color = selected and C.accent or INACTIVE_ICON_COLOR,
                Transparency = selected and 0.57 or 0.95,
            }, TWEEN_DURATION)
        end
        animate(item.button, {
            BackgroundTransparency = selected and 0 or 1,
            BackgroundColor3 = Color3.fromRGB(26, 26, 26),
        }, TWEEN_DURATION)
        local stripes = item.shadow
        for i = 1, #stripes do stripes[i].Visible = selected end
    end
    local tab = library.tabs[name]
    if tab then
        local leftName, topName, bottomName = "left", "top", "bottom"
        for i=1,#tab.Sections do
            local section=tab.Sections[i]
            if section.Body == leftBody then leftName=section.Name
            elseif section.Body == topBody then topName=section.Name
            elseif section.Body == bottomBody then bottomName=section.Name end
        end
        leftHeading.Text = leftName
        topHeading.Text = topName
        bottomHeading.Text = bottomName
        tab:Mount()
        if name == "ESP" then
            overlayUI.MountPreview()
        else
            overlayUI.HidePreview()
        end
        for i=1,#tab.Sections do
            local section=tab.Sections[i]
            if section.Body and section.Body:IsA("ScrollingFrame") then
                local body=section.Body
                local desired = math.max(body.Size.Y.Offset, (section.YCursor or 20) + 22)
                if desired > body.CanvasSize.Y.Offset then
                    body.CanvasSize=UDim2.fromOffset(0, desired)
                end
            end
        end
    end
    for index,body in ipairs(bodies) do
        local origin=tabBodyPositions[body]
        body.Position=origin+UDim2.fromOffset(10,0)
        animate(body,{Position=origin},.22+index*.025,Enum.EasingStyle.Quart)
        local transition=rect(body,0,0,body.Size.X.Offset,body.Size.Y.Offset,C.pane,28)
        transition.Name="PageTransition"
        animate(transition,{BackgroundTransparency=1},.2+index*.025)
        task.delay(.3+index*.025,function() if transition.Parent then transition:Destroy() end end)
    end
    create("Folder", {Parent = leftBody, Name = "PageContentReady"})
    refreshAccent(true)
end

for tabName, item in pairs(tabButtons) do
    item.button.MouseButton1Click:Connect(function()
        renderTab(tabName)
    end)
end
renderTab("Main")
overlayUI.ShowKeyGate()

-- Load the last selected profile on startup (when autoload was enabled).
-- Restore metadata before allowing autosave to prevent startup defaults from
-- overwriting an existing saved profile.
task.spawn(function()
    if not hasFiles and not configRemote then
        configRemote = ReplicatedStorage:WaitForChild("VioletLOLConfigRPC", 3)
        if configRemote and configRemote:IsA("RemoteFunction") then
            backendName = "Roblox DataStore"
        end
    end
    local ok, meta = requestStore("readMeta")
    if ok and type(meta) == "table" then
        if type(meta.selected) == "string" then
            selectedProfile = cleanProfile(meta.selected)
            if configProfileInput and configProfileInput.Parent then
                configProfileInput.Text = selectedProfile
            end
        end
        if type(meta.autoload) == "boolean" then
            setSetting("config.autoload", meta.autoload)
        end
        if type(meta.autosave) == "boolean" then
            setSetting("config.autosave", meta.autosave)
        end
    end
    if state["config.autoload"] == true then
        -- A missing profile is normal on first launch.
        local loaded = loadProfile(selectedProfile, true)
        if loaded then configStatus("autoloaded: " .. selectedProfile) end
    end
    metadataBooting = false
end)

-- Centralized keybind router: each keybind belongs to its toggle and
-- supports Toggle, Hold or Always. Capture shows the original [.  ] animation.
if not options.Integration then
    local circle=create("Frame",{Parent=gui,Name="FOVCircle",AnchorPoint=Vector2.new(.5,.5),
        Size=UDim2.fromOffset(400,400),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,
        BorderSizePixel=0,Visible=false,ZIndex=0})
    create("UICorner",{Parent=circle,CornerRadius=UDim.new(1,0)})
    local stroke=create("UIStroke",{Parent=circle,Color=Color3.new(1,1,1),Thickness=1.5,Transparency=.2})
    local gradient=create("UIGradient",{Parent=stroke})
    local fillGradient=create("UIGradient",{Parent=circle})
    local glow=nativeIconGlow(circle,true)
    local angle=0
    connect(RunService.RenderStepped,function(dt)
        circle.Visible=unlocked and state.use_fov==true
        if not circle.Visible then return end
        local radius=math.clamp(state.fov_radius or 200,50,500)
        local view=workspace.CurrentCamera.ViewportSize
        local pointer=UserInputService.TouchEnabled and view/2 or UserInputService:GetMouseLocation()
        circle.Position=UDim2.fromOffset(pointer.X,pointer.Y)
        circle.Size=UDim2.fromOffset(radius*2,radius*2)
        local alpha=math.clamp(state.fov_transparency or .5,0,1)
        circle.BackgroundTransparency=state.fov_fill and .8+alpha*.2 or 1
        stroke.Transparency=alpha
        local colors=ColorSequence.new(state.fov_gradient_left or C.accent,state.fov_gradient_right or C.accent)
        gradient.Color=colors; fillGradient.Color=colors
        if state.fov_rotate then angle=(angle+dt*45*(state.grad_speed or 1.5))%360 end
        gradient.Rotation=angle; fillGradient.Rotation=angle
        if glow then glow.Color=state.fov_gradient_right or C.accent; glow.Transparency=state.fov_glow and .75 or 1 end
    end)
end
local heldBinds={}
local function inputName(input)
    if input.UserInputType==Enum.UserInputType.Keyboard then return input.KeyCode.Name end
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseButton2
        or input.UserInputType==Enum.UserInputType.MouseButton3 then return input.UserInputType.Name end
end
local function bindBegan(input, processed)
    if not gui.Parent or not unlocked then return end
    local name=inputName(input)
    if not name then return end
    if capturingKeybind then
        local spec = capturingKeybind
        capturingKeybind = nil
        keybindAnimationSerial = keybindAnimationSerial + 1
        if name=="Backspace" or name=="Delete" then spec:Set("None")
        elseif name ~= "Escape" and name~="Unknown" then
            spec:Set(name)
            if spec.Changed then pcall(spec.Changed, input.KeyCode, spec) end
        end
        if spec.Instance and spec.Instance.Parent then
            spec.Instance.Text = displayKey(spec:Get())
            spec.Instance.TextColor3 = C.text
        end
        return
    end
    if processed or UserInputService:GetFocusedTextBox() then return end
    if name == windowApi.MenuKey.Name then
        overlayUI.ToggleMenu()
        return
    end
    for i = 1, #library.keybinds do
        local spec = library.keybinds[i]
        if name == tostring(spec:Get()) and not heldBinds[spec] then
            heldBinds[spec]=true
            local target = spec.ParentToggle
            if target and spec.ToggleTarget ~= false then
                if spec.Mode == "Hold" then target:Set(true)
                elseif spec.Mode == "Always" then target:Set(true)
                else target:Set(not target:Get()) end
            end
            if spec.Callback then pcall(spec.Callback, true, spec) end
        end
    end
end
local function bindEnded(input)
    if not gui.Parent then return end
    for i = 1, #library.keybinds do
        local spec = library.keybinds[i]
        if heldBinds[spec] and inputName(input)==tostring(spec:Get()) then
            heldBinds[spec]=nil
            if spec.Mode=="Hold" then
                if spec.ParentToggle and spec.ToggleTarget ~= false then spec.ParentToggle:Set(false) end
                if spec.Callback then pcall(spec.Callback, false, spec) end
            end
        end
    end
end
connect(UserInputService.InputBegan,bindBegan)
connect(UserInputService.InputEnded,bindEnded)
connect(UserInputService.WindowFocusReleased,function()
    for spec in pairs(heldBinds) do
        if spec.Mode=="Hold" and spec.ParentToggle then spec.ParentToggle:Set(false) end
    end
    table.clear(heldBinds)
end)

-- Values are exposed through control handles, library.flags, GUI attributes,
-- and the SettingChanged BindableEvent. Widgets/layout remain V20-equivalent.
function windowApi:ShowTab(name) currentTab=nil; renderTab(name) end
function windowApi:Refresh()
    currentTab = nil
    renderTab("Main")
end
function windowApi:SetValue(k,v) setSetting(k,v) end
function windowApi:Notify(data) overlayUI.Notify({text=data.Text or data.text or data.Title,type=string.lower(data.Type or "info")}) end
function windowApi:SetAccent(color) setSetting("theme.accent",color); refreshAccent(true) end
function windowApi:SetHeaderGradientLeft(color) setSetting("theme.header_left",color) end
function windowApi:SetHeaderGradientRight(color) setSetting("theme.header_right",color) end
function windowApi:SetMenuKey(key) self.MenuKey=key end
function windowApi:SetKeybindListVisible(value) setSetting("keybinds.enabled",value) end
function windowApi:SetNotificationsVisible(value) setSetting("notifications.enabled",value) end
windowApi.Scale = gui:FindFirstChildWhichIsA("UIScale",true) or {Scale=1}
windowApi.HeaderGradientLeft=HEADER_GRADIENT_LEFT_DEFAULT
windowApi.HeaderGradientRight=HEADER_GRADIENT_RIGHT_DEFAULT
return windowApi
end


return library

end
-- Compatibility adapter: retain original feature callbacks and config serialization.
local v23 = makeV23()
local originalUnload = library.Unload
function library:Window(options)
    options = table.clone(options or {})
    options.SharedFlags=self.flags
    options.Integration=true
    options.KeySystem=false
    options.GuiName='VioletOperationOneV23'
    local w=v23:Window(options)
    self.gui=v23.gui
    self.options=v23.options
    self._v23window=w
    local nativeTab=w.Tab
    local sectionCache={}
    local map={Combat='Main',Visuals='ESP',Misc='Misc',Settings='Config'}
    local function wrapSection(section)
        local proxy={}
        local function add(kind,data)
            data=table.clone(data or {})
            if data.Values and not data.Options then data.Options=data.Values end
            local c=section[kind](section,data)
            local settings=c.Settings
            function c:Settings() return wrapSection(settings(self)) end
            c.SetValue=c.Set
            if data.Keybind then c:Keybind(data.Keybind) end
            if data.Colorpicker then c:Settings():Colorpicker(data.Colorpicker) end
            for _,cp in ipairs(data.Colorpickers or {}) do c:Settings():Colorpicker(cp) end
            return c
        end
        for _,kind in ipairs({'Toggle','Slider','Dropdown','Colorpicker','Keybind','Textbox','Button','Label'}) do
            proxy[kind]=function(_,data) return add(kind,data) end
            proxy[string.lower(kind)]=proxy[kind]
        end
        proxy.Checkbox=proxy.Toggle
        function proxy:ButtonRow(data) for _,b in ipairs(data.Buttons or {}) do self:Button(b) end end
        function proxy:Separator() return self:Label({Name=' '}) end
        return proxy
    end
    local function wrapTab(target,sub)
        local p={}
        function p:Section(data)
            local dest=target
            if data.Name=='Weapon Mods' then dest='Main' end
            if data.Name=='FOV Circle' then dest='Main' end
            data=table.clone(data)
            if data.Side=='Right' then data.Side='Top' end
            if dest=='Misc' and (data.Name=='Drone' or data.Name=='Drone Movement' or data.Name=='Sprint Behavior' or data.Name=='Movement') then data.Name='Movement'; data.Side='Top' end
            if dest=='Main' and (data.Name=='Weapon Mods' or data.Name=='Melee' or data.Name=='Weapon Behavior') then data.Name='Weapon Behavior'; data.Side='Top' end
            local key=dest..'/'..data.Name..'/'..(data.Side or 'Left')
            local section=sectionCache[key]
            if not section then section=v23.tabs[dest]:Section(data); sectionCache[key]=section end
            return wrapSection(section)
        end
        function p:SubTab(data) return wrapTab(({Gadget='Gadgets',Grenade='Gadgets',World='World',['Local Player']='Local Player'})[data.Name] or target,data.Name) end
        p.DefaultSubTab=p
        return p
    end
    function w:Tab(data) return wrapTab(map[data.Name] or data.Name) end
    function w:RegisterAccent(callback) callback(library.accent) self._accentCallback=callback end
    local setAccent=w.SetAccent
    function w:SetAccent(color) setAccent(self,color) if self._accentCallback then self._accentCallback(color) end end
    return w
end
function library:SetAccent(color) self.accent=color if self._v23window then self._v23window:SetAccent(color) end end
function library:Notify(data) if self._v23window then self._v23window:Notify(data) end end
function library:Unload()
    if self.Extras then self.Extras:Unload() end
    if self.SnaplinesV27 then self.SnaplinesV27:Unload() end
    if self.AppearanceV26 then self.AppearanceV26:Unload() end
    if self.MechanicsV25 then self.MechanicsV25:Unload() end
    if self.CombatV24 then self.CombatV24:Unload() end
    if self.ActionsV24 then self.ActionsV24:Unload() end
    v23:Unload()
    originalUnload(self)
end

return library, {
finishStartup=finishStartup,
Players=Players,
UserInputService=UserInputService,
RunService=RunService,
ReplicatedStorage=ReplicatedStorage,
Workspace=Workspace,
HttpService=HttpService,
CoreGui=CoreGui,
gethui=gethui,
LocalPlayer=LocalPlayer,
sanitizeConfigName=sanitizeConfigName,
v23=v23,
}
