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
-module(xl_cf_tests).
-author("volodymyr.kyrychenko@strikead.com").

-include_lib("eunit/include/eunit.hrl").
-include("xl_cf.hrl").

lists_test() ->
    ?assertEqual([{X, Y, Z} || X <- [1, 2, 3], Y <- [a, b, c], Z <- [x, y, z]],
        xl_cf:flatmap([{X, Y, Z} || X <- [1, 2, 3], Y <- [a, b, c], Z <- [x, y, z]])).

stream_test() ->
    ?assertEqual([{X, Y, Z} || X <- [1, 2, 3], Y <- [a, b, c], Z <- [x, y, z]],
        xl_stream:to_list(xl_cf:flatmap([{X, Y, Z} ||
            X <- xl_stream:to_stream([1, 2, 3]),
            Y <- xl_stream:to_stream([a, b, c]),
            Z <- xl_stream:to_stream([x, y, z])
        ]))).

gb_tree_test() ->
    ?assertEqual(gb_trees:insert(1, 2, gb_trees:insert(2, 4, gb_trees:insert(3, 6, gb_trees:empty()))),
        xl_cf:flatmap([V + K ||
            {K, V} <- gb_trees:insert(1, 1, gb_trees:insert(2, 2, gb_trees:insert(3, 3, gb_trees:empty())))
        ])).
