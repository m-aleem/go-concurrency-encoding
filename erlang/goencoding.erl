%% goencoding.erl

-module(goencoding).
-export([sync_new/0, sync_send/2, sync_recv/1, sync_close/1,
         async_new/1, async_send/2, async_recv/1, async_close/1]).

%% ---------------------------------------------------------------------------
%% SYNCHRONOUS CHANNELS
%% ---------------------------------------------------------------------------

%% sync_new() -> ChannelPid
%% Creates a new synchronous channel (like Go's make(chan T))
%% Returns: Pid of the channel process
sync_new() ->
    spawn(fun() -> sync_channel_loop(none, false) end).

%% Internal Channel Process for Synchronous Channels
%% ChannelState can be:
%%   none - no one waiting
%%   {waiting_sender, SenderPid, Msg} - sender blocked waiting for receiver
%%   {waiting_receiver, RecvPid} - receiver blocked waiting for sender
%% Closed is a boolean indicating if channel is closed

sync_channel_loop(ChannelState, Closed) ->
    receive
        {send, SenderPid, Msg} ->
            if
                Closed ->
                    %% Send on closed channel - notify sender of error
                    SenderPid ! {error, closed},
                    sync_channel_loop(ChannelState, Closed);
                true ->
                    case ChannelState of
                        none ->
                            %% No receiver waiting, sender blocks
                            sync_channel_loop({waiting_sender, SenderPid, Msg}, Closed);
                        {waiting_receiver, RecvPid} ->
                            %% Receiver waiting! Rendezvous
                            RecvPid ! {ok, Msg},
                            SenderPid ! ok,
                            sync_channel_loop(none, Closed)
                    end
            end;

        {recv, RecvPid} ->
            case ChannelState of
                none ->
                    if
                        Closed ->
                            %% No sender waiting and channel closed
                            RecvPid ! closed,
                            sync_channel_loop(ChannelState, Closed);
                        true ->
                            %% No sender waiting, receiver blocks
                            sync_channel_loop({waiting_receiver, RecvPid}, Closed)
                    end;
                {waiting_sender, SenderPid, Msg} ->
                    %% Sender waiting! Rendezvous
                    RecvPid ! {ok, Msg},
                    SenderPid ! ok,
                    sync_channel_loop(none, Closed)
            end;

        close_channel ->
            %% Mark channel as closed
            case ChannelState of
                {waiting_receiver, RecvPid} ->
                    %% Notify waiting receiver that channel is closed
                    RecvPid ! closed,
                    sync_channel_loop(none, true);
                _ ->
                    %% Invalid ChannelState for close (e.g. sender waiting) - just mark closed
                    sync_channel_loop(ChannelState, true)
            end
    end.

%% sync_send(ChannelPid, Msg) -> ok | {error, closed}
%% Sends a message on the channel (like Go's ch <- msg)
%% Blocks until a receiver is ready to receive
sync_send(ChannelPid, Msg) ->
    ChannelPid ! {send, self(), Msg},
    receive
        ok -> ok;
        {error, closed} -> {error, closed}
    end.

%% sync_recv(ChannelPid) -> {ok, Msg} | closed
%% Receives a message from the channel (like Go's msg := <-ch)
%% Blocks until a sender is ready to send
%% Returns: {ok, Msg} if successful, 'closed' if channel is closed
sync_recv(ChannelPid) ->
    ChannelPid ! {recv, self()},
    receive
        {ok, Msg} -> {ok, Msg};
        closed -> closed
    end.

%% sync_close(ChannelPid) -> ok
%% Closes the channel (like Go's close(ch))
%% From https://go.dev/tour/concurrency/4:
%% Note: Only the sender should close a channel, never the receiver.
sync_close(ChannelPid) ->
    ChannelPid ! close_channel,
    ok.

%% ---------------------------------------------------------------------------
%% ASYNCHRONOUS (BUFFERED) CHANNELS
%% ---------------------------------------------------------------------------

%% async_new(Capacity) -> ChannelPid
%% Creates a new asynchronous (buffered) channel (like Go's make(chan T, capacity))
%% Capacity: maximum number of messages that can be buffered
%% Returns: Pid of the channel process
async_new(Capacity) ->
    spawn(fun() -> async_channel_loop(queue:new(), Capacity, [], false) end).

%% Internal Channel Process for Asynchronous Channels
%% Buffer: queue of buffered messages
%% Capacity: maximum buffer size
%% WaitingReceivers: list of receiver PIDs waiting for messages
%% Closed: boolean indicating if channel is closed

async_channel_loop(Buffer, Capacity, WaitingReceivers, Closed) ->
    BufferSize = queue:len(Buffer),
    receive
        {send, SenderPid, Msg} ->
            if
                Closed ->
                    %% Send on closed channel - notify sender of error
                    SenderPid ! {error, closed},
                    async_channel_loop(Buffer, Capacity, WaitingReceivers, Closed);
                true ->
                    case WaitingReceivers of
                        [RecvPid | RestReceivers] ->
                            %% Receiver waiting! Send directly (bypass buffer)
                            RecvPid ! {ok, Msg},
                            SenderPid ! ok,
                            async_channel_loop(Buffer, Capacity, RestReceivers, Closed);
                        [] ->
                            if
                                BufferSize < Capacity ->
                                    %% Buffer has space, accept message immediately
                                    NewBuffer = queue:in(Msg, Buffer),
                                    SenderPid ! ok,
                                    async_channel_loop(NewBuffer, Capacity, WaitingReceivers, Closed);
                                true ->
                                    %% Buffer full, sender must block
                                    %% Store sender in waiting state
                                    async_channel_loop_waiting_sender(
                                        Buffer, Capacity, WaitingReceivers, Closed, SenderPid, Msg)
                            end
                    end
            end;

        {recv, RecvPid} ->
            case queue:out(Buffer) of
                {{value, Msg}, NewBuffer} ->
                    %% Message in buffer, deliver it
                    RecvPid ! {ok, Msg},
                    async_channel_loop(NewBuffer, Capacity, WaitingReceivers, Closed);
                {empty, _} ->
                    if
                        Closed ->
                            %% Buffer empty and channel closed
                            RecvPid ! closed,
                            async_channel_loop(Buffer, Capacity, WaitingReceivers, Closed);
                        true ->
                            %% Buffer empty, receiver must wait
                            NewWaitingReceivers = WaitingReceivers ++ [RecvPid],
                            async_channel_loop(Buffer, Capacity, NewWaitingReceivers, Closed)
                    end
            end;

        close_channel ->
            %% Mark channel as closed, notify all waiting receivers
            lists:foreach(fun(RecvPid) -> RecvPid ! closed end, WaitingReceivers),
            async_channel_loop(Buffer, Capacity, [], true)
    end.

%% Helper state: sender waiting because buffer is full
async_channel_loop_waiting_sender(Buffer, Capacity, WaitingReceivers, Closed, SenderPid, Msg) ->
    receive
        {recv, RecvPid} ->
            %% Receiver arrived! Can now accept the blocked sender's message
            RecvPid ! {ok, Msg},
            SenderPid ! ok,
            async_channel_loop(Buffer, Capacity, WaitingReceivers, Closed);

        close_channel ->
            %% Channel closed while sender waiting
            SenderPid ! {error, closed},
            lists:foreach(fun(RecvPid) -> RecvPid ! closed end, WaitingReceivers),
            async_channel_loop(Buffer, Capacity, [], true)
    end.

%% async_send(ChannelPid, Msg) -> ok | {error, closed}
%% Sends a message on the buffered channel (like Go's ch <- msg)
%% Does not block if buffer has space; blocks if buffer is full
async_send(ChannelPid, Msg) ->
    ChannelPid ! {send, self(), Msg},
    receive
        ok -> ok;
        {error, closed} -> {error, closed}
    end.

%% async_recv(ChannelPid) -> {ok, Msg} | closed
%% Receives a message from the buffered channel (like Go's msg := <-ch)
%% Does not block if buffer has messages; blocks if buffer is empty
%% Returns: {ok, Msg} if successful, 'closed' if channel is closed and empty
async_recv(ChannelPid) ->
    ChannelPid ! {recv, self()},
    receive
        {ok, Msg} -> {ok, Msg};
        closed -> closed
    end.

%% async_close(ChannelPid) -> ok
%% Closes the buffered channel (like Go's close(ch))
%% From https://go.dev/tour/concurrency/4:
%% Note: Only the sender should close a channel, never the receiver.
async_close(ChannelPid) ->
    ChannelPid ! close_channel,
    ok.

%% ---------------------------------------------------------------------------
%% CHANNEL MOBILITY
%% ---------------------------------------------------------------------------

%% In our Erlang encoding, channels are represented as PIDs therefore channel
%% mobility is inherently supported without any special handling. You can send
%% a channel as follows:
%%
%% Example:
%%   Ch1 = sync_new(),           % Create first channel
%%   Ch2 = sync_new(),           % Create second channel
%%   sync_send(Ch1, Ch2),        % Send Ch2 through Ch1
%%   {ok, ReceivedCh} = sync_recv(Ch1),  % Receive the channel
%%   sync_send(ReceivedCh, 42),  % Use the received channel
%%
%% This works for both sync_* and async_* channel functions.