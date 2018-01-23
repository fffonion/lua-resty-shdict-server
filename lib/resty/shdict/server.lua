

local tonumber = tonumber
local pairs = pairs
local type = type
local sub = string.sub
local byte = string.byte
local table_concat = table.concat

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 54)

_M._VERSION = '0.01'

-- shdict API has 4 arguments at most
local SHDICT_MAX_ARGUMENTS = 4
local CRLF = "\r\n"

local mt = { __index = _M }

-- put password before shdict, if someone accidently use module.new to initialize,
-- we will not expose password as shdict name
function _M.new(self, password, shdict)
    return setmetatable({ shdict = shdict, password = password, authenticated = false}, mt)
end

local function _do_cmd(self, cmd, args)
    local ret = new_tab(0, 3) 

    while true do
        -- authentication
        if cmd == "auth" then
            if not self.password then
                ret.err = "Client sent AUTH, but no password is set"
            elseif args[1] ~= self.password then
                ret.err = "invalid password"
                self.authenticated = false
            else
                self.authenticated = true
            end
            break
        elseif self.password and not self.authenticated then
            ret.err = "authentication required"
            break
        end

        if cmd == "ping" then
            ret.has_msg = true
            ret.msg = "PONG"
            break
        elseif cmd == "select" then
            self.shdict = args[1]
        elseif not self.shdict then
            ret.err = "no shdict selected"
            break
        end

        local dict = ngx.shared[self.shdict]
        if not dict then
            ret.err = "shdict '".. self.shdict .."' not defined"
            if cmd == "select" then
                self.shdict = nil
            end
            break
        end
        if cmd == "select" then 
            break
        end

        local _func = dict[cmd]
        if not _func then
            ret.err = "unknown command '" .. cmd .. "'"
            break
        end

        local ok, result, err = pcall(_func, dict, unpack(args))
        -- lua level error
        if not ok then
            ret.err = result
            break
        end
        if err then
            -- shdict API error
            ret.err = err
        elseif result ~= true then
            -- shdict always return true as first return value if there's
            -- no "actual" return values
            -- we only put it into ret.msg if shdict actually return something
            ret.msg = result
            -- in some cases, result is nil
            -- ret.has_msg is used to indicate that we has set a value to ret.msg
            ret.has_msg = true
        end
        
        break
    end
    return ret
end

