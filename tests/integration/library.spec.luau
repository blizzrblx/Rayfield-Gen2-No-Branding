local helpers = (_G :: any).__LIBRARY_TEST_HELPERS

return function()
    local Library = helpers.requireLibrary()
    local image = helpers.requireUtility("image")
    local variables = helpers.requireUtility("variables")

    describe("Library init and themes", function()
        local originalSecureMode
        local originalPreload
        local originalLoadFont
        local window

        beforeEach(function()
            originalSecureMode = variables.secureMode
            originalPreload = image.preload
            originalLoadFont = variables.fontManager.loadFont
        end)

        afterEach(function()
            if window and not window.unloaded then
                window:Unload()
            end
            window = nil
            variables.secureMode = originalSecureMode
            image.preload = originalPreload
            variables.fontManager.loadFont = originalLoadFont
        end)

        it("requires every built-in theme", function()
            for _, name in { "default", "amethyst", "cobalt", "ember", "frost", "rose" } do
                local theme = helpers.requireTheme(name)
                expect(type(theme)).to.equal("table")
                expect(theme.WindowColor).to.be.ok()
                expect(theme.AccentColor).to.be.ok()
            end
        end)

        it("creates a window through the public init module", function()
            variables.secureMode = false

            window = Library:CreateWindow({
                name = "Init Window",
                subtitle = "Normal",
                configuration = {
                    autoSave = false,
                    autoLoad = false,
                },
            })

            expect(window.name).to.equal("Init Window")
            expect(window.hidden).to.equal(false)
            expect(window.hasShownOnce).to.equal(true)
        end)

        it("applies the module-level topbar and loading overrides", function()
            variables.secureMode = false

            Library.TopbarText = "Hub"
            Library.TopbarIcon = 123456789
            Library.LoadingText = "Loading Hub"
            Library.LoadingIcon = 987654321

            window = Library:CreateWindow({
                name = "Override Window",
                configuration = {
                    autoSave = false,
                    autoLoad = false,
                },
            })

            -- the module overrides flow into the window's collapsed face unless
            -- the window props set their own
            expect(window.showName).to.equal("Hub")
            expect(window.showIcon).to.equal(123456789)

            -- restore for later specs: the module is cached across requires
            Library.TopbarText = "Menu"
            Library.TopbarIcon = ""
            Library.LoadingText = ""
            Library.LoadingIcon = ""
        end)

        it("runs the secure-mode preload and font-swap branches deterministically", function()
            local preloadCalled = false
            local loadedWeights = {}

            variables.secureMode = true
            image.preload = function(onSettled)
                preloadCalled = true
                if onSettled then
                    onSettled(0)
                end
            end
            variables.fontManager.loadFont = function(_, _asset, weight)
                table.insert(loadedWeights, weight)
                return Font.new("font://secure", weight, Enum.FontStyle.Normal)
            end

            window = Library:CreateWindow({
                name = "Secure Window",
                fallbackFont = Enum.Font.SourceSans,
                configuration = {
                    autoSave = false,
                    autoLoad = false,
                },
            })

            expect(preloadCalled).to.equal(true)
            expect(#loadedWeights).to.equal(2)
            expect(window.name).to.equal("Secure Window")
            expect(window.hidden).to.equal(false)
        end)
    end)
end
