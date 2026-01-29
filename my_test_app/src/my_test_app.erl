-module(my_test_app).
-export([main/1]).

main(_) ->
    AddPath = fun(Path) -> code:add_patha(Path) end,
    lists:foreach(AddPath, filelib:wildcard("_build/default/lib/*/ebin")),

    application:ensure_all_started(crudjt_erlang),

    'Elixir.CRUDJT.Config':start_master([
        {encrypted_key, <<"Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==">>},
        {store_jt_path, <<"path/to/local/storage">>},
        {grpc_port, 50051}
    ]),

    io:format("OS: ~p~n", [os:type()]),

    Arch = erlang:system_info(system_architecture),
    io:format("CPU: ~s~n", [Arch]),

    io:format("Checking without metadata...~n"),
    Data = #{<<"user_id">> => 42, <<"role">> => 11},
    ExpectedData = #{<<"data">> => Data},

    EdData = #{<<"user_id">> => 42, <<"role">> => 8},
    ExpectedEdData = #{<<"data">> => EdData},

    Token = 'Elixir.CRUDJT':create(Data),

    'Elixir.CRUDJT':read(Token),

    io:format("~p~n", ['Elixir.CRUDJT':read(Token) == ExpectedData]),
    io:format("~p~n", ['Elixir.CRUDJT':update(Token, EdData) == true]),
    io:format("~p~n", ['Elixir.CRUDJT':read(Token) == ExpectedEdData]),
    io:format("~p~n", ['Elixir.CRUDJT':delete(Token) == true]),
    io:format("~p~n", ['Elixir.CRUDJT':read(Token) == nil]),

    io:format("Checking ttl~n"),
    Ttl = 5,
    TokenWithTtl = 'Elixir.CRUDJT':create(Data, Ttl),
    loop_ttl(TokenWithTtl, Ttl, Data),

    io:format("When expired ttl~n"),
    TtlExpired = 1,
    TokenExpired = 'Elixir.CRUDJT':create(Data, TtlExpired),
    timer:sleep(timer:seconds(TtlExpired)),
    io:format("~p~n", ['Elixir.CRUDJT':read(TokenExpired) == nil]),
    io:format("~p~n", ['Elixir.CRUDJT':update(TokenExpired, Data) == false]),
    io:format("~p~n", ['Elixir.CRUDJT':delete(TokenExpired) == false]),

    io:format("Checking silence_read~n"),
    Silence_read = Ttl,
    TokenWithSilence_read = 'Elixir.CRUDJT':create(Data, nil, Silence_read),
    loop_silence_read(TokenWithSilence_read, Silence_read, Data),

    io:format("Checking ttl and silence_read~n"),
    ValueWithBoth = 'Elixir.CRUDJT':create(Data, Ttl, Silence_read),
    loop_asdf_qwerty(ValueWithBoth, Ttl, Silence_read, Data),
    io:format("~p~n", ['Elixir.CRUDJT':read(TokenWithSilence_read) == nil]),

    io:format("Checking scale load~n"),
    Requests = 40000,
    ScaleData = #{
        <<"user_id">> => 414243,
        <<"role">> => 11,
        <<"devices">> => #{
            <<"ios_expired_at">> => <<"2025-02-18 20:41:59 +0200">>,
            <<"android_expired_at">> => <<"2025-02-18 20:41:59 +0200">>,
            <<"mobile_app_expired_at">> => <<"2025-02-18 20:41:59 +0200">>,
            <<"external_api_integration_expired_at">> => <<"2025-02-18 20:41:59 +0200">>
        },
        <<"a">> => 42
    },

    benchmark(Requests, ScaleData).

    %%%%%%%%
    loop_ttl(_, 0, _) -> ok;
loop_ttl(Value, N, Data) ->
    ExpectedTttl = N + 1,
    ExpectedResult = #{<<"metadata">> => #{<<"ttl">> => ExpectedTttl - 1}, <<"data">> => Data},
    io:format("~p~n", ['Elixir.CRUDJT':read(Value) == ExpectedResult]),
    timer:sleep(timer:seconds(1)),
    loop_ttl(Value, N - 1, Data).

loop_silence_read(_, 0, _) -> ok;
loop_silence_read(Value, N, Data) ->
    ExpectedResult = #{<<"metadata">> => #{<<"silence_read">> => N - 1}, <<"data">> => Data},
    io:format("~p~n", ['Elixir.CRUDJT':read(Value) == ExpectedResult]),
    loop_silence_read(Value, N - 1, Data).

loop_asdf_qwerty(_, 0, 0, _) -> ok;
loop_asdf_qwerty(Value, Ttl, Silence_read, Data) when Ttl >= 0, Silence_read >= 0 ->
    ExpectedTttl = Ttl + 1,
    ExpectedResult = #{<<"metadata">> => #{<<"ttl">> => ExpectedTttl - 1, <<"silence_read">> => Silence_read - 1}, <<"data">> => Data},
    io:format("~p~n", ['Elixir.CRUDJT':read(Value) == ExpectedResult]),
    timer:sleep(timer:seconds(1)),
    case {Ttl, Silence_read} of
        {0, 0} -> ok;
        _ -> loop_asdf_qwerty(Value, max(0, Ttl - 1), max(0, Silence_read - 1), Data)
    end.

    %%%%%%%%

    benchmark(Requests, ScaleData) -> benchmark(10, Requests, ScaleData).

    benchmark(0, _, _) -> ok;
    benchmark(N, Requests, ScaleData) ->
        {TimeQ, List} = timer:tc(fun() -> lists:foldl(fun(_, Acc) -> ['Elixir.CRUDJT':create(ScaleData) | Acc] end, [], lists:seq(1, Requests)) end),
        io:format("when creates 40k values with Turbo Queue: ~p seconds~n", [TimeQ / 1000000]),

        {TimeW, _} = timer:tc(fun() -> lists:foreach(fun(V) -> 'Elixir.CRUDJT':read(V) end, List) end),
        io:format("when reads 40k values: ~p seconds~n", [TimeW / 1000000]),

        {TimeE, _} = timer:tc(fun() -> lists:foreach(fun(V) -> 'Elixir.CRUDJT':update(V, ScaleData) end, List) end),
        io:format("when updates 40k values: ~p seconds~n", [TimeE / 1000000]),

        {TimeR, _} = timer:tc(fun() -> lists:foreach(fun(V) -> 'Elixir.CRUDJT':delete(V) end, List) end),
        io:format("when deletes 40k values: ~p seconds~n", [TimeR / 1000000]),

        benchmark(N - 1, Requests, ScaleData).
