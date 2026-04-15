local plugin = require('lumos.plugin')

describe('Plugin Module', function()
    describe('use', function()
        it('applies a function plugin to a target', function()
            local target = {value = 0}
            local p = function(t, opts)
                t.value = (opts.increment or 1)
            end
            plugin.use(target, p, {increment = 5})
            assert.are.equal(5, target.value)
        end)

        it('applies a table plugin with init method', function()
            local target = {name = ""}
            local p = {
                init = function(t, opts)
                    t.name = opts.name or "default"
                end
            }
            plugin.use(target, p, {name = "lumos"})
            assert.are.equal("lumos", target.name)
        end)

        it('returns the target for chaining', function()
            local target = {}
            local result = plugin.use(target, function(t) t.marked = true end)
            assert.are.equal(target, result)
            assert.is_true(target.marked)
        end)

        it('errors for invalid plugin types', function()
            assert.has_error(function()
                plugin.use({}, "not_a_plugin")
            end)
        end)
    end)
end)
