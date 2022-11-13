-module(aoc@invoke_ffi).

-export([
    do_ensure_loaded/1,
    find_files/2,
    promise_of/1,
    map/2,
    await/1
]).

-spec do_ensure_loaded(atom()) -> boolean().
do_ensure_loaded(Module) ->
    case erlang:module_loaded(Module) of
        true -> true;
        false -> case code:ensure_loaded(Module) of
            {module, _Module} -> true;
            {error, _Error} -> false
        end
    end.

-spec find_files(binary(), binary()) -> list(binary()).
find_files(Pattern, In) ->
    Results = filelib:wildcard(binary_to_list(Pattern), binary_to_list(In)),
    lists:map(fun list_to_binary/1, Results).

% -------- %
% Promises %
% -------- %

-type result(Result, Error) :: {ok, Result} | {error, Error}.
-type worker_fun(Result, Error) :: fun(() -> result(Result, Error)).
-type promise(_Result, _Error) :: pid().

-spec promise_of(worker_fun(Result, Error)) -> promise(Result, Error).
promise_of(Worker) ->
    spawn(fun() ->
        Result = case Worker of
            _ when is_function(Worker) -> Worker();
            {M, F, A} -> erlang:apply(M, F, A)
        end,
        respond(Result)
    end).

-spec respond(any()) -> no_return().
respond(Result) ->
    receive
        {get, Pid, Ref} -> Pid ! {Ref, Result};
        {then, {WorkerProcess, WorkerRef}, WorkerFactory} -> WorkerProcess ! {WorkerRef, fun () ->
            case WorkerFactory of
                _ when is_function(WorkerFactory) -> WorkerFactory(Result);
                {M, F, A} -> erlang:apply(M, F, A ++ [Result])
            end
        end}
    end,
    respond(Result).

-spec worker(reference()) -> pid().
worker(Ref) ->
    spawn(fun () ->
        Result = receive
            {Ref, Func} when is_function(Func) -> Func()
        end,
        respond(Result)
    end).

-spec map(promise(Result1, Error1), fun((result(Result1, Error1)) -> worker_fun(Result2, Error2))) -> promise(Result2, Error2).
map(Promise, FunctionFactory) ->
    Ref = erlang:make_ref(),
    Pid = worker(Ref),
    Promise ! {then, {Pid, Ref}, FunctionFactory},
    Pid.

-spec await(promise(Result, Error)) -> result(Result, Error).
await(Worker) ->
    Ref = erlang:make_ref(),
    Worker ! {get, self(), Ref},
    receive
        {Ref, Result} -> Result
    end.
