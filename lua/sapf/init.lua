local config = require("sapf.config")

local M = {}

local CONSTANTS = {
    CHUNK_SIZE = 64,
    BUFFER_TYPE = "nofile",
    BUFFER_HIDDEN = "hide",
}

M.DEFAULT_WINDOW_OPTIONS = {
    wrap = false,
    number = false,
    relativenumber = false,
    signcolumn = "no",
}

local job_id, buffer_id

local function debug_log(msg)
    if config.options.debug then
        vim.notify("[SAPF] " .. msg, vim.log.levels.DEBUG)
    end
end

local function create_sapf_buffer()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "*" .. config.options.buffer_name .. "*")
    vim.bo[buf].buftype = CONSTANTS.BUFFER_TYPE
    vim.bo[buf].bufhidden = CONSTANTS.BUFFER_HIDDEN
    vim.bo[buf].swapfile = false
    vim.bo[buf].fileformat = "unix"
    debug_log("Created new buffer: " .. buf)
    return buf
end

local function create_sapf_window()
    local win_conf = {
        relative = 'editor',
        width = math.floor(vim.o.columns * config.options.window.width),
        height = vim.o.lines - 4,
        col = vim.o.columns,
        row = 0,
        anchor = 'NE',
        style = 'minimal',
        border = config.options.window.border
    }
    local win = vim.api.nvim_open_win(buffer_id, false, win_conf)
    for option, value in pairs(M.DEFAULT_WINDOW_OPTIONS) do
        vim.wo[win][option] = value
    end
    debug_log("Created new window: " .. win)
    return win
end

local function ensure_buffer_exists()
    if not buffer_id or not vim.api.nvim_buf_is_valid(buffer_id) then
        buffer_id = create_sapf_buffer()
    end
    return buffer_id
end

local function on_stdout(_, data, _)
    if not (data and #data > 0) then return end
    vim.schedule(function()
        if not (buffer_id and vim.api.nvim_buf_is_valid(buffer_id)) then return end
        local lines = vim.tbl_filter(function(line) return line and line ~= "" end, data)
        if #lines == 0 then return end
        lines = vim.tbl_map(function(line) return line:gsub("\r", "") end, lines)
        pcall(function()
            vim.api.nvim_buf_set_lines(buffer_id, -1, -1, false, lines)
            local win_id = vim.fn.bufwinid(buffer_id)
            if win_id ~= -1 then
                vim.api.nvim_win_set_cursor(win_id, { vim.api.nvim_buf_line_count(buffer_id), 0 })
            end
        end)
    end)
end

local function ensure_window_visible()
    if vim.fn.bufwinid(buffer_id) == -1 and buffer_id then
        create_sapf_window()
    end
end

function M.start()
    if job_id then
        vim.notify("A sapf process is already running", vim.log.levels.ERROR)
        return
    end
    ensure_buffer_exists()
    ensure_window_visible()
    local job_opts = {
        on_stdout = on_stdout,
        on_stderr = on_stdout,
        stdout_buffered = false,
        stderr_buffered = false,
        pty = true,
    }
    job_id = vim.fn.jobstart({ config.options.interpreter }, job_opts)
    if job_id <= 0 then
        vim.notify("Failed to start sapf process", vim.log.levels.ERROR)
        return
    end
    vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, {})
    debug_log("Started SAPF process with job_id: " .. job_id)
end

function M.send_stop()
    M.send_string("stop")
end

function M.send_clear()
    M.send_string("clear")
end

function M.stop()
    if job_id then
        vim.fn.jobstop(job_id)
        job_id = nil
        if buffer_id and vim.api.nvim_buf_is_valid(buffer_id) then
            vim.api.nvim_buf_delete(buffer_id, { force = true })
            buffer_id = nil
        end
        debug_log("Stopped SAPF process and cleaned up resources")
    end
end

function M.send_string(str)
    if not job_id then
        vim.notify("No sapf process running", vim.log.levels.ERROR)
        return
    end
    ensure_window_visible()
    str = vim.trim(str) .. "\n"
    local success, err = pcall(function()
        for i = 1, #str, CONSTANTS.CHUNK_SIZE do
            vim.fn.chansend(job_id, string.sub(str, i, i + CONSTANTS.CHUNK_SIZE - 1))
        end
    end)
    if not success then
        vim.notify("Failed to send string: " .. tostring(err), vim.log.levels.ERROR)
    end
end

function M.eval_region(start_pos, end_pos, transform_text)
    local lines = vim.api.nvim_buf_get_lines(0, start_pos[1] - 1, end_pos[1], false)
    if #lines > 0 then
        lines[1] = string.sub(lines[1], start_pos[2])
        lines[#lines] = string.sub(lines[#lines], 1, end_pos[2])
    end
    local text = table.concat(lines, "\n")
    if transform_text then
        text = transform_text(text)
    end
    M.send_string(text)
end

function M.eval_paragraph(transform_text)
    local start_pos = vim.fn.getpos("'{")
    local end_pos = vim.fn.getpos("'}")
    M.eval_region({ start_pos[2], start_pos[3] }, { end_pos[2], end_pos[3] }, transform_text)
end

function M.run_multiple_paragraphs(transform_text)
    local mode = vim.api.nvim_get_mode().mode
    if mode:sub(1, 1) == "v" then
        local start_pos = vim.fn.getpos("'<")
        local end_pos = vim.fn.getpos("'>")
        M.eval_region({ start_pos[2], start_pos[3] }, { end_pos[2], end_pos[3] }, transform_text)
    else
        M.eval_paragraph(transform_text)
    end
end

function M.stop_and_eval_paragraph(transform_text)
    M.send_string("stop")
    vim.defer_fn(function()
        M.eval_paragraph(transform_text)
    end, 100)
end

function M.word_help()
    local word = vim.fn.expand('<cword>')
    if word and word ~= '' then
        M.send_string(string.format("`%s help", word))
    else
        vim.notify("No word under cursor", vim.log.levels.WARN)
    end
end

function M.health()
    local health = require("health")
    health.report_start("SAPF")
    if vim.fn.executable(config.options.interpreter) == 1 then
        health.report_ok(config.options.interpreter .. " is executable")
    else
        health.report_error(config.options.interpreter .. " is not executable")
    end
end

function M.setup(opts)
    if type(opts) ~= "table" and opts ~= nil then
        error("Expected table or nil for opts, got " .. type(opts))
    end
    config.setup(opts)
    local group = vim.api.nvim_create_augroup("Sapf", { clear = true })
    vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.stop })
    vim.api.nvim_create_user_command("SapfStart", M.start, {})
    vim.api.nvim_create_user_command("SapfKill", M.stop, {})
    vim.api.nvim_create_user_command("SapfStop", M.send_stop, {})
    vim.api.nvim_create_user_command("SapfClear", M.send_clear, {})
    vim.api.nvim_create_user_command("SapfEvalParagraph", function() M.eval_paragraph() end, {})
    vim.api.nvim_create_user_command("SapfRunMultiple", function() M.run_multiple_paragraphs() end, {})
    vim.api.nvim_create_user_command("SapfStopAndEval", function() M.stop_and_eval_paragraph() end, {})
    vim.api.nvim_create_user_command("SapfFunctionHelp", M.word_help, {})
    debug_log("SAPF setup complete")
end

return M
