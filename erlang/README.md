# erlang

## Running tests

Compile the program:
```terminal
erlc goencoding.erl test_sync.erl test_async.erl test_mobility.erl test_close.erl test_typing.erl test.erl
```

Run:
```terminal
erl -noshell -s test main -s init stop
```

Then, select one of the following options:

1. Sync Test
2. Async Test
3. Mobility Test
4. Close (Panic) Test
5. Typing Tests
6. All Tests