local function _parse_line(line)
    local cmd
    local args = new_tab(SHDICT_MAX_ARGUMENTS, 0) 

    local s_quote_level = 0 -- single quote level
    local d_quote_level = 0 -- double quote level
    local buf = {}
    local flush_buf = false
    local unquoted = false
    local argc = 0
    local it, err = ngx.re.gmatch(line, "(.)", "jo")
    if not it then
        ngx.log(ngx.ERR, "error splitting arguments ", err)
        return nil, nil
    end
    while true do
        local v, err = it()
        if err then
            ngx.log(ngx.ERR, "error iterating arguments ", err)
            return nil, nil
        end
        if not v then
            break
        end

        v = v[0]
        if v == '"' then
            if unquoted then
                buf[#buf + 1] = '"'
                unquoted = false
            elseif d_quote_level > 0 then
                flush_buf = true
            elseif s_quote_level > 0 then
                buf[#buf + 1] = '"'
            else
                d_quote_level = d_quote_level + 1
            end
        elseif v == "'" then
            if unquoted then
                buf[#buf + 1] = "'"
                unquoted = false
            elseif s_quote_level > 0 then
                flush_buf = true
            elseif d_quote_level > 0 then
                buf[#buf + 1] = "'"
            else
                s_quote_level = s_quote_level + 1
            end
        elseif v == " " then
            if s_quote_level + d_quote_level == 0 then
                if #buf > 0 then
                    flush_buf = true
                end
            else
                buf[#buf + 1] = v
            end
        elseif v == [[\]] then
            if unquoted then
                -- 12\\3   -> "12\\\\3"
                -- "12\\3" -> "12\\3"
                buf[#buf + 1] = [[\]]
                if d_quote_level + s_quote_level == 0 then
                    buf[#buf + 1] = [[\]]
                end
                unquoted = false
            else
                unquoted = true
            end
        else
            buf[#buf + 1] = v
        end

        if flush_buf then
            -- move buf to cmd or args
            if not cmd then
                cmd = table_concat(buf, ""):lower()
            else
                -- exceeds max argument count
                if argc >= SHDICT_MAX_ARGUMENTS then
                    return nil, nil
                end
                args[argc + 1] = table_concat(buf, "")
                argc = argc + 1
            end
            buf = {}
            flush_buf = false
            d_quote_level = 0
            s_quote_level = 0
        end
    end

    -- has unmatched quotes
    if s_quote_level + d_quote_level > 0 then
        return nil, nil
    end

    -- flush rest buffer
    if #buf > 0 then
        if not cmd then
            cmd = table_concat(buf, ""):lower()
        else
            -- exceeds max argument count
            if argc >= SHDICT_MAX_ARGUMENTS then
                return nil, nil
            end
            args[argc + 1] = table_concat(buf, "")
            argc = argc + 1
        end
    end

    return cmd, args 
end


local function output_plain(ret)
    local output

    if ret.err then
        output = "ERR " .. ret.err
    else
        if ret.has_msg then
            if ret.msg == nil then
                output = "(nil)"
            elseif type(ret.msg) == 'string' then
                output = "\"" .. ret.msg .. "\""
            elseif type(ret.msg) == 'table' then
                local r = {}
                for i, v in pairs(ret.msg) do
                    r[#r + 1] = i .. ") " .. v
                end
                output = table_concat(r, "\n")
            else
                output = ret.msg
            end
        else
            output = "OK"
        end
    end

    return output
end

local function output_json(ret)
    local output = {ok = true, response = nil, error = nil}
    local json = require("cjson")
    if not json then
        ngx.log(ngx.ERR, "cjson is not found")
        ngx.exit(500)
    end
    
    if ret.err then
        output.ok = false
        output.error = ret.err
    else
        if ret.has_msg then
            output.response = ret.msg
        end
    end
    return json.encode(output)
end

function _M.serve_http(self, output_filter)
    -- HTTP subsystem server returning a single line response at a time
    self.shdict = ngx.var.arg_dict or self.shdict
    -- silently ignore password if there's no password set
    if self.password and ngx.var.arg_password then
        local ret = _do_cmd(self, "auth", { ngx.var.arg_password })
        if ret.err ~= nil then
            ngx.say(output_plain(ret))
            return
        end
    end

    local cmd, args = _parse_line(ngx.unescape_uri(ngx.var.arg_cmd))

    if not cmd then
        ngx.say("Invalid argument(s)")
        return
    end

    local ret = _do_cmd(self, cmd, args)

    output_filter = output_filter or output_plain
    ngx.say(output_filter(ret))

end

function _M.serve_http_plain(self)
    ngx.header.content_type = 'text/plain';
    return _M.serve_http(self, output_plain)
end

function _M.serve_http_json(self)
    ngx.header.content_type = 'application/json';
    return _M.serve_http(self, output_json)
end



local function _parse_redis_req(line, sock)
    -- parse RESP protocol request with a preread line and the request socket
    local err
    if not line then
        line, err = sock:receive()
        if not line then
            return nil, err
        end
    end

    -- taken from lua-resty-redis._read_reply
    local prefix = byte(line)

    if prefix == 36 then    -- char '$'
        -- print("bulk reply")

        local size = tonumber(sub(line, 2))
        if size < 0 then
            return nil
        end

        local data, err = sock:receive(size)
        if not data then
            if err == "timeout" then
                sock:close()
            end
            return nil, err
        end

        local dummy, err = sock:receive(2) -- ignore CRLF
        if not dummy then
            return nil, err
        end

        return data

    elseif prefix == 43 then    -- char '+'
        -- print("status reply")

        return sub(line, 2)

    elseif prefix == 42 then -- char '*'
        local n = tonumber(sub(line, 2))

        -- print("multi-bulk reply: ", n)
        if n < 0 then
            return null
        end

        local cmd
        local vals = new_tab(n - 1, 0)
        local nvals = 0
        for i = 1, n do
            local res, err = _parse_redis_req(nil, sock)
            if res then
                if cmd == nil then
                    cmd = res
                else
                    nvals = nvals + 1
                    vals[nvals] = res
                end

            elseif res == nil then
                return nil, err

            else
                -- be a valid redis error value
                if cmd == nil then
                    cmd = res
                else
                    nvals = nvals + 1
                    vals[nvals] = {false, err}
                end
            end
        end

        return cmd, vals

    elseif prefix == 58 then    -- char ':'
        -- print("integer reply")
        return tonumber(sub(line, 2))

    elseif prefix == 45 then    -- char '-'
        -- print("error reply: ", n)

        return false, sub(line, 2)

    else
        -- when `line` is an empty string, `prefix` will be equal to nil.
        return nil, "unknown prefix: \"" .. tostring(prefix) .. "\""
    end
end

local function _serialize_redis(data)
    if data == nil then
        return "$-1" .. CRLF
    elseif type(data) == 'string' then
        return "+" .. data .. CRLF
    elseif type(data) == 'number' then
        return ":" .. data .. CRLF
    elseif type(data) == 'table' then
        local r = {"*" .. #data}
        -- only iterate the array part
        for i, v in ipairs(data) do
            if type(v) == 'string' then
                r[#r + 1] = "$" .. #v
                r[#r + 1] = v
            elseif type(v) == 'number' then
                r[#r + 1] = ":" .. v
            elseif type(v) == 'table' then
                r[#r + 1] = _serialize_redis(v)
            elseif v == nil then
                r[#r + 1] = "$-1"
            else
                ngx.log(ngx.ERR, "value ", v, " can't be serialized in a array")
            end
        end
        -- add trailling CRLF
        r[#r + 1] = ""
        return table_concat(r, CRLF)
    else
        return "-ERR Type '" .. type(data) .. "' can't be serialized using RESP" .. CRLF
    end
end

local function output_redis(ret)
    if ret.err then
        return "-ERR " .. ret.err .. "\r\n"
    end
    local output
    if ret.has_msg then
        return _serialize_redis(ret.msg)
    else
        return _serialize_redis("OK")
    end

end


function _M.serve_stream_redis(self)
    -- stream subsystem server that is Redis-compatible and supports RESP and inline protocol
    local sock = assert(ngx.req.socket(true))
    local shdict = self.shdict
    local line, prefix, err
    local cmd, args
    while true do
        -- read a line
        line, err = sock:receive()
        if not line then
            if err == "timeout" then
                sock:close()
            end
            return
        end
        prefix = byte(line)
        if prefix == 42 then -- char '*'
            cmd, args = _parse_redis_req(line, sock)
            if cmd == nil then
                ngx.print(output_redis({[err] = args}))
            end
        else
            cmd, args = _parse_line(line)
        end

        if not cmd then
            ngx.say("Invalid argument(s)")
        else
            local ret = _do_cmd(self, cmd, args)
            ngx.print(output_redis(ret))
        end
    end


   
end


function _M.serve(self, mode)
    if not mode then
        if ngx.config.subsystem == "http" then
            mode = "http_plain"
        elseif ngx.config.subsystem == "stream" then
            mode = "stream_redis"
        else
            ngx.log(ngx.ERR, "subsystem ", ngx.config.subsystem, " not supported")
            ngx.exit(500)
        end
    end
    local handler = _M["serve_" .. mode]
    if not handler then
        ngx.log(ngx.ERR, "handler ", mode, " not found")
        ngx.exit(500)
    end

    return handler(self)
end

return _M
