# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);


my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/lib/?/init.lua;;";
    lua_shared_dict dogs 1m;
};

run_tests();

__DATA__
=== TEST 1: HTTP with get.
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            ngx.shared.dogs:set("doge", "wow")
            local srv = require("resty.shdict.server")
            local s = srv:new(nil, "dogs")
            s:serve()
        }
    }
--- request
    GET /t?cmd=get%20doge
--- response_body eval
"\"wow\""
--- no_error_log
[error]


=== TEST 2: HTTP initialized without shdict, no dict arg.
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            ngx.shared.dogs:set("doge", "wow")
            local srv = require("resty.shdict.server")
            local s = srv:new(nil, nil)
            s:serve()
        }
    }
--- request
    GET /t?cmd=get%20doge
--- response_body eval
"ERR no shdict selected"
--- no_error_log
[error]


=== TEST 3: HTTP initialized without shdict, has dict arg.
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            ngx.shared.dogs:set("doge", "wow")
            local srv = require("resty.shdict.server")
            local s = srv:new(nil, nil)
            s:serve()
        }
    }
--- request
    GET /t?dict=dogs&cmd=get%20doge
--- response_body eval
"\"wow\""
--- no_error_log
[error]


=== TEST 4: HTTP initialized without shdict, has wrong dict arg.
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            ngx.shared.dogs:set("doge", "wow")
            local srv = require("resty.shdict.server")
            local s = srv:new(nil, nil)
            s:serve()
        }
    }
--- request
    GET /t?dict=cats&cmd=get%20dog
--- response_body eval
"ERR shdict 'cats' not defined"
--- no_error_log
[error]


=== TEST 5: HTTP initialized with password, no password arg.
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            ngx.shared.dogs:set("doge", "wow")
            local srv = require("resty.shdict.server")
            local s = srv:new("foobar", nil)
            s:serve()
        }
    }
--- request
    GET /t?dict=dogs&cmd=get%20dog
--- response_body eval
"ERR authentication required"
--- no_error_log
[error]


=== TEST 6: HTTP initialized with password, has password arg.
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            ngx.shared.dogs:set("doge", "wow")
            local srv = require("resty.shdict.server")
            local s = srv:new("foobar", nil)
            s:serve()
        }
    }
--- request
    GET /t?dict=dogs&cmd=get%20doge&password=foobar
--- response_body eval
"\"wow\""
--- no_error_log
[error]


=== TEST 7: HTTP initialized with password, wrong password arg.
--- http_config eval: $::HttpConfig
--- config
    location =/t {
        content_by_lua_block {
            ngx.shared.dogs:set("doge", "wow")
            local srv = require("resty.shdict.server")
            local s = srv:new("foobar", nil)
            s:serve()
        }
    }
--- request
    GET /t?dict=dogs&cmd=get%20doge&password=foobarbar
--- response_body eval
"ERR invalid password"
--- no_error_log
[error]

