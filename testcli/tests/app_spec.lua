-- Basic test for app
local app = require('app')

describe("App CLI", function()
    it("should run without error", function()
        assert.has_no.errors(function()
            app.run({"greet", "TestUser"})
        end)
    end)
end)
