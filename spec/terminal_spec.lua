-- Terminal module tests
local terminal = require('lumos.terminal')

describe("Terminal Module", function()
    it('should_use_colors returns a boolean', function()
        local ok = terminal.should_use_colors()
        assert.is_boolean(ok)
    end)

    it('should_use_animations returns a boolean', function()
        local ok = terminal.should_use_animations()
        assert.is_boolean(ok)
    end)

    it('supports_interactive_prompts returns a boolean', function()
        local ok = terminal.supports_interactive_prompts()
        assert.is_boolean(ok)
    end)

    it('width returns a positive number', function()
        local w = terminal.width()
        assert.is_number(w)
        assert.is_true(w >= 0)
    end)

    it('height returns a positive number', function()
        local h = terminal.height()
        assert.is_number(h)
        assert.is_true(h >= 0)
    end)

    it('cursor controls write ANSI codes', function()
        -- Mock platform.is_piped so ansi_write produces output in test environment
        local platform = require('lumos.platform')
        local orig_is_piped = platform.is_piped
        platform.is_piped = function() return false end

        -- Capture io.write output to verify sequences
        local original_write = io.write
        local captured = {}
        io.write = function(...)
            for _, v in ipairs({...}) do
                table.insert(captured, tostring(v))
            end
        end

        terminal.save_cursor()
        terminal.restore_cursor()
        terminal.hide_cursor()
        terminal.show_cursor()

        io.write = original_write
        platform.is_piped = orig_is_piped

        local output = table.concat(captured)
        assert.is_not_nil(output:find("\27%[s"))
        assert.is_not_nil(output:find("\27%[u"))
        assert.is_not_nil(output:find("\27%[%?25l"))
        assert.is_not_nil(output:find("\27%[%?25h"))
    end)
end)
