-module(test_sync).
-export([main/0]).

%% ---------------------------------------------------------------------------
%% SYNCHRONOUS COMMUNICATION
%% From https://go.dev/tour/concurrency/2: By default, sends and receives
%% block until the other side is ready. This allows goroutines to synchronize
%% without explicit locks or condition variables.
%% ---------------------------------------------------------------------------

test_sync_sender(Ch, Msgs) ->
    test_sync_sender(Ch, Msgs, 0).

test_sync_sender(Ch, Msgs, I) when I < Msgs ->
    goencoding:sync_send(Ch, I), % blocks until receiver is ready
    io:format("[sync] Sender sent: ~p~n", [I]),
    test_sync_sender(Ch, Msgs, I + 1);
test_sync_sender(Ch, _Msgs, _I) ->
    goencoding:sync_close(Ch). % signal "no more values"

test_sync_sender_no_close(Ch, Msgs) ->
    test_sync_sender_no_close(Ch, Msgs, 0).

test_sync_sender_no_close(_Ch, Msgs, I) when I >= Msgs ->
    ok;
test_sync_sender_no_close(Ch, Msgs, I) ->
    goencoding:sync_send(Ch, I), % blocks until receiver is ready
    io:format("[sync] Sender sent: ~p~n", [I]),
    test_sync_sender_no_close(Ch, Msgs, I + 1).

test_sync_receiver(Ch) ->
    case goencoding:sync_recv(Ch) of % loops until channel is closed
        {ok, Msg} ->
            timer:sleep(100), % simulate slow processing
            io:format("[sync] Receiver got: ~p~n", [Msg]),
            test_sync_receiver(Ch);
        closed ->
            io:format("[sync] Receiver: channel closed, no more messages, done receiving~n")
    end.

test_one_sender() ->
    Ch = goencoding:sync_new(),
    Parent = self(),

    io:format("[sync] Spawned receiver goroutine...~n"),
    spawn(fun() ->
        test_sync_receiver(Ch),
        Parent ! {done, receiver}
    end),

    %timer:sleep(100), % Ensure receiver is ready before sender starts

    io:format("[sync] Spawned sender goroutine...~n"),
    spawn(fun() ->
        test_sync_sender(Ch, 1), % send 1 message
        Parent ! {done, sender}
    end),

    % Wait for both to complete
    receive {done, receiver} -> ok end,
    receive {done, sender} -> ok end.

test_sync_multiple_blocked_senders() ->
    Ch = goencoding:sync_new(),
    Parent = self(),

    spawn(fun() ->
        test_sync_receiver(Ch),
        Parent ! {done, receiver}
    end),

    spawn(fun() ->
        test_sync_sender_no_close(Ch, 1),
        Parent ! {done, sender1}
    end),

    spawn(fun() ->
        test_sync_sender_no_close(Ch, 1),
        Parent ! {done, sender2}
    end),

    spawn(fun() ->
        test_sync_sender_no_close(Ch, 1),
        Parent ! {done, sender3}
    end),


    receive {done, sender1} -> ok end,
    receive {done, sender2} -> ok end,
    receive {done, sender3} -> ok end,
    goencoding:sync_close(Ch),
    receive {done, receiver} -> ok end.

%test_sync_right_type() ->
%    Ch = goencoding:sync_new(fun is_integer/1), % channel of integers only
%    Parent = self(),
%
%    spawn(fun() ->
%        test_sync_receiver(Ch),
%        Parent ! {done, receiver}
%    end),
%
%    spawn(fun() ->
%        Result =
%            try
%                goencoding:sync_send(Ch, 42),
%                ok
%            catch
%                Class:Reason ->
%                    io:format("[sync] Expected type error: ~p:~p~n", [Class, Reason]),
%                    {error, Class, Reason}
%            end,
%        Parent ! {done, sender, Result}
%    end),
%
%    receive {done, sender, Result} -> io:format("[sync] Sender finished: ~p~n", [Result]) end,
%    goencoding:sync_close(Ch),
%    receive {done, receiver} -> ok end.
%
%test_sync_wrong_type() ->
%    Ch = goencoding:sync_new(fun is_integer/1), % channel of integers only
%    Parent = self(),
%
%    spawn(fun() ->
%        test_sync_receiver(Ch),
%        Parent ! {done, receiver}
%    end),
%
%    spawn(fun() ->
%        Result =
%            try
%                goencoding:sync_send(Ch, "not an integer"),
%                ok
%            catch
%                Class:Reason ->
%                    io:format("[sync] Expected type error: ~p:~p~n", [Class, Reason]),
%                    {error, Class, Reason}
%            end,
%        Parent ! {done, sender, Result}
%    end),
%
%    receive {done, sender, Result} -> io:format("[sync] Sender finished: ~p~n", [Result]) end,
%    goencoding:sync_close(Ch),
%    receive {done, receiver} -> ok end.
%
%test_sync_any_type() ->
%    Ch = goencoding:sync_new(), % generic channel, no type checking
%    Parent = self(),
%
%    spawn(fun() ->
%        test_sync_receiver(Ch),
%        Parent ! {done, receiver}
%    end),
%
%    spawn(fun() ->
%        Result =
%            try
%                goencoding:sync_send(Ch, "sending a string"),
%                goencoding:sync_send(Ch, 12345),
%                ok
%            catch
%                Class:Reason ->
%                    io:format("[sync] Expected type error: ~p:~p~n", [Class, Reason]),
%                    {error, Class, Reason}
%            end,
%        Parent ! {done, sender, Result}
%    end),
%
%    receive {done, sender, Result} -> io:format("[sync] Sender finished: ~p~n", [Result]) end,
%    goencoding:sync_close(Ch),
%    receive {done, receiver} -> ok end.
%

%% ---------------------------------------------------------------------------
%% MAIN
%% ---------------------------------------------------------------------------

main() ->
	io:format("~n--- Synchronous tests ---~n"),

	io:format("------ Sync 1: Send on an open channel (one sender, one receiver) ------~n"),
	test_one_sender(),

	io:format("~n------ Sync 2: Send on an open channel (multiple senders, one receiver) ------~n"),
	test_sync_multiple_blocked_senders(),

    %io:format("~n--- Test right type ---~n"),
    %test_sync_right_type(),
    %io:format("~n--- Test wrong type ---~n"),
    %test_sync_wrong_type(),
    %io:format("~n--- Test any type ---~n"),
    %test_sync_any_type(),
    %io:format("~n--- End Synchronous tests ---~n").

	io:format("--- End Synchronous tests ---~n").
