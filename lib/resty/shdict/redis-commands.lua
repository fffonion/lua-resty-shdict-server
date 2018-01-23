
local ffi = require 'ffi'

local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C
local next = next
local type = type
local error = error
local ngx_shared = ngx.shared
local getmetatable = getmetatable


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
                -- alias
                mt.del = mt.delete 
                mt.flushall = mt.flush_all
                -- new commands
                mt.keys = function(L, pattern)
                    -- return a list of keys that matches given pattern
                    -- complexity is O(3n)
                    -- For debug only, do not use in production code
                    local keys = mt.get_keys(L, 0)
                    -- Let's convert glob pattern to regexp pattern
                    -- a*b? => a.*b.
                    pattern = ngx.re.gsub(pattern, [=[[\*\?]{2,}]=], "*", "jo") -- remove continous * or ?
                    pattern = ngx.re.gsub(pattern, [=[[\.\(\)]+]=], [[\$0]], "jo") -- add \ before . ( )
                    pattern = ngx.re.gsub(pattern, [=[[\*\?]]=], ".$0", "jo") -- convert * to .*, ? to .?
                    pattern = "^" .. pattern .. "$" -- match the whole word
                    for i=#keys, 1, -1 do
                        if not ngx.re.match(keys[i], pattern, "jo") then
                            table.remove(keys, i)
                        end
                    end
                    return keys
                end
            end
        end
    end
end


return {
    version = 0.01
}

