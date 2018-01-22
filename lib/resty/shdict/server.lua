

require "resty.core"

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 54)

_M._VERSION = '0.01'

-- shdict API has 4 arguments at most
local SHDICT_MAX_ARGUMENTS = 4

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

        if cmd == "select" then
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

local function _parse(line)
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
            else
                d_quote_level = d_quote_level + 1
            end
        elseif v == "'" then
            if unquoted then
                buf[#buf + 1] = "'"
                unquoted = false
            elseif s_quote_level > 0 then
                flush_buf = true
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
                cmd = table.concat(buf, ""):lower()
            else
                -- exceeds max argument count
                if argc >= SHDICT_MAX_ARGUMENTS then
                    return nil, nil
                end
                args[argc + 1] = table.concat(buf, "")
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
            cmd = table.concat(buf, ""):lower()
        else
            -- exceeds max argument count
            if argc >= SHDICT_MAX_ARGUMENTS then
                return nil, nil
            end
            args[argc + 1] = table.concat(buf, "")
            argc = argc + 1
        end
    end

    return cmd, args 
end


local function output_plain(self, cmd, args)
    local ret = _do_cmd(self, cmd, args)

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
                    r[#r + 1 ] = i .. ") " .. v
                end
                output = table.concat(r, "\n")
            else
                output = ret.msg
            end
        else
            output = "OK"
        end
    end

    return output
end


function _M.serve_http_plain(self)
    -- HTTP subsystem server returning a single line response at a time
    self.shdict = ngx.var.arg_dict or self.shdict
    -- silently ignore password if there's no password set
    if self.password and ngx.var.arg_password then
        local ret = output_plain(self, "auth", { ngx.var.arg_password })
        if ret ~= "OK" then
            ngx.say(ret)
            return
        end
    end

    local cmd, args = _parse(ngx.unescape_uri(ngx.var.arg_cmd))

    if not cmd then
        ngx.say("Invalid argument(s)")
        return
    end

    ngx.say(output_plain(self, cmd, args))

end

function _M.serve_stream_plain(self)
    -- stream subsystem server returning a single line response in a loop

    local sock = assert(ngx.req.socket(true))
    local shdict = self.shdict
    while true do
        -- read a line
        local cmd, args = _parse(sock:receive())

        if not cmd then
            ngx.say("Invalid argument(s)")
            return
        end

        ngx.say(output_plain(self, cmd, args))
    end

end


function _M.serve(self, mode)
    if not mode then
        if ngx.config.subsystem == "http" then
            mode = "serve_http_plain"
        elseif ngx.config.subsystem == "stream" then
            mode = "serve_stream_plain"
        else
            ngx.log(ngx.ERR, "subsystem ", ngx.config.subsystem, " not supported")
            ngx.exit(500)
        end
    end
    local handler = _M[mode]
    if not handler then
        ngx.log(ngx.ERR, "handler ", mode, " not found")
        ngx.exit(500)
    end

    return handler(self)
end

return _M
