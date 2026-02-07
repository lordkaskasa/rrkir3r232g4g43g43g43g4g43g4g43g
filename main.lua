
--[[
    lemon.lua UI Library
    Custom UI framework with cloneref + CoreGui protection
    Replaces ImGui for lemon.lua cheat menu
    
    API:
        local Library = loadstring(...)()
        local Window = Library:CreateWindow({ Title, Size, ToggleKey })
        local Tab = Window:CreateTab("TAB_NAME")
        local Section = Tab:CreateSection("SECTION_TITLE")
        Section:Checkbox({ Label, Value, Callback })
        Section:Slider({ Label, Value, MinValue, MaxValue, Callback })
        Section:Combo({ Label, Selected, Items, Callback })
        Section:InputText({ Label, PlaceHolder, Value })
        Section:Button({ Text, Callback })
        Section:Keybind({ Label, Value, IgnoreGameProcessed, Callback })
        Window:SetVisible(bool)
        Window:Close()
        Window:Destroy()
]]

local Library = {}

-- ═══════════════════════════════════════════════════
-- PROTECTION & SERVICES
-- ═══════════════════════════════════════════════════
local CloneRef = cloneref or function(x) return x end
local Players = CloneRef(game:GetService("Players"))
local TweenService = CloneRef(game:GetService("TweenService"))
local UserInputService = CloneRef(game:GetService("UserInputService"))
local RunService = CloneRef(game:GetService("RunService"))
local CoreGui = CloneRef(game:GetService("CoreGui"))

local LocalPlayer = Players.LocalPlayer
local isStudio = RunService:IsStudio()
local guiParent = isStudio and LocalPlayer.PlayerGui or CoreGui

-- ═══════════════════════════════════════════════════
-- THEME
-- ═══════════════════════════════════════════════════
local Theme = {
	Accent      = Color3.fromRGB(112, 146, 190),
	AccentDark  = Color3.fromRGB(80, 110, 150),
	AccentHover = Color3.fromRGB(130, 162, 200),
	BgDark      = Color3.fromRGB(13, 13, 15),
	BgMain      = Color3.fromRGB(20, 20, 22),
	BgChild     = Color3.fromRGB(24, 24, 26),
	BgHeader    = Color3.fromRGB(28, 28, 30),
	BgInput     = Color3.fromRGB(16, 16, 18),
	Border      = Color3.fromRGB(40, 52, 68),
	Text        = Color3.fromRGB(255, 255, 255),
	TextDim     = Color3.fromRGB(102, 102, 102),
	TextMid     = Color3.fromRGB(170, 170, 170),
	Green       = Color3.fromRGB(100, 255, 100),
	Red         = Color3.fromRGB(255, 100, 100),
}

