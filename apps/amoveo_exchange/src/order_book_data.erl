-module(order_book_data).
-behaviour(gen_server).
-export([start_link/0,code_change/3,handle_call/3,handle_cast/2,handle_info/2,init/1,terminate/2,
	read/0,
	write/1]).
-include("records.hrl").
-define(LOC, config:file(?MODULE)).
init(ok) -> 
    process_flag(trap_exit, true),
    utils:init(#ob{}, ?LOC).
start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, ok, []).
code_change(_OldVsn, State, _Extra) -> {ok, State}.
terminate(_, X) -> 
    utils:save(X, ?LOC),
    io:format("order book data died!"), 
    ok.
handle_info(_, X) -> {noreply, X}.
handle_cast({write, X}, _) -> {noreply, X};
handle_cast(_, X) -> {noreply, X}.
handle_call(_, _From, X) -> {reply, X, X}.

read() -> gen_server:call(?MODULE, read).
write(X) -> gen_server:cast(?MODULE, {write, X}).
