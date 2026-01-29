%%%-------------------------------------------------------------------
%% @doc my_test_app public API
%% @end
%%%-------------------------------------------------------------------

-module(my_test_app_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    my_test_app_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
