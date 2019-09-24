
local ffi = require 'ffi'

local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C
local next = next
local type = type
local error = error
local table_remove = table.remove
local ngx_re = ngx.re
local ngx_shared = ngx.shared
local getmetatable = getmetatable
local setmetatable = setmetatable

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

-- resty.core.shdict
local function check_zone(zone)
    if not zone or type(zone) ~= "table" then
        return error("bad \"zone\" argument")
    end

    zone = zone[1]
    if type(zone) ~= "userdata" then
        return error("bad \"zone\" argument")
    end

    return zone
end


if ngx_shared then
    local _, dict = next(ngx_shared, nil)
    if dict then
        local mt = getmetatable(dict)
        if mt then
            mt = mt.__index
            if mt then
                mt.delete = function(zone, ...)
                    for i, key in ipairs({...}) do
                        mt.set(zone, key, nil)
                    end
                    return true
                end

                mt.keys = function(zone, pattern)
                    if pattern == nil then
                        return nil, "expecting exactly two arguments, but only seen 1"
                    end
                    -- return a list of keys that matches given pattern
                    -- complexity is O(3n)
                    -- For debug only, do not use in production code
                    local keys = mt.get_keys(zone, 0)
                    -- Let's convert glob pattern to regexp pattern
                    -- a*b? => a.*b.
                    pattern = ngx_re.gsub(pattern, [=[[\*\?]{2,}]=], "*", "jo") -- remove continous * or ?
                    pattern = ngx_re.gsub(pattern, [=[[\.\(\)]+]=], [[\$0]], "jo") -- add \ before . ( )
                    pattern = ngx_re.gsub(pattern, [=[[\*\?]]=], ".$0", "jo") -- convert * to .*, ? to .?
                    pattern = "^" .. pattern .. "$" -- match the whole word
                    for i=#keys, 1, -1 do
                        if not ngx_re.match(keys[i], pattern, "jo") then
                            table_remove(keys, i)
                        end
                    end
                    return keys
                end

                mt.eval = function(zone, code, numkeys, ...)
                    local arg = {...}
                    if numkeys ~= nil then
                        numkeys = tonumber(numkeys)
                        if numkeys == nil then
                            return nil, "value is not an integer or out of range"
                        elseif numkeys < 0 then
                            return nil, "Number of keys can't be negative"
                        elseif #arg < numkeys then
                            return nil, "Number of keys can't be greater than number of arg"
                        end
                    else
                        return nil, "wrong number of arguments for 'eval' command"
                    end

                    local injected = [[
shdict.call = function(cmd, ...)
    assert(cmd and zone[cmd:lower()], "Unknown ngx.shared command called from Lua script")
    return zone[cmd:lower()](zone, ...)
end
shdict.pcall = function(...)
    local ok, result, err = pcall(shdict.call, ...)
    if not ok then
        return nil, result
    end
    return result, err
end
                    ]]
                    -- provide a jailed environment
                    -- optionally: http://metalua.luaforge.net/src/lib/strict.lua.html
                    local env = {
                        ngx = { shared = ngx_shared, re = ngx_re },
                        shdict = new_tab(2, 0),
                        zone = zone,
                        KEYS = arg,
                        ARGV = setmetatable({}, { __index = function(_, i) return arg[i + numkeys] end }), 
                        assert = assert,
                        error = error,
                        getmetatable = getmetatable,
                        ipairs = ipairs,
                        next = next,
                        pairs = pairs,
                        pcall = pcall,
                        select = select,
                        setmetatable = setmetatable,
                        tonumber = tonumber,
                        tostring = tostring,
                        unpack = unpack,

                        bit = bit,
                        math = math,
                        string = string,
                        table = table,
                    }

                    env['redis'] = env['shdict']

                    local f, err = load(injected .. code, "=(user_script)", "t", env) 
                    if not f then
                        return nil, "Error compiling script " .. err
                    end

                    local ok, result, err = pcall(f)
                    if not ok then
                        -- TODO: fix the wrong line number becuase we injected some code
                        return nil, "Error running script ".. result
                    end
                    return result, err

                end

                mt.getflag = function(zone, key)
                    local value, flag = mt.get(zone, key)
                    if value == nil then
                        return value, flag
                    else
                        return flag
                    end
                end

                -- alias
                mt.del = mt.delete
                mt.flushall = mt.flush_all
                mt.setnx = mt.add
                mt.setex = mt.replace

            end
        end
    end
end


return {
    version = 0.01
}

