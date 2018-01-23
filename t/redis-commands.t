# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua::Stream 'no_plan';

no_shuffle();
run_tests();

__DATA__
=== TEST 1: Redis commands KEYS 
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge1", "wow")
        ngx.shared.dogs:set("doge2", "such")
        ngx.shared.dogs:set("doge3", "doge")
        require("resty.shdict.redis-commands")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, "dogs")
        s:serve()
    }
--- stream_request eval
"*2\r
\$4\r
keys\r
\$5\r
doge*\r
*2\r
\$4\r
keys\r
\$5\r
do?e1\r

quit\r
"

--- stream_response eval
"*3\r
\$5\r
doge1\r
\$5\r
doge2\r
\$5\r
doge3\r
*1\r
\$5\r
doge1\r
"

--- no_error_log
[error]

=== TEST 2: Redis commands EVAL keys and argv
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        require("resty.shdict.redis-commands")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, "dogs")
        s:serve()
    }
--- stream_request eval
"*7\r
\$4\r
eval\r
\$25\r
return KEYS[2] .. ARGV[1]\r
:2\r
\$1\r
1\r
\$1\r
2\r
\$1\r
3\r
\$1\r
4\r

*3\r
\$4\r
eval\r
\$8\r
return 1\r
\$2\r
aa\r

*3\r
\$4\r
eval\r
\$8\r
return 1\r
:-1\r

*3\r
\$4\r
eval\r
\$8\r
return 1\r
:1\r

*2\r
\$4\r
eval\r
\$8\r
return 1\r

quit\r
"

--- stream_response eval
"+23\r
-ERR value is not an integer or out of range\r
-ERR Number of keys can't be negative\r
-ERR Number of keys can't be greater than number of arg\r
-ERR wrong number of arguments for 'eval' command\r
"

--- no_error_log
[error]


=== TEST 3: Redis commands EVAL shdict.call no error
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        require("resty.shdict.redis-commands")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, "dogs")
        s:serve()
    }
--- stream_request eval
"*3\r
\$4\r
eval\r
\$33\r
return shdict.call('get', 'doge')\r
:0\r

*3\r
\$4\r
eval\r
\$35\r
return shdict.call('set', 'cat', 1)\r
:0\r

*3\r
\$4\r
eval\r
\$32\r
return shdict.call('get', 'cat')\r
:0\r

*3\r
\$4\r
eval\r
\$33\r
return shdict.pcall('get', 'cat')\r
:0\r

quit\r
"
--- stream_response eval
"+wow\r
+OK\r
:1\r
:1\r
"

--- no_error_log
[error]


=== TEST 4: Redis commands EVAL shdict.call and shdict.pcall error handling
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        require("resty.shdict.redis-commands")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, "dogs")
        s:serve()
    }
--- stream_request eval
"*3\r
\$4\r
eval\r
\$34\r
return shdict.call('gget', 'doge')\r
:0\r

*3\r
\$4\r
eval\r
\$28\r
shdict.pcall('gget', 'doge')\r
:0\r

*3\r
\$4\r
eval\r
\$35\r
return shdict.pcall('gget', 'doge')\r
:0\r

quit\r
"
--- stream_response eval
"-ERR Error running script (user_script):2: Unknown ngx.shared command called from Lua script\r
\$-1\r
-ERR (user_script):2: Unknown ngx.shared command called from Lua script\r
"

--- no_error_log
[error]
