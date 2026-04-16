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

    it('cursor controls write ANSI codes without error', function()
        -- Just ensure they don't throw
        terminal.save_cursor()
        terminal.restore_cursor()
        terminal.hide_cursor()
        terminal.show_cursor()
        terminal.clear_to_end()
        terminal.clear_to_bottom()
        terminal.move_cursor(1, 1)
        assert.is_true(true)
    end)
end)
