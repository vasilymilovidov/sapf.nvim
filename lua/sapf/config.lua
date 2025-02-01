local M = {}

M.defaults = {
    buffer_name = "SAPF Repl",
    interpreter = "sapf",
    window = {
        width = 0.4,
        position = "right",
        border = "single",
    },
    buffer = {
        scroll_to_bottom = true,
        clear_on_start = true,
    },
    debug = false,
}

M.options = {}

local function validate_config(opts)
    if type(opts.interpreter) ~= "string" then
        return false, "interpreter must be a string"
    end
    if type(opts.buffer_name) ~= "string" then
        return false, "buffer_name must be a string"
    end
    if opts.window then
        if type(opts.window.width) ~= "number" or opts.window.width <= 0 or opts.window.width > 1 then
            return false, "window.width must be a number between 0 and 1"
        end
        if opts.window.position and not vim.tbl_contains({ "right", "left", "top", "bottom" }, opts.window.position) then
            return false, "window.position must be one of: right, left, top, bottom"
        end
    end
    return true
end

function M.setup(opts)
    local config = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
    local is_valid, error_msg = validate_config(config)
    if not is_valid then
        error(string.format("Invalid configuration: %s", error_msg))
    end
    M.options = config
    if M.options.debug then
        vim.notify("SAPF config initialized: " .. vim.inspect(M.options), vim.log.levels.DEBUG)
    end
end

function M.get()
    return M.options
end

function M.reset()
    M.options = vim.deepcopy(M.defaults)
end

return M
