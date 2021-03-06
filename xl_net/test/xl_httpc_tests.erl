%%  Copyright (c) 2012-2013
%%  StrikeAd LLC http://www.strikead.com
%%
%%  All rights reserved.
%%
%%  Redistribution and use in source and binary forms, with or without
%%  modification, are permitted provided that the following conditions are met:
%%
%%      Redistributions of source code must retain the above copyright
%%  notice, this list of conditions and the following disclaimer.
%%      Redistributions in binary form must reproduce the above copyright
%%  notice, this list of conditions and the following disclaimer in the
%%  documentation and/or other materials provided with the distribution.
%%      Neither the name of the StrikeAd LLC nor the names of its
%%  contributors may be used to endorse or promote products derived from
%%  this software without specific prior written permission.
%%
%%  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%%  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
%%  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
%%  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%%  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
%%  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
%%  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
%%  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%%  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-module(xl_httpc_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("xl_stdlib/include/xl_eunit.hrl").
-include("xl_httpc.hrl").

call_test() ->
    xl_application:start(inets),
    application:set_env(xl_net_test, test_call, [{client, []}, {request, []}]),
    ?assertOk(xl_httpc:start_link(xl_net_test, test_call)),
    try
        ?assertEqual({ok, #http_resp{code = 200, reason = "OK"}},
            xl_httpc:call(test_call, "http://google.com"))
    after
        xl_httpc:stop(test_call)
    end.


post_test() ->
    xl_application:start(inets),
    application:set_env(xl_net_test, test_post, [{client, []}, {request, []}]),
    ?assertOk(xl_httpc:start_link(xl_net_test, test_post)),
    try
        ?assertOk(xl_httpc:post(test_post, "http://google.com", "text/plain", "test"))
    after
        xl_httpc:stop(test_post)
    end.

