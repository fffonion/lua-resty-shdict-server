# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua::Stream 'no_plan';

use Cwd qw(cwd);


my $pwd = cwd();

our $StreamConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;;";
    lua_shared_dict dogs 1m;
};

#no_shuffle();
run_tests();

__DATA__
=== TEST 1: Redis inline protocol simple get.
--- stream_config eval: $::StreamConfig
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, "dogs")
        s:serve_stream_redis()
    }
--- stream_request eval
"get doge\r
quit\r
"

--- stream_response eval
"+wow\r
"

--- no_error_log
[error]


=== TEST 2: Redis inline protocol initialized without shdict, no dict arg.
--- stream_config eval: $::StreamConfig
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, nil)
        s:serve_stream_redis()
    }
--- stream_request eval
"get doge\r
quit\r
"

--- stream_response eval
"-ERR no shdict selected\r
"

--- no_error_log
[error]


=== TEST 3: Redis inline protocol initialized without shdict, has dict arg.
--- stream_config eval: $::StreamConfig
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, nil)
        s:serve_stream_redis()
    }
--- stream_request eval
"select dogs\r
get doge\r
quit\r
"

--- stream_response eval
"+OK\r
+wow\r
"

--- no_error_log
[error]


=== TEST 4: Redis inline protocol initialized without shdict, has wrong dict arg.
--- stream_config eval: $::StreamConfig
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, nil)
        s:serve_stream_redis()
    }
--- stream_request eval
"select cats\r
quit\r
"

--- stream_response eval
"-ERR shdict 'cats' not defined\r
"

--- no_error_log
[error]


=== TEST 5: Redis inline protocol initialized with password, no password arg.
--- stream_config eval: $::StreamConfig
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new("foobar", nil)
        s:serve_stream_redis()
    }
--- stream_request eval
"select dogs\r
get doge\r
quit\r
"

--- stream_response eval
"-ERR authentication required\r
-ERR authentication required\r
"

--- no_error_log
[error]


=== TEST 6: Redis inline protocol initialized with password, has password arg.
--- stream_config eval: $::StreamConfig
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new("foobar", nil)
        s:serve_stream_redis()
    }
--- stream_request eval
"auth foobar\r
select dogs\r
get doge\r
quit\r
"

--- stream_response eval
"+OK\r
+OK\r
+wow\r
"

--- no_error_log
[error]


=== TEST 7: Redis inline protocol initialized with password, wrong password arg.
--- stream_config eval: $::StreamConfig
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new("foobar", nil)
        s:serve_stream_redis()
    }
--- stream_request eval
"auth foobarbar\r
select dogs\r
get doge\r
quit\r
"

--- stream_response eval
"-ERR invalid password\r
-ERR authentication required\r
-ERR authentication required\r
"

--- no_error_log
[error]


=== TEST 8: Redis inline protocol ping 
--- stream_config eval: $::StreamConfig
--- stream_server_config
    content_by_lua_block {
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, nil)
        s:serve_stream_redis()
    }
--- stream_request eval
"ping\r
quit\r
"

--- stream_response eval
"+PONG\r
"

--- no_error_log
[error]


=== TEST 9: Redis inline protocol parse line
--- stream_config eval: $::StreamConfig
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("d'o'ge", "wow")
        ngx.shared.dogs:set("do ge", "wo w")
        ngx.shared.dogs:set("do", "wo")
        ngx.shared.dogs:set([[do"ge]], [[wo"w]])
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, "dogs")
        s:serve_stream_redis()
    }
--- stream_request eval
"get \"\r
get \"doge\" \"\r
get \"d'o'ge\"\r
get \"d'o\"ge'\r
get \"do ge\"\r
get \"do\\\"ge\"\r
quit\r
"

--- stream_response eval
"Invalid argument(s)\r
Invalid argument(s)\r
+wow\r
Invalid argument(s)\r
+wo w\r
+wo\"w\r
"

--- no_error_log
[error]

