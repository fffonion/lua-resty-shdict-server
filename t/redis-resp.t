# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua::Stream 'no_plan';

no_shuffle();
run_tests();

__DATA__
=== TEST 1: Redis RESP protocol simple get.
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, "dogs")
        s:serve_stream_redis()
    }
--- stream_request eval
"*2\r
\$3\r
get\r
\$4\r
doge\r

quit\r
"

--- stream_response eval
"+wow\r
"

--- no_error_log
[error]


=== TEST 2: Redis RESP protocol initialized without shdict, no dict arg.
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, nil)
        s:serve()
    }
--- stream_request eval
"*2\r
\$3\r
get\r
\$4\r
doge\r

quit\r
"

--- stream_response eval
"-ERR no shdict selected\r
"

--- no_error_log
[error]


=== TEST 3: Redis RESP protocol initialized without shdict, has dict arg.
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, nil)
        s:serve()
    }
--- stream_request eval
"*2\r
\$6\r
select\r
\$4\r
dogs\r

*2\r
\$3\r
get\r
\$4\r
doge\r

quit\r
"

--- stream_response eval
"+OK\r
+wow\r
"

--- no_error_log
[error]


=== TEST 4: Redis RESP protocol initialized without shdict, has wrong dict arg.
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new(nil, nil)
        s:serve()
    }
--- stream_request eval
"*2\r
\$6\r
select\r
\$4\r
cats\r

quit\r
"

--- stream_response eval
"-ERR shdict 'cats' not defined\r
"

--- no_error_log
[error]


=== TEST 5: Redis RESP protocol initialized with password, no password arg.
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new("foobar", nil)
        s:serve()
    }
--- stream_request eval
"*2\r
\$6\r
select\r
\$4\r
dogs\r

*2\r
\$3\r
get\r
\$4\r
doge\r

quit\r
"

--- stream_response eval
"-ERR authentication required\r
-ERR authentication required\r
"

--- no_error_log
[error]


=== TEST 6: Redis RESP protocol initialized with password, has password arg.
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new("foobar", nil)
        s:serve()
    }
--- stream_request eval
"*2\r
\$4\r
auth\r
\$6\r
foobar\r

*2\r
\$6\r
select\r
\$4\r
dogs\r

*2\r
\$3\r
get\r
\$4\r
doge\r

quit\r
"

--- stream_response eval
"+OK\r
+OK\r
+wow\r
"

--- no_error_log
[error]


=== TEST 7: Redis RESP protocol initialized with password, wrong password arg.
--- stream_config
    lua_shared_dict dogs 1m;
--- stream_server_config
    content_by_lua_block {
        ngx.shared.dogs:set("doge", "wow")
        local srv = require("resty.shdict.server")
        local s = srv:new("foobar", nil)
        s:serve()
    }
--- stream_request eval
"*2\r
\$4\r
auth\r
\$9\r
foobarbar\r

*2\r
\$6\r
select\r
\$4\r
dogs\r

*2\r
\$3\r
get\r
\$4\r
doge\r

quit\r
"

--- stream_response eval
"-ERR invalid password\r
-ERR authentication required\r
-ERR authentication required\r
"

--- no_error_log
[error]

