# erlang

## Running tests

1) Compile the program: `erlc goencoding.erl test_sync.erl test_async.erl test_mobility.erl test.erl`
2) Run: `erl -noshell -s test main -s init stop`