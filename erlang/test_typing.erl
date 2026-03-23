-module(test_typing).
-export([main/0]).

%% ---------------------------------------------------------------------------
%% CHANNEL TYPING
%% Tests that typed channels (sync_new/1, async_new/2) enforce type
%% constraints on send, rejecting messages that don't match the predicate
%% with a {panic, {type_error, Msg}} recoverable via recover/1.
%% ---------------------------------------------------------------------------

%% --- Test 1: Sync typed channel accepts correct type ---
test_sync_typed_accept() ->
    Ch = goencoding:sync_new(fun is_integer/1),
    Parent = self(),
    spawn(fun() ->
        goencoding:sync_send(Ch, 42),
        Parent ! {done, sender}
    end),
    {ok, Msg} = goencoding:sync_recv(Ch),
    receive {done, sender} -> ok end,
    io:format("[typing] Sync accept integer 42: ~p~n", [Msg]).

%% --- Test 2: Sync typed channel rejects wrong type ---
test_sync_typed_reject() ->
    Ch = goencoding:sync_new(fun is_integer/1),
    Parent = self(),
    spawn(fun() ->
        Result = goencoding:recover(fun() -> goencoding:sync_send(Ch, "hello") end),
        Parent ! {done, Result}
    end),
    receive
        {done, {panic, {type_error, _}} = Err} ->
            io:format("[typing] Sync reject on int channel: ~p~n", [Err]);
        {done, Other} ->
            io:format("[typing] Sync reject UNEXPECTED: ~p~n", [Other])
    end.

%% --- Test 3: Sync typed channel rejects when receiver is already waiting ---
test_sync_typed_reject_with_waiting_receiver() ->
    Ch = goencoding:sync_new(fun is_atom/1),
    Parent = self(),
    %% Receiver starts first and blocks
    spawn(fun() ->
        Recv = goencoding:sync_recv(Ch),
        Parent ! {recv_result, Recv}
    end),
    timer:sleep(50), % ensure receiver is waiting
    %% Sender sends wrong type - should be rejected
    spawn(fun() ->
        Result = goencoding:recover(fun() -> goencoding:sync_send(Ch, 123) end),
        Parent ! {send_result, Result}
    end),
    receive
        {send_result, {panic, {type_error, _}} = Err} ->
            io:format("[typing] Sync reject on atom channel (receiver waiting): ~p~n", [Err]);
        {send_result, Other} ->
            io:format("[typing] Sync reject with waiting receiver UNEXPECTED: ~p~n", [Other])
    end,
    %% Clean up: send a valid value so the receiver unblocks
    spawn(fun() -> goencoding:sync_send(Ch, ok) end),
    receive {recv_result, _} -> ok end.

%% --- Test 4: Async typed channel accepts correct type ---
test_async_typed_accept() ->
    Ch = goencoding:async_new(3, fun is_atom/1),
    goencoding:async_send(Ch, hello),
    goencoding:async_send(Ch, world),
    {ok, V1} = goencoding:async_recv(Ch),
    {ok, V2} = goencoding:async_recv(Ch),
    io:format("[typing] Async accept atoms: ~p, ~p~n", [V1, V2]).

%% --- Test 5: Async typed channel rejects wrong type ---
test_async_typed_reject() ->
    Ch = goencoding:async_new(3, fun is_atom/1),
    Result = goencoding:recover(fun() -> goencoding:async_send(Ch, 123) end),
    case Result of
        {panic, {type_error, _}} ->
            io:format("[typing] Async reject on atom channel: ~p~n", [Result]);
        Other ->
            io:format("[typing] Async reject UNEXPECTED: ~p~n", [Other])
    end.

