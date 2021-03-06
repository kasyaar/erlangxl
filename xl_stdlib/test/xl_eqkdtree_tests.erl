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
-module(xl_eqkdtree_tests).
-author("volodymyr.kyrychenko@strikead.com").

-include_lib("eunit/include/eunit.hrl").
-include("xl_eunit.hrl").

generate_points(PlaneSizes, Count) ->
    Planes = lists:map(fun(Size) -> lists:seq(1, Size) end, PlaneSizes),
    [list_to_tuple([element(2, xl_lists:random(P)) || P <- Planes] ++ [V]) || V <- lists:seq(1, Count)].

generate_planes(Variabililty, Count) ->
    [element(2, xl_lists:random(Variabililty)) || _ <- lists:seq(1, Count)].

new_test() ->
    xl_application:start(xl_stdlib),
    Points = [{1, c, c}, {1, b, b}, {3, a, a}, {2, c, c}, {1, b, b}, {3, a, a}, {2, c, c}, {1, b, b}, {3, a, a}, {2, c, c}],
    Compare = fun(_Plane, X, Y) -> xl_lists:compare(X, Y) end,
    ExpectedTree = {xl_eqkdtree,
        {2, 1,
            {b, 2,
                undefined,
                {1, 1,
                    undefined,
                    {ok, [b, b, b]},
                    undefined
                },
                {1, 1,
                    undefined,
                    {c, 2,
                        undefined,
                        {ok, [c]},
                        undefined
                    },
                    undefined
                }
            },
            {c, 2,
                undefined,
                {ok, [c, c, c]},
                undefined
            },
            {a, 2,
                undefined,
                {3, 1,
                    undefined,
                    {ok, [a, a, a]},
                    undefined
                },
                undefined
            }
        }, [{compare, Compare}]},
    ?assertEquals(ExpectedTree, xl_eqkdtree:new(Points, [{compare, Compare}])).

new_performance_test_() ->
    xl_application:start(xl_stdlib),

    {timeout, 2000, fun() ->
%%         xl_lists:times(fun(X) ->
%%             Count = X*20,
%%             xl_eunit:format("~p ~p~n", [Count, erts_debug:size(xl_eqkdtree:new(generate_points([100, 10, 100, 10, 100, 10, 10, 10, 10, 10, 100, 10, 10, 10, 10], Count), undefined))])
%%         end, 10),
        xl_eunit:performance(eqkdtree, fun() ->
            Planes = generate_planes([100, 50, 10], 10),
            TotalPoints = 1000,
            Points = generate_points(Planes, TotalPoints),
            UniquePoints = xl_lists:count_unique(Points),
            {Time, Tree} = timer:tc(xl_eqkdtree, new, [Points]),
            xl_eunit:format("planes: ~p:~p\t\t\tpoints: ~p\tunique: ~p\tsize: ~p\tdepth: ~p\tconstruction time: ~p mcs~n", [
                length(Planes),
                list_to_tuple(Planes),
                TotalPoints,
                length(UniquePoints),
                xl_eqkdtree:size(Tree),
                xl_eqkdtree:depth(Tree),
                Time
            ])
        end, 5)
    end}.

find_test_() ->
    {timeout, 2000, fun() ->
        Planes = generate_planes([100, 50, 10], 10),
        TotalPoints = 10000,
        Points = generate_points(Planes, TotalPoints),
        UniquePoints = xl_lists:count_unique(Points),
        Tree = xl_eqkdtree:new(Points),
        xl_eunit:format("planes: ~p:~p\t\t\tpoints: ~p\tunique: ~p\tsize: ~p\tdepth: ~p~n", [
            length(Planes),
            list_to_tuple(Planes),
            TotalPoints,
            length(UniquePoints),
            xl_eqkdtree:size(Tree),
            xl_eqkdtree:depth(Tree)
        ]),
        KeyTuple = fun(T) -> list_to_tuple(element(1, lists:split(tuple_size(T) - 1, tuple_to_list(T)))) end,
        PointsToFind = [KeyTuple(P) || _ <- lists:seq(1, 10), P <- [element(2, xl_lists:random(Points))]],
        Results = [
            {RP, lists:map(
                fun(T) -> element(tuple_size(T), T) end,
                lists:filter(fun(P) -> KeyTuple(P) == RP end, Points)
            )} || RP <- PointsToFind
        ],
        xl_lists:times(fun() ->
            {ok, P} = xl_lists:random(PointsToFind),
            Expected = xl_lists:kvfind(P, Results),
            xl_eunit:performance(eqkdtree_find, fun() ->
                ?assertEquals(Expected, xl_eqkdtree:find(P, Tree))
            end, 10000)
        end, 10)
    end}.

