Name
====

lua-resty-shdict-tool - An interface for debugging and serving ngx.shared dictionaries

Table of Contents
=================

- [Description](#description)
- [Status](#status)
- [Synopsis](#synopsis)
- [API](#api)
- [Commands](#commands)
	* [Basic commands](#basic-commands)
    * [AUTH](#auth)
	* [SELECT](#auth)
- [Known Issues](#known-issues)
- [TODO](#todo)
- [Copyright and License](#copyright-and-license)
- [See Also](#see-also)


Description
===========

This is a tool to provide a `redis-cli`-like interface to debug [ngx.shared.DICT](https://github.com/openresty/lua-nginx-module#ngxshareddict) API.

It can also be used as a mocking Redis server (WIP).

[Back to TOC](#table-of-contents)


Status
========

Experimental.

Synopsis
========

Shared dictionaries defined in `http` and `stream` subsystems are not shared to each other, thus we need two sets of configurations to debug with either subsystem. Despite from this, this module provide a similar API to use in both subsystems.

http
----

```lua
lua_shared_dict dogs 10m;

server {
	listen 80;
	
	location =/cli {
		content_by_lua_block {

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

[Back to TOC](#table-of-contents)


API
=======

shdict.server:new(password, shdict)
---------------------------------

Initialize the server instance with *password* and pre-selected shared dictionary *shdict*.

If *password* is not set, the server is public. If *password* is set, client must call [auth](#auth) command to authenticate before running other commands. Please take proper security measurements if you're listening to non-local interfaces.

If *shdict* is not set, client must call [select](#select) command to select a shared dictionary.

shdict.server:serve()
---------------------

Start the default handler in each subsystem. For `http` the default handler is `serve_http_plain`. For `stream` the default handler is `serve_stream_plain`.

shdict.server:serve_http_plain()
--------------------------------

This handler accept a single HTTP request from client and send the response back in plain text.

shdict.server:serve_stream_plain()
----------------------------------

This handler accept TCP connection, read line by line from client and send the response back in plain text.

[Back to TOC](#table-of-contents)


Commands
=======

Basic commands
-------------

Methods from `ngx.shared.DICT` API are supported.

* [ngx.shared.DICT](#ngxshareddict)
* [ngx.shared.DICT.get](#ngxshareddictget)
* [ngx.shared.DICT.get_stale](#ngxshareddictget_stale)
* [ngx.shared.DICT.set](#ngxshareddictset)
* [ngx.shared.DICT.safe_set](#ngxshareddictsafe_set)
* [ngx.shared.DICT.add](#ngxshareddictadd)
* [ngx.shared.DICT.safe_add](#ngxshareddictsafe_add)
* [ngx.shared.DICT.replace](#ngxshareddictreplace)
* [ngx.shared.DICT.delete](#ngxshareddictdelete)
* [ngx.shared.DICT.incr](#ngxshareddictincr)
* [ngx.shared.DICT.lpush](#ngxshareddictlpush)
* [ngx.shared.DICT.rpush](#ngxshareddictrpush)
* [ngx.shared.DICT.lpop](#ngxshareddictlpop)
* [ngx.shared.DICT.rpop](#ngxshareddictrpop)
* [ngx.shared.DICT.llen](#ngxshareddictllen)
* [ngx.shared.DICT.ttl](#ngxshareddictttl)
* [ngx.shared.DICT.expire](#ngxshareddictexpire)
* [ngx.shared.DICT.flush_all](#ngxshareddictflush_all)
* [ngx.shared.DICT.flush_expired](#ngxshareddictflush_expired)
* [ngx.shared.DICT.get_keys](#ngxshareddictget_keys)
* [ngx.shared.DICT.capacity](#ngxshareddictcapacity)
* [ngx.shared.DICT.free_space](#ngxshareddictfree_space)

Some of the commands require the `resty.core` being installed and is limited in the stream subsystem where `resty.core` is not available yet.

Methods names are **case-insensitive**. Arguments are seperated by spaces.

For example:

- To set a value **wow** with key **dog**, use `SET dog wow` or `sEt dog wow`.
- To set a value **wow !** with key **dog**, use `SET dog "wow !"`.
- To set a value **"wow" !** with key **dog**, use `SET dog "\"wow\" !"`.

AUTH
----

Authenticate to the server.

```
AUTH password
```

SELECT
------

Select a shared dictionary.

```
SELECT shdict
```

[Back to TOC](#table-of-contents)


Known Issues
====

- The library will use `resty.core` if it's installed, the behaviour will be slightly different from the C implementation. For example, missing arguments will be filled by `nil` when using `resty.core`, issuing `SET a` is equivalent to `SET a nil` in this situation.

[Back to TOC](#table-of-contents)


TODO
====

- Add tests.
- Implement a CLI tool.
- Apply data type convertion to distinguish string, number and nil.
- Redis compatible protocol.
- Add EVAL command.

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