%% --- Test 6: Async typed channel rejects when receiver is waiting ---
test_async_typed_reject_with_waiting_receiver() ->
    Ch = goencoding:async_new(3, fun is_float/1),
    Parent = self(),
    %% Receiver starts first and blocks (buffer is empty)
    spawn(fun() ->
        Recv = goencoding:async_recv(Ch),
        Parent ! {recv_result, Recv}
    end),
    timer:sleep(50), % ensure receiver is waiting
    %% Sender sends wrong type
    Result = goencoding:recover(fun() -> goencoding:async_send(Ch, not_a_float) end),
    case Result of
        {panic, {type_error, _}} ->
            io:format("[typing] Async reject on float channel (receiver waiting): ~p~n", [Result]);
        Other ->
            io:format("[typing] Async reject with waiting receiver UNEXPECTED: ~p~n", [Other])
    end,
    %% Clean up: send a valid value so the receiver unblocks
    goencoding:async_send(Ch, 3.14),
    receive {recv_result, _} -> ok end.

%% --- Test 7: Untyped channels still accept anything ---
test_untyped_accepts_all() ->
    ChSync = goencoding:sync_new(),
    Parent = self(),
    spawn(fun() ->
        goencoding:sync_send(ChSync, {any, "term", 123, [list]}),
        Parent ! {done, sender}
    end),
    {ok, V1} = goencoding:sync_recv(ChSync),
    receive {done, sender} -> ok end,

    ChAsync = goencoding:async_new(3),
    goencoding:async_send(ChAsync, "string"),
    goencoding:async_send(ChAsync, 42),
    goencoding:async_send(ChAsync, {tuple, value}),
    {ok, V2} = goencoding:async_recv(ChAsync),
    {ok, V3} = goencoding:async_recv(ChAsync),
    {ok, V4} = goencoding:async_recv(ChAsync),
    io:format("[typing] Untyped sync accepted: ~p~n", [V1]),
    io:format("[typing] Untyped async accepted: ~p, ~p, ~p~n", [V2, V3, V4]).

%% --- Test 8: Type error is recoverable (does not kill process) ---
test_type_error_recoverable() ->
    Ch = goencoding:sync_new(fun is_integer/1),
    Parent = self(),
    spawn(fun() ->
        %% First send fails (wrong type), but process survives
        R1 = goencoding:recover(fun() -> goencoding:sync_send(Ch, "bad") end),
        %% Second send succeeds (correct type)
        R2 = goencoding:recover(fun() -> goencoding:sync_send(Ch, 99) end),
        Parent ! {results, R1, R2}
    end),
    timer:sleep(50),
    %% Only the valid send should come through
    {ok, 99} = goencoding:sync_recv(Ch),
    receive
        {results, {panic, {type_error, _}} = Err, {ok, ok}} ->
            io:format("[typing] Type error recoverable, process continued after reject: ~p~n", [Err]);
        {results, R1, R2} ->
            io:format("[typing] Recoverable UNEXPECTED: ~p, ~p~n", [R1, R2])
    end.

main() ->
    io:format("--- Typing ---~n~n"),

    io:format("------ Typing 1: Sync typed channel accepts correct type ------~n"),
    test_sync_typed_accept(),
    io:format("~n"),

    io:format("------ Typing 2: Sync typed channel rejects wrong type ------~n"),
    test_sync_typed_reject(),
    io:format("~n"),

    io:format("------ Typing 3: Sync typed reject with waiting receiver ------~n"),
    test_sync_typed_reject_with_waiting_receiver(),
    io:format("~n"),

    io:format("------ Typing 4: Async typed channel accepts correct type ------~n"),
    test_async_typed_accept(),
    io:format("~n"),

    io:format("------ Typing 5: Async typed channel rejects wrong type ------~n"),
    test_async_typed_reject(),
    io:format("~n"),

    io:format("------ Typing 6: Async typed reject with waiting receiver ------~n"),
    test_async_typed_reject_with_waiting_receiver(),
    io:format("~n"),

    io:format("------ Typing 7: Untyped channels accept anything ------~n"),
    test_untyped_accepts_all(),
    io:format("~n"),

    io:format("------ Typing 8: Type error is recoverable ------~n"),
    test_type_error_recoverable(),

    io:format("~n--- End Typing ---~n").
