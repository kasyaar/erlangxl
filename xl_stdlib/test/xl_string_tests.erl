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
-module(xl_string_tests).

-include_lib("eunit/include/eunit.hrl").
-include("xl_lang.hrl").

strip_test() ->
    ?assertEqual("a b\tc", xl_string:strip(" \ta b\tc \r\n")).

strip_empty_test() ->
    ?assertEqual("", xl_string:strip("")).

stripthru_test() ->
    ?assertEqual("abc\"\\n\"", xl_string:stripthru("a\tb\nc\"\\n\"")).

substitute_test() ->
    ?assertEqual(<<"xyz1">>,
        xl_string:substitute(<<"x@a_a@z@b-b@">>, [{a_a, "y"}, {'b-b', 1}], {$@, $@})),
    ?assertEqual("xyz1",
        xl_string:substitute("x{a_a}z{b-b}", [{a_a, "y"}, {'b-b', 1}])),
    ?assertEqual("xyz1",
        xl_string:substitute("x{a}z{b}", [{a, "y"}, {b, 1}])),
    ?assertEqual("xyzy",
        xl_string:substitute("x{a}z{a}", [{a, "y"}])),
    ?assertEqual("xyz{b+}",
        xl_string:substitute("x{a}z{b+}", [{a, "y"}])),
    ?assertEqual("xyz",
        xl_string:substitute("x{a}z{b}", [{a, "y"}])),
    ?assertEqual("xy",
        xl_string:substitute("x{a.b}", [{'a.b', "y"}])),
    ?assertEqual("xyz{}",
        xl_string:substitute("x{a}z{}", [{a, "y"}])).

equal_ignore_case_test() ->
    ?assert(xl_string:equal_ignore_case(<<"A">>, <<"a">>)),
    ?assert(xl_string:equal_ignore_case("A", "a")),
    ?assert(xl_string:equal_ignore_case(<<"A">>, "a")),
    ?assert(xl_string:equal_ignore_case("A", <<"a">>)).

join_test() ->
    ?assertEqual(<<"aaa;bbb;ccc">>,
        xl_string:join([<<"aaa">>, "bbb", <<"ccc">>], <<";">>)),
    ?assertEqual("aaa;bbb;ccc",
        xl_string:join([<<"aaa">>, "bbb", <<"ccc">>], ";")),
    ?assertEqual("aaabbbccc",
        xl_string:join([<<"aaa">>, "bbb", <<"ccc">>])).

join_performance_test() ->
    MixedStrings = ["a", 1, "b", 2.3, c, "a", 1, "b", 2.3, c, "a", 1, "b", 2.3, c],
    MixedBinaries = [<<"a">>, 1, <<"b">>, 2.3, c, <<"a">>, 1, <<"b">>, 2.3, c, <<"a">>, 1, <<"b">>, 2.3, c],
    Strings = ["a", "b", "a", "b", "a", "b"],
    Binaries = [<<"a">>, <<"b">>, <<"a">>, <<"b">>, <<"a">>, <<"b">>],
    MixedStringsXps = xl_eunit:performance("mixed strings", fun(_) ->
        xl_string:join(MixedStrings, "")
    end, 10000),
    MixedBinariesXps = xl_eunit:performance("mixed binaries", fun(_) ->
        xl_string:join(MixedBinaries, <<"">>)
    end, 10000),
    StringsXps = xl_eunit:performance("strings", fun(_) ->
        xl_string:join(Strings, "")
    end, 10000),
    BinariesXps = xl_eunit:performance("binaries", fun(_) ->
        xl_string:join(Binaries, <<"">>)
    end, 10000),
    ?assert(MixedBinariesXps > MixedStringsXps),
    ?assert(BinariesXps < StringsXps).

unquote_test() ->
    ?assertEqual("aaa\"a", xl_string:unquote("\"aaa\\\"a\"")).

replace_test() ->
    ?assertEqual("abeabe", xl_string:replace("abcdeabcde", "cd", "")).

-record(r, {a, b, c}).
format_record_test() ->
    R = #r{a = 1, b = 2, c = c},
    ?assertEqual("#r{a = 1, b = 2, c = c}", ?FORMAT_RECORD(R, r)).
