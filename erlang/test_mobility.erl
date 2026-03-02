-module(test_mobility).
-export([main/0]).

%% ---------------------------------------------------------------------------
%% CHANNEL MOBILITY
%% In Go, channels can be sent through other channels.
%% This works for both synchronous and asynchronous (buffered) channels.
%% ---------------------------------------------------------------------------

%% Test 1: Mobility with synchronous channels

test_mobility_sync_worker(Id, RequestChan, Parent) ->
    %% Create a response channel (synchronous)
    ResponseChan = goencoding:sync_new(),

    %% Send our response channel through the request channel
    io:format("[mobility-sync] Worker ~p: sending response channel~n", [Id]),
    goencoding:sync_send(RequestChan, ResponseChan),

    %% Wait for result on our response channel
    {ok, Result} = goencoding:sync_recv(ResponseChan),
    io:format("[mobility-sync] Worker ~p: received result ~p~n", [Id, Result]),

    Parent ! {done, sync_worker}.

test_mobility_sync_server(RequestChan, Parent) ->
    %% Receive a response channel from a worker
    {ok, ResponseChan} = goencoding:sync_recv(RequestChan),
    io:format("[mobility-sync] Server: received response channel from worker~n"),

    %% Send result back through the received channel
    Result = 42,
    io:format("[mobility-sync] Server: sending result ~p through received channel~n", [Result]),
    goencoding:sync_send(ResponseChan, Result),

    Parent ! {done, sync_server}.

test_mobility_sync() ->
    %% Channel that carries channels! (synchronous)
    RequestChan = goencoding:sync_new(),
    Parent = self(),

    io:format("[mobility-sync] Starting worker...~n"),
    spawn(fun() -> test_mobility_sync_worker(1, RequestChan, Parent) end),

    io:format("[mobility-sync] Starting server...~n"),
    spawn(fun() -> test_mobility_sync_server(RequestChan, Parent) end),

    %% Wait for both to complete
    receive {done, sync_worker} -> ok end,
    receive {done, sync_server} -> ok end,

    io:format("[mobility-sync] Done!~n").

%% Test 2: Mobility with asynchronous (buffered) channels

test_mobility_async_worker(Id, RequestChan, Parent) ->
    %% Create a response channel (asynchronous with buffer)
    ResponseChan = goencoding:async_new(2),

    %% Send our response channel through the request channel
    io:format("[mobility-async] Worker ~p: sending response channel~n", [Id]),
    goencoding:sync_send(RequestChan, ResponseChan),

    %% Wait for result on our response channel
    {ok, Result} = goencoding:async_recv(ResponseChan),
    io:format("[mobility-async] Worker ~p: received result ~p~n", [Id, Result]),

    Parent ! {done, async_worker}.

test_mobility_async_server(RequestChan, Parent) ->
    %% Receive a response channel from a worker
    {ok, ResponseChan} = goencoding:sync_recv(RequestChan),
    io:format("[mobility-async] Server: received response channel from worker~n"),

    %% Send result back through the received channel (won't block due to buffer)
    Result = 99,
    io:format("[mobility-async] Server: sending result ~p through received channel~n", [Result]),
    goencoding:async_send(ResponseChan, Result),

    Parent ! {done, async_server}.

test_mobility_async() ->
    %% Channel that carries channels! (synchronous carrier, but carries async channels)
    RequestChan = goencoding:sync_new(),
    Parent = self(),

    io:format("[mobility-async] Starting worker...~n"),
    spawn(fun() -> test_mobility_async_worker(1, RequestChan, Parent) end),

    io:format("[mobility-async] Starting server...~n"),
    spawn(fun() -> test_mobility_async_server(RequestChan, Parent) end),

    %% Wait for both to complete
    receive {done, async_worker} -> ok end,
    receive {done, async_server} -> ok end,

    io:format("[mobility-async] Done!~n").

%% ---------------------------------------------------------------------------
%% MAIN
%% ---------------------------------------------------------------------------

main() ->
    io:format("--- Mobility ---~n"),

    io:format("~n------ Mobility 1: Synchronous ------~n"),
    test_mobility_sync(),

    io:format("~n------ Mobility 2: Asynchronous ------~n"),
    test_mobility_async(),

    io:format("--- End Mobility ---~n~n").