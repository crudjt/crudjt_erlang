-module(crudjt_erlang_loader).
-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    Deps = [
        cowboy, cowlib, crudjt, flow, gen_stage, googleapis,
        grpc, gun, hpax, jason, mint, msgpax, protobuf,
        ranch, rustler, telemetry, toml
    ],
    lists:foreach(fun(A) ->
        catch application:ensure_all_started(A)
    end, Deps),
    {ok, self()}.

stop(_State) -> ok.
