--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local variables = require(script.utility.variables)
local image = require(script.utility.image)
local locale = require(script.utility.locale)
local constants = require(script.utility.constants)
local types = require(script.types)

-- re-export public types so consumers can annotate against Library.Window etc
export type Theme = types.Theme
export type Translator = types.Translator
export type Translations = types.Translations
export type WindowConfiguration = types.WindowConfiguration

export type WindowProps = types.WindowProps
export type TabProps = types.TabProps
export type TagProps = types.TagProps
export type SectionProps = types.SectionProps
export type GroupProps = types.GroupProps
export type ButtonProps = types.ButtonProps
export type ToggleProps = types.ToggleProps
export type SliderProps = types.SliderProps
export type DropdownProps = types.DropdownProps
export type InputProps = types.InputProps
export type KeybindProps = types.KeybindProps
export type ColorPickerProps = types.ColorPickerProps
export type StatProps = types.StatProps
export type ProgressProps = types.ProgressProps
export type ConsoleProps = types.ConsoleProps
export type TextProps = types.TextProps
export type DividerProps = types.DividerProps
export type NotifyProps = types.NotifyProps
export type ToastProps = types.ToastProps
export type PopupBox = types.PopupBox
export type PopupOption = types.PopupOption
export type PopupProps = types.PopupProps

export type Moveable = types.Moveable
export type Lockable = types.Lockable
export type Window = types.Window
export type Tab = types.Tab
export type Group = types.Group
export type Button = types.Button
export type Toggle = types.Toggle
export type Slider = types.Slider
export type Dropdown = types.Dropdown
export type Input = types.Input
export type Keybind = types.Keybind
export type ColorPicker = types.ColorPicker
export type Stat = types.Stat
export type Progress = types.Progress
export type Console = types.Console
export type Section = types.Section
export type TabSection = types.TabSection
export type Text = types.Text
export type Divider = types.Divider
export type Tag = types.Tag
export type Popup = types.Popup
export type Library = types.Library

-- the components are untyped luau, so this is where the window module meets the public contract
type WindowModule = { new: (types.WindowProps) -> types.Window }

local library = {} :: Library

-- Plain, assignable branding overrides. Set these after requiring the module and before
-- CreateWindow; a WindowProps value for the same slot still wins over these.
library.TopbarText = "Menu" -- the collapsed pill's title shown while the window is hidden
library.TopbarIcon = "" -- the collapsed pill's icon (asset id or image uri; "" hides it)
library.LoadingText = "" -- the loading screen's caption ("" hides it)
library.LoadingIcon = "" -- the loading screen's icon (asset id or image uri; "" hides it)

-- The loading screen shown while the window builds. Renders LoadingIcon above LoadingText,
-- centered; whichever is blank is simply left out.
local function createBanner()
    local ui = Instance.new("ScreenGui")
    ui.Name = variables.httpService:GenerateGUID(false)
    ui.ClipToDeviceSafeArea = false
    ui.DisplayOrder = constants.displayOrder.banner
    ui.IgnoreGuiInset = true
    ui.ResetOnSpawn = false
    ui.Enabled = true
    ui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
    ui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ui.Parent = variables.guiContainer

    local container = Instance.new("Frame")
    container.Name = "Banner"
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.fromScale(0.5, 0.5)
    container.AutomaticSize = Enum.AutomaticSize.XY
    container.BackgroundTransparency = 1
    container.Parent = ui

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = container

    local loadingIcon = library.LoadingIcon or ""
    local loadingText = library.LoadingText or ""

    if loadingIcon ~= "" then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.AnchorPoint = Vector2.new(0.5, 0)
        icon.BackgroundTransparency = 1
        icon.Image = image.resolve(loadingIcon)
        icon.Size = UDim2.fromOffset(60, 60)
        icon.LayoutOrder = 1
        icon.Parent = container
    end

    if loadingText ~= "" then
        local caption = Instance.new("TextLabel")
        caption.Name = "Caption"
        caption.AnchorPoint = Vector2.new(0.5, 0)
        caption.BackgroundTransparency = 1
        caption.FontFace = variables.brandFont(Enum.FontWeight.SemiBold)
        caption.Text = loadingText
        caption.TextColor3 = Color3.fromRGB(255, 255, 255)
        caption.TextSize = 18
        caption.LayoutOrder = 2
        caption.Parent = container
    end

    return ui
end

function library:CreateWindow(properties: types.WindowProps): types.Window
    -- the topbar overrides slot in below anything the dev passed per-window
    local merged = if typeof(properties) == "table" then table.clone(properties) else {} :: any
    merged.showName = merged.showName or merged.ShowName or library.TopbarText
    merged.showIcon = merged.showIcon or merged.ShowIcon or library.TopbarIcon
    properties = merged

    local banner = createBanner()

    local window: types.Window? -- forward declared so the settle callback below can reach it
    -- preload can settle before the window is built; hold the notify until it is
    local queuedNotify: (() -> ())?

    if variables.secureMode then
        -- cache icons locally so secureMode doesnt leak asset ids. non-blocking: whats already on
        -- disk applies now, the rest download in the background and rebind once ready. if any never
        -- cache, tell the dev once - on screen only, secure mode stays off the console
        image.preload(function(failed)
            if failed <= 0 then
                return
            end
            local function notify()
                if not window or window.unloaded then
                    return
                end
                window:Notify({
                    title = locale.resolve("Secure mode"),
                    content = if failed == 1
                        then locale.resolve("An asset couldn't be cached and won't appear.")
                        else locale.resolve("Some assets couldn't be cached and won't appear."),
                })
            end
            if window then
                notify()
            else
                queuedNotify = notify
            end
        end)
    end

    -- the banner is only torn down once the window is up, so a throw in here (bad props) would
    -- otherwise strand it in the gui container for the rest of the session
    local made, result = pcall(function()
        return (require(script.components.window) :: WindowModule).new(properties)
    end)
    if not made then
        banner:Destroy()
        error(result, 0)
    end

    local built = result :: types.Window
    window = built

    if queuedNotify then
        task.spawn(queuedNotify)
        queuedNotify = nil
    end

    if variables.secureMode then
        -- secure mode renders the fallback up front (variables.brandFont), then downloads the real
        -- brand faces off the main thread and swaps them in once ready, so startup never blocks
        task.spawn(function()
            local body = variables.fontManager:loadFont(constants.fontAsset, Enum.FontWeight.Medium)
            local title = variables.fontManager:loadFont(constants.fontAsset, Enum.FontWeight.SemiBold)
            -- the download can outlast the window; dont swap into one thats been unloaded
            if
                not built.unloaded
                and body
                and title
                and body ~= variables.fallbackFont
                and title ~= variables.fallbackFont
            then
                built:ChangeTheme({ Font = body, TitleFont = title })
            end
        end)
    end

    task.spawn(function()
        task.wait(0.5)

        banner:Destroy()

        task.wait(0.5)
        -- the window can be unloaded inside this delay; showing it then would fire
        -- saved-config callbacks and build toasts on destroyed instances
        if not built.unloaded then
            built:Show()
        end
    end)

    return built
end

return library
