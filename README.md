Name
====

lua-resty-shdict-server - A HTTP and Redis protocol compatible interface for debugging ngx.shared API

Table of Contents
=================

- [Description](#description)
- [Status](#status)
- [Synopsis](#synopsis)
- [API](#api)
- [Commands](#commands)
    * [Basic commands](#basic-commands)
    * [AUTH](#auth)
    * [SELECT](#select)
    * [PING](#ping)
    * [KEYS](#keys)
	* [EVAL](#eval)
- [Known Issues](#known-issues)
- [TODO](#todo)
- [Copyright and License](#copyright-and-license)
- [See Also](#see-also)


Description
===========

This is a library that provides a HTTP and a Redis protocol compatible interface to debug [ngx.shared.DICT](https://github.com/openresty/lua-nginx-module#ngxshareddict) API.

It can also be used as a mocking Redis server (WIP).

[Back to TOC](#table-of-contents)


Status
========

Experimental.

Synopsis
========

Shared dictionaries defined in `http` and `stream` subsystems are not shared to each other *currently*, thus we need two sets of configurations to debug with either subsystem. Despite from this, this module provide a similar API to use in both subsystems.

http
----

```lua
lua_shared_dict dogs 10m;

server {
    listen 80;
    
    location =/cli {
        content_by_lua_block {
            require "resty.core"
            local srv = require("resty.shdict.server")
            local s = srv:new("foobar", nil)
            s:serve()
        }
    }
}
```

This sets up a simple HTTP server. Use any http client like `curl` to issue a http request to the location we configured. For example:

```shell
$ curl "http://host/cli?dict=dogs&cmd=set%20dog%20wow&password=foobar"
OK

$ curl "http://host/cli?dict=dogs&cmd=get%20dog&password=foobar"
"wow"
```

stream
----

```lua
lua_shared_dict dogs 10m;

server {
    listen 127.0.0.1:18001;
    content_by_lua_block {
        require "resty.core.shdict"
        local srv = require("resty.shdict.server")
        local s = srv:new("foobar", nil)
        s:serve()
    }
}
```

This sets up a simple TCP server. Use telnet or equivalent tools to connect interactively. For example:

```shell
$ telnet 127.0.0.1 18001
Trying 127.0.0.1...
Connected to 127.0.0.1.
Escape character is '^]'.
SELECT dogs
ERR authentication required
AUTH foobar
OK
SELECT dogs
OK
SET dog wow
OK
GET dog
"wow"
```

Also it supports [Redis RESP protocol](https://redis.io/topics/protocol).

```shell
$ redis-cli -h 127.0.0.1 -p 18001
127.0.0.1:18001> get dogs
(error) ERR authentication required
127.0.0.1:18001> auth foobar
OK
127.0.0.1:18001> set dog wow
(error) ERR no shdict selected
127.0.0.1:18001> select dogs
OK
127.0.0.1:18001> set dog wow
OK
127.0.0.1:18001> get dog
wow
```


[Back to TOC](#table-of-contents)


API
=======

shdict.server:new(password, shdict)
---------------------------------

Initialize the server instance with *password* and pre-selected shared dictionary *shdict*.

If *password* is not set, the server is public. If *password* is set, client must call [auth](#auth) command to authenticate before running other commands. Please take proper security measurements if you're listening to non-local interfaces.

If *shdict* is not set, client must call [select](#select) command to select a shared dictionary.

shdict.server:serve(mode)
---------------------

Start the server with handler named *mode`. To run handler `serve_stream_redis`, use:

```Lua
shdict.server:serve("stream_redis")
```

If *mode* is not defined, default handler for each subsystem is used. For `http` the default handler is `serve_http_plain`. For `stream` the default handler is `serve_stream_redis`.

shdict.server:serve_http_plain()
--------------------------------

This handler accept a single HTTP request from client and send the response back in plain text.

shdict.server:serve_http_json()
-------------------------------

This handler accept a single HTTP request from client and send the response back in json encoded text.

shdict.server:serve_http(output_filter)
---------------------------------------

This handler accept a single HTTP request from client and send the response formatted by `output_filter`.

If `output_filter` is not defined, **output_plain** is used and this handler is equivalent to `serve_http_plain`.

`output_filter` is a function that takes a table as argument and returns a string. User can define their own filter and genereate desirable output.

shdict.server:serve_stream_redis()
----------------------------------

This handler accept TCP connection in inline or Redis protocol. A plain text TCP client like `telnet` or `nc` or a Redis-compatible client or library can be used to connect to the server.

[Back to TOC](#table-of-contents)


Commands
=======

Basic commands
-------------

Methods from `ngx.shared.DICT` API are supported.

* [ngx.shared.DICT](https://github.com/openresty/lua-nginx-module#ngxshareddict)
* [ngx.shared.DICT.get](https://github.com/openresty/lua-nginx-module#ngxshareddictget)
* [ngx.shared.DICT.get_stale](https://github.com/openresty/lua-nginx-module#ngxshareddictget_stale)
* [ngx.shared.DICT.set](https://github.com/openresty/lua-nginx-module#ngxshareddictset)
* [ngx.shared.DICT.safe_set](https://github.com/openresty/lua-nginx-module#ngxshareddictsafe_set)
* [ngx.shared.DICT.add](https://github.com/openresty/lua-nginx-module#ngxshareddictadd)
* [ngx.shared.DICT.safe_add](https://github.com/openresty/lua-nginx-module#ngxshareddictsafe_add)
* [ngx.shared.DICT.replace](https://github.com/openresty/lua-nginx-module#ngxshareddictreplace)
* [ngx.shared.DICT.delete](https://github.com/openresty/lua-nginx-module#ngxshareddictdelete)
* [ngx.shared.DICT.incr](https://github.com/openresty/lua-nginx-module#ngxshareddictincr)
* [ngx.shared.DICT.lpush](https://github.com/openresty/lua-nginx-module#ngxshareddictlpush)
* [ngx.shared.DICT.rpush](https://github.com/openresty/lua-nginx-module#ngxshareddictrpush)
* [ngx.shared.DICT.lpop](https://github.com/openresty/lua-nginx-module#ngxshareddictlpop)
* [ngx.shared.DICT.rpop](https://github.com/openresty/lua-nginx-module#ngxshareddictrpop)
* [ngx.shared.DICT.llen](https://github.com/openresty/lua-nginx-module#ngxshareddictllen)
* [ngx.shared.DICT.ttl](https://github.com/openresty/lua-nginx-module#ngxshareddictttl)
* [ngx.shared.DICT.expire](https://github.com/openresty/lua-nginx-module#ngxshareddictexpire)
* [ngx.shared.DICT.flush_all](https://github.com/openresty/lua-nginx-module#ngxshareddictflush_all)
* [ngx.shared.DICT.flush_expired](https://github.com/openresty/lua-nginx-module#ngxshareddictflush_expired)
* [ngx.shared.DICT.get_keys](https://github.com/openresty/lua-nginx-module#ngxshareddictget_keys)
* [ngx.shared.DICT.capacity](https://github.com/openresty/lua-nginx-module#ngxshareddictcapacity)
* [ngx.shared.DICT.free_space](https://github.com/openresty/lua-nginx-module#ngxshareddictfree_space)

Some of the commands like `ttl` and `capacity` require the `resty.core` being installed. To use these commands, put `require('resty.core')` for http subsystem and `require('resty.core.shdict')` for stream subsystem.

Methods names are **case-insensitive**. Arguments are seperated by spaces.

For example:

- To set a value **wow** with key **dog**, use `SET dog wow` or `sEt dog wow`.
- To set a value **wow !** with key **dog**, use `SET dog "wow !"`.
- To set a value **"wow" !** with key **dog**, use `SET dog "\"wow\" !"`.

Some commands are mapped to redis-flavoured commands if `resty.shdict.redis-commands` is included.

- `del` as an alias of `delete`
- `flushall` as an alias of `flush_all`

AUTH
----

Authenticate to the server.

```
> AUTH password
```

Returns **OK** if *password* is valid.

SELECT
------

Select a shared dictionary.

```
> SELECT shdict
```

Returns **OK** if *shdict* is found.

PING
----

Test connection to the server.

```
> PING
PONG
```

KEYS
----

This command requires the `resty.shdict.redis-commands` module.

The time complexity is **O(3n)**. This command is for debug only, please do not use in production code to search for keys.

Returns all keys matching *pattern* in a list. The *pattern* is a glob-style pattern.

```
> KEYS pattern
> KEYS do?
> KEYS do*
> KEYS do[a-z]
```

Returns a list of all keys found.

EVAL
----

This command requires the `resty.shdict.redis-commands` module.

Run a Lua script on the server. The syntax is same as Redis [EVAL](https://redis.io/commands/eval). 

```
> EVAL script numkeys key [key ...] arg [arg ...]
> EVAL "shdict.call('set', 'dog', 'wow') 0
(nil)
> EVAL "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}" 2 key1 key2 first second
1) "key1"
2) "key2"
3) "first"
4) "second"
```

For security reasons, only the following APIs are available:

- `ngx.*` APIs except for `ngx.shared` and `ngx.re`
- `shdict.call` and `shdict.pcall`
- `zone` as the current shdict instance

Also an alias from `redis.call` to `shdict.call` is created for convenience.

[Back to TOC](#table-of-contents)


Known Issues
====

- The library will use `resty.core` if it's installed, the behaviour will be slightly different from the C implementation. For example, missing arguments will be filled by `nil` when using `resty.core`, issuing `SET a` is equivalent to `SET a nil` in this situation.
- For performance issues, inline protocol (HTTP inline or Redis inline) only accept four arguments at most. `EVAL` may fail with **Invalid argument(s)** for this reason. To solve this, always use other protocols (like Redis RESP protocol) to call these commands.

[Back to TOC](#table-of-contents)


TODO
====

- Add INFO command.

[Back to TOC](#table-of-contents)


Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2018, by fffonion <fffonion@gmail.com>.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)


See Also
========
* [openresty/lua-nginx-module](https://github.com/openresty/lua-nginx-module)

[Back to TOC](#table-of-contents)