-- ═══════════════════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════════════════
local function create(cls, parent, props)
	local inst = Instance.new(cls)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function tw(obj, props, dur, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- ═══════════════════════════════════════════════════
-- LIBRARY : CreateWindow
-- ═══════════════════════════════════════════════════
function Library:CreateWindow(config)
	config = config or {}
	local title     = config.Title or "lemon.lua"
	local size      = config.Size or UDim2.fromOffset(690, 470)
	local toggleKey = config.ToggleKey or Enum.KeyCode.Insert

	local Window = {}
	local tabs = {}
	local currentTabIndex = 0
	local visible = true
	local connections = {}
	local activeSlider = nil -- for global slider tracking

	-- ── ScreenGui ──
	local screenGui = create("ScreenGui", guiParent, {
		Name = "LemonUI_" .. math.random(100000, 999999),
		DisplayOrder = 99998,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- ── Main Window Frame ──
	local windowFrame = create("Frame", screenGui, {
		Name = "Window",
		Size = size,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.BgMain,
		BorderSizePixel = 0,
	})
	create("UICorner", windowFrame, { CornerRadius = UDim.new(0, 6) })
	create("UIStroke", windowFrame, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.5,
	})

	-- ── Left Sidebar ──
	local sidebar = create("Frame", windowFrame, {
		Name = "Sidebar",
		Size = UDim2.new(0, 128, 1, 0),
		BackgroundColor3 = Theme.BgDark,
		BorderSizePixel = 0,
	})
	create("UICorner", sidebar, { CornerRadius = UDim.new(0, 6) })
	create("Frame", sidebar, { -- mask right corners
		Size = UDim2.new(0, 10, 1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		BackgroundColor3 = Theme.BgDark,
		BorderSizePixel = 0,
	})

	-- Accent bar
	create("Frame", sidebar, {
		Size = UDim2.new(0, 3, 0, 20),
		Position = UDim2.new(0, 12, 0, 12),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	})

	-- Title
	create("TextLabel", sidebar, {
		Size = UDim2.new(1, -30, 0, 44),
		Position = UDim2.new(0, 22, 0, 0),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Theme.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Divider
	create("Frame", sidebar, {
		Size = UDim2.new(1, -20, 0, 1),
		Position = UDim2.new(0, 10, 0, 44),
		BackgroundColor3 = Theme.Border,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	})

	-- Tab button area in sidebar
	local tabContainer = create("Frame", sidebar, {
		Name = "Tabs",
		Size = UDim2.new(1, -16, 1, -56),
		Position = UDim2.new(0, 8, 0, 52),
		BackgroundTransparency = 1,
	})
	create("UIListLayout", tabContainer, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	})

	-- ── Bottom Bar ──
	local bottomBar = create("Frame", windowFrame, {
		Name = "BottomBar",
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 1, -32),
		BackgroundColor3 = Theme.BgDark,
		BorderSizePixel = 0,
	})
	create("UICorner", bottomBar, { CornerRadius = UDim.new(0, 6) })
	create("Frame", bottomBar, { -- mask top corners
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Theme.BgDark,
		BorderSizePixel = 0,
	})
	create("TextLabel", bottomBar, {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		Text = title .. "  |  press INSERT to toggle",
		TextColor3 = Theme.TextDim,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- ── Content Area ──
	local contentArea = create("ScrollingFrame", windowFrame, {
		Name = "Content",
		Size = UDim2.new(1, -138, 1, -42),
		Position = UDim2.new(0, 133, 0, 5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent,
		ScrollBarImageTransparency = 0.5,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	create("UIListLayout", contentArea, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	create("UIPadding", contentArea, {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 8),
	})

	-- ── Dropdown Overlay (for Combo popups) ──
	local dropdownOverlay = create("Frame", screenGui, {
		Name = "DropdownOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 100,
	})
	local activeDropdown = nil

	local function closeDropdown()
		if activeDropdown then
			activeDropdown:Destroy()
			activeDropdown = nil
			dropdownOverlay.Visible = false
		end
	end

	-- clicking empty area closes dropdown
	create("TextButton", dropdownOverlay, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 100,
	}).MouseButton1Click:Connect(closeDropdown)

	-- ════════════════════════════
	-- TAB SWITCHING
	-- ════════════════════════════
	local function showTab(index)
		for i, tab in ipairs(tabs) do
			local active = (i == index)
			tab.contentFrame.Visible = active
			if tab.button then
				tw(tab.button, {
					BackgroundTransparency = active and 0.85 or 1,
				}, 0.15)
				tw(tab.indicator, {
					BackgroundTransparency = active and 0 or 1,
				}, 0.15)
				tw(tab.label, {
					TextColor3 = active and Theme.Text or Theme.TextDim,
				}, 0.15)
			end
		end
		currentTabIndex = index
		contentArea.CanvasPosition = Vector2.new(0, 0)
	end

	-- ════════════════════════════
	-- WINDOW DRAGGING
	-- ════════════════════════════
	local dragging, dragStart, startPos

	sidebar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = windowFrame.Position
		end
	end)

	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if dragging then
				local delta = input.Position - dragStart
				windowFrame.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
			-- global slider drag
			if activeSlider then
				activeSlider(input)
			end
		end
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			activeSlider = nil
		end
	end))

	-- ════════════════════════════
	-- TOGGLE KEY
	-- ════════════════════════════
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == toggleKey then
			visible = not visible
			windowFrame.Visible = visible
		end
	end))

	-- ════════════════════════════════════════════════
	-- Window:CreateTab
	-- ════════════════════════════════════════════════
	function Window:CreateTab(name)
		local Tab = {}
		local tabIndex = #tabs + 1

		-- Sidebar button
		local btn = create("TextButton", tabContainer, {
			Name = "Tab_" .. name,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = tabIndex,
		})
		create("UICorner", btn, { CornerRadius = UDim.new(0, 4) })

		-- Active indicator bar
		local indicator = create("Frame", btn, {
			Size = UDim2.new(0, 3, 0, 16),
			Position = UDim2.new(0, 2, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
		create("UICorner", indicator, { CornerRadius = UDim.new(0, 2) })

		local tabLabel = create("TextLabel", btn, {
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = Theme.TextDim,
			TextSize = 12,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		-- Content frame for this tab
		local contentFrame = create("Frame", contentArea, {
			Name = "Tab_" .. name,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = (tabIndex == 1),
			LayoutOrder = tabIndex,
		})
		create("UIListLayout", contentFrame, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})

		local tabData = {
			button = btn,
			indicator = indicator,
			label = tabLabel,
			contentFrame = contentFrame,
		}
		tabs[tabIndex] = tabData

		-- Hover
		btn.MouseEnter:Connect(function()
			if currentTabIndex ~= tabIndex then
				tw(btn, { BackgroundTransparency = 0.9 }, 0.1)
			end
		end)
		btn.MouseLeave:Connect(function()
			if currentTabIndex ~= tabIndex then
				tw(btn, { BackgroundTransparency = 1 }, 0.1)
			end
		end)
		btn.MouseButton1Click:Connect(function()
			closeDropdown()
			showTab(tabIndex)
		end)

		if tabIndex == 1 then
			showTab(1)
		end

		-- ════════════════════════════════════════════════
		-- Tab:CreateSection
		-- ════════════════════════════════════════════════
		function Tab:CreateSection(sectionTitle)
			local Section = {}
			local elementOrder = 0

			local sectionFrame = create("Frame", contentFrame, {
				Name = "Section_" .. sectionTitle,
				Size = UDim2.new(1, -4, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.BgChild,
				BorderSizePixel = 0,
				LayoutOrder = #contentFrame:GetChildren(),
			})
			create("UICorner", sectionFrame, { CornerRadius = UDim.new(0, 4) })
			create("UIStroke", sectionFrame, {
				Color = Theme.Border,
				Thickness = 1,
				Transparency = 0.7,
			})

			-- Header
			local header = create("Frame", sectionFrame, {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Theme.BgHeader,
				BorderSizePixel = 0,
			})
			create("UICorner", header, { CornerRadius = UDim.new(0, 4) })
			create("Frame", header, { -- mask bottom corners
				Size = UDim2.new(1, 0, 0, 8),
				Position = UDim2.new(0, 0, 1, -8),
				BackgroundColor3 = Theme.BgHeader,
				BorderSizePixel = 0,
			})
			create("Frame", header, { -- accent bar
				Size = UDim2.new(0, 3, 0, 14),
				Position = UDim2.new(0, 8, 0.5, -7),
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
			})
			create("TextLabel", header, {
				Size = UDim2.new(1, -24, 1, 0),
				Position = UDim2.new(0, 18, 0, 0),
				BackgroundTransparency = 1,
				Text = sectionTitle,
				TextColor3 = Theme.Text,
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			-- Body
			local body = create("Frame", sectionFrame, {
				Name = "Body",
				Size = UDim2.new(1, -16, 0, 0),
				Position = UDim2.new(0, 8, 0, 32),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			})
			create("UIListLayout", body, {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			})
			create("UIPadding", body, { PaddingBottom = UDim.new(0, 8) })

			local function nextOrder()
				elementOrder = elementOrder + 1
				return elementOrder
			end

			-- ════════════════════════
			-- CHECKBOX
			-- ════════════════════════
			function Section:Checkbox(cfg)
				local value = cfg.Value or false
				local cb = cfg.Callback
				local el = { Value = value }

				local row = create("TextButton", body, {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					LayoutOrder = nextOrder(),
				})

				local box = create("Frame", row, {
					Size = UDim2.fromOffset(14, 14),
					Position = UDim2.new(0, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = value and Theme.Accent or Theme.BgInput,
					BorderSizePixel = 0,
				})
				create("UICorner", box, { CornerRadius = UDim.new(0, 3) })
				create("UIStroke", box, { Color = Theme.Border, Thickness = 1, Transparency = 0.5 })

				local check = create("TextLabel", box, {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "\xE2\x9C\x93",
					TextColor3 = Theme.Text,
					TextSize = 10,
					Font = Enum.Font.GothamBold,
					TextTransparency = value and 0 or 1,
				})

				local lbl = create("TextLabel", row, {
					Size = UDim2.new(1, -22, 1, 0),
					Position = UDim2.new(0, 22, 0, 0),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 12,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				row.MouseEnter:Connect(function()
					tw(lbl, { TextColor3 = Theme.Text }, 0.1)
				end)
				row.MouseLeave:Connect(function()
					tw(lbl, { TextColor3 = Theme.TextMid }, 0.1)
				end)

				row.MouseButton1Click:Connect(function()
					value = not value
					el.Value = value
					tw(box, { BackgroundColor3 = value and Theme.Accent or Theme.BgInput }, 0.15)
					tw(check, { TextTransparency = value and 0 or 1 }, 0.15)
					if cb then cb(el, value) end
				end)

				function el:SetValue(v)
					value = v
					el.Value = v
					box.BackgroundColor3 = v and Theme.Accent or Theme.BgInput
					check.TextTransparency = v and 0 or 1
				end

				return el
			end

			-- ════════════════════════
			-- SLIDER
			-- ════════════════════════
			function Section:Slider(cfg)
				local value = cfg.Value or 0
				local min = cfg.MinValue or cfg.Min or 0
				local max = cfg.MaxValue or cfg.Max or 100
				local cb = cfg.Callback
				local el = { Value = value }

				local frame = create("Frame", body, {
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				})

				local lbl = create("TextLabel", frame, {
					Size = UDim2.new(0.7, 0, 0, 16),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 12,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local valLabel = create("TextLabel", frame, {
					Size = UDim2.new(0.3, 0, 0, 16),
					Position = UDim2.new(0.7, 0, 0, 0),
					BackgroundTransparency = 1,
					Text = tostring(value),
					TextColor3 = Theme.Accent,
					TextSize = 12,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Right,
				})

				local track = create("TextButton", frame, {
					Size = UDim2.new(1, 0, 0, 6),
					Position = UDim2.new(0, 0, 0, 20),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false,
				})
				create("UICorner", track, { CornerRadius = UDim.new(1, 0) })

				local ratio = math.clamp((value - min) / math.max(max - min, 1), 0, 1)
				local fill = create("Frame", track, {
					Size = UDim2.new(ratio, 0, 1, 0),
					BackgroundColor3 = Theme.Accent,
					BorderSizePixel = 0,
				})
				create("UICorner", fill, { CornerRadius = UDim.new(1, 0) })

				local thumb = create("Frame", track, {
					Size = UDim2.fromOffset(10, 10),
					Position = UDim2.new(ratio, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Theme.Text,
					BorderSizePixel = 0,
					ZIndex = 2,
				})
				create("UICorner", thumb, { CornerRadius = UDim.new(1, 0) })

				local function updateFromInput(input)
					local absX = track.AbsolutePosition.X
					local absW = track.AbsoluteSize.X
					local r = math.clamp((input.Position.X - absX) / absW, 0, 1)
					local newVal = math.floor(min + r * (max - min) + 0.5)
					if newVal ~= value then
						value = newVal
						el.Value = value
						valLabel.Text = tostring(value)
						fill.Size = UDim2.new(r, 0, 1, 0)
						thumb.Position = UDim2.new(r, 0, 0.5, 0)
						if cb then cb(el, value) end
					end
				end

				track.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						activeSlider = updateFromInput
						updateFromInput(input)
					end
				end)

				function el:SetValue(v)
					value = math.clamp(v, min, max)
					el.Value = value
					local r = (value - min) / math.max(max - min, 1)
					valLabel.Text = tostring(value)
					fill.Size = UDim2.new(r, 0, 1, 0)
					thumb.Position = UDim2.new(r, 0, 0.5, 0)
				end

				return el
			end

			-- ════════════════════════
			-- COMBO
			-- ════════════════════════
			function Section:Combo(cfg)
				local selected = cfg.Selected or cfg.Value or ""
				local items = cfg.Items or cfg.Options or {}
				local cb = cfg.Callback
				local internal = { items = items }

				local frame = create("Frame", body, {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				})

				create("TextLabel", frame, {
					Size = UDim2.new(0.5, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 12,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local btnFrame = create("Frame", frame, {
					Size = UDim2.new(0.5, 0, 1, 0),
					Position = UDim2.new(0.5, 0, 0, 0),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
				})
				create("UICorner", btnFrame, { CornerRadius = UDim.new(0, 3) })
				create("UIStroke", btnFrame, { Color = Theme.Border, Thickness = 1, Transparency = 0.7 })

				local selBtn = create("TextButton", btnFrame, {
					Size = UDim2.new(1, -12, 1, 0),
					Position = UDim2.new(0, 6, 0, 0),
					BackgroundTransparency = 1,
					Text = selected .. "  \xE2\x96\xBC",
					TextColor3 = Theme.TextMid,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					AutoButtonColor = false,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})

				local function openDropdown()
					closeDropdown()

					local absPos = btnFrame.AbsolutePosition
					local absSize = btnFrame.AbsoluteSize
					local maxH = math.min(#internal.items * 22 + 4, 180)

					local dd = create("Frame", dropdownOverlay, {
						Size = UDim2.fromOffset(absSize.X, maxH),
						Position = UDim2.fromOffset(absPos.X, absPos.Y + absSize.Y + 2),
						BackgroundColor3 = Theme.BgChild,
						BorderSizePixel = 0,
						ZIndex = 101,
					})
					create("UICorner", dd, { CornerRadius = UDim.new(0, 4) })
					create("UIStroke", dd, { Color = Theme.Border, Thickness = 1, Transparency = 0.5 })

					local scroll = create("ScrollingFrame", dd, {
						Size = UDim2.new(1, -4, 1, -4),
						Position = UDim2.fromOffset(2, 2),
						BackgroundTransparency = 1,
						ScrollBarThickness = 2,
						ScrollBarImageColor3 = Theme.Accent,
						BorderSizePixel = 0,
						CanvasSize = UDim2.fromOffset(0, #internal.items * 22),
						ZIndex = 102,
					})
					create("UIListLayout", scroll, {
						SortOrder = Enum.SortOrder.LayoutOrder,
					})

					for idx, item in ipairs(internal.items) do
						local isActive = (item == selected)
						local opt = create("TextButton", scroll, {
							Size = UDim2.new(1, 0, 0, 22),
							BackgroundColor3 = Theme.Accent,
							BackgroundTransparency = isActive and 0.7 or 1,
							Text = "",
							AutoButtonColor = false,
							LayoutOrder = idx,
							ZIndex = 103,
						})

						local optLabel = create("TextLabel", opt, {
							Size = UDim2.new(1, -16, 1, 0),
							Position = UDim2.new(0, 8, 0, 0),
							BackgroundTransparency = 1,
							Text = item,
							TextColor3 = isActive and Theme.Text or Theme.TextMid,
							TextSize = 11,
							Font = Enum.Font.Gotham,
							TextXAlignment = Enum.TextXAlignment.Left,
							ZIndex = 103,
						})

						opt.MouseEnter:Connect(function()
							if item ~= selected then
								tw(opt, { BackgroundTransparency = 0.85 }, 0.08)
							end
						end)
						opt.MouseLeave:Connect(function()
							if item ~= selected then
								tw(opt, { BackgroundTransparency = 1 }, 0.08)
							end
						end)
						opt.MouseButton1Click:Connect(function()
							selected = item
							rawset(el, "Value", selected)
							selBtn.Text = selected .. "  \xE2\x96\xBC"
							if cb then cb(el, selected) end
							closeDropdown()
						end)
					end

					activeDropdown = dd
					dropdownOverlay.Visible = true
				end

				selBtn.MouseButton1Click:Connect(openDropdown)

				-- use proxy for settable Items property
				local el = setmetatable({}, {
					__newindex = function(t, k, v)
						if k == "Items" then
							internal.items = v
							local found = false
							for _, item in ipairs(v) do
								if item == selected then found = true; break end
							end
							if not found and #v > 0 then
								selected = v[1]
								rawset(t, "Value", selected)
								selBtn.Text = selected .. "  \xE2\x96\xBC"
							end
						else
							rawset(t, k, v)
						end
					end,
					__index = function(t, k)
						if k == "Items" then return internal.items end
						return rawget(t, k)
					end,
				})

				el.Value = selected

				function el:SetItems(newItems)
					internal.items = newItems
				end

				return el
			end

			-- ════════════════════════
			-- INPUT TEXT
			-- ════════════════════════
			function Section:InputText(cfg)
				local value = cfg.Value or ""
				local cb = cfg.Callback
				local el = {}

				local frame = create("Frame", body, {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				})

				create("TextLabel", frame, {
					Size = UDim2.new(0.4, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 12,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local inputBox = create("TextBox", frame, {
					Size = UDim2.new(0.6, 0, 1, 0),
					Position = UDim2.new(0.4, 0, 0, 0),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
					Text = value,
					PlaceholderText = cfg.PlaceHolder or cfg.Placeholder or "",
					PlaceholderColor3 = Color3.fromRGB(55, 55, 60),
					TextColor3 = Theme.Text,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					ClearTextOnFocus = false,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				create("UICorner", inputBox, { CornerRadius = UDim.new(0, 3) })
				create("UIPadding", inputBox, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
				local iStroke = create("UIStroke", inputBox, { Color = Theme.Border, Thickness = 1, Transparency = 0.7 })

				inputBox.Focused:Connect(function()
					tw(iStroke, { Color = Theme.Accent, Transparency = 0.3 }, 0.15)
				end)
				inputBox.FocusLost:Connect(function()
					value = inputBox.Text
					tw(iStroke, { Color = Theme.Border, Transparency = 0.7 }, 0.15)
					if cb then cb(el, value) end
				end)

				function el:GetValue()
					return inputBox.Text
				end
				function el:SetValue(v)
					inputBox.Text = v
					value = v
				end

				return el
			end

			-- ════════════════════════
			-- BUTTON
			-- ════════════════════════
			function Section:Button(cfg)
				local cb = cfg.Callback
				local el = {}

				local btn = create("TextButton", body, {
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
					Text = cfg.Text or "button",
					TextColor3 = Theme.TextMid,
					TextSize = 12,
					Font = Enum.Font.GothamMedium,
					AutoButtonColor = false,
					LayoutOrder = nextOrder(),
				})
				create("UICorner", btn, { CornerRadius = UDim.new(0, 4) })
				create("UIStroke", btn, { Color = Theme.Border, Thickness = 1, Transparency = 0.7 })

				btn.MouseEnter:Connect(function()
					tw(btn, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.7, TextColor3 = Theme.Text }, 0.12)
				end)
				btn.MouseLeave:Connect(function()
					tw(btn, { BackgroundColor3 = Theme.BgInput, BackgroundTransparency = 0, TextColor3 = Theme.TextMid }, 0.12)
				end)
				btn.MouseButton1Click:Connect(function()
					if cb then cb() end
				end)

				return el
			end

			-- ════════════════════════
			-- KEYBIND
			-- ════════════════════════
			function Section:Keybind(cfg)
				local value = cfg.Value or Enum.KeyCode.Unknown
				local cb = cfg.Callback
				local listening = false
				local el = { Value = value }

				local frame = create("Frame", body, {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				})

				create("TextLabel", frame, {
					Size = UDim2.new(1, -65, 1, 0),
					BackgroundTransparency = 1,
					Text = cfg.Label or "",
					TextColor3 = Theme.TextMid,
					TextSize = 12,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})

				local keyBtn = create("TextButton", frame, {
					Size = UDim2.new(0, 58, 0, 18),
					Position = UDim2.new(1, -58, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Theme.BgInput,
					BorderSizePixel = 0,
					Text = value.Name or "None",
					TextColor3 = Theme.TextMid,
					TextSize = 10,
					Font = Enum.Font.GothamMedium,
					AutoButtonColor = false,
				})
				create("UICorner", keyBtn, { CornerRadius = UDim.new(0, 3) })
				create("UIStroke", keyBtn, { Color = Theme.Border, Thickness = 1, Transparency = 0.7 })

				local listenConn
				keyBtn.MouseButton1Click:Connect(function()
					if listening then return end
					listening = true
					keyBtn.Text = "..."
					tw(keyBtn, { BackgroundColor3 = Theme.Accent }, 0.12)

					listenConn = UserInputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.Keyboard then
							if input.KeyCode == Enum.KeyCode.Escape then
								keyBtn.Text = value.Name
							else
								value = input.KeyCode
								el.Value = value
								keyBtn.Text = value.Name
								if cb then cb(el, value) end
							end
							tw(keyBtn, { BackgroundColor3 = Theme.BgInput }, 0.12)
							listening = false
							listenConn:Disconnect()
						end
					end)
				end)

				function el:SetValue(v)
					value = v
					el.Value = v
					keyBtn.Text = v.Name
				end

				return el
			end

			return Section
		end

		return Tab
	end

	-- ════════════════════════════════════════════════
	-- WINDOW METHODS
	-- ════════════════════════════════════════════════
	function Window:SetVisible(v)
		visible = v
		windowFrame.Visible = v
	end

	function Window:Close()
		windowFrame.Visible = false
		visible = false
	end

	function Window:Destroy()
		for _, conn in ipairs(connections) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		screenGui:Destroy()
	end

	function Window:IsVisible()
		return visible
	end

	-- expose for external use
	Window.Window = windowFrame
	Window.ScreenGui = screenGui

	return Window
end

return Library
