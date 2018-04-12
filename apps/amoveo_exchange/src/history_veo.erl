%This is a record of all the payments that the server has received which have not yet received their bitcoin.
%It is storing spend transactions from the blockchain, not trades.

-module(history_veo).
-behaviour(gen_server).
-export([start_link/0,code_change/3,handle_call/3,handle_cast/2,handle_info/2,init/1,terminate/2,
	history/2, delete/2]).%do we really want to delete stuff?
-record(db, {height = -1, data = []}).
init(ok) -> {ok, []}.
start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, ok, []).
code_change(_OldVsn, State, _Extra) -> {ok, State}.
terminate(_, _) -> io:format("died!"), ok.
handle_info(_, X) -> {noreply, X}.
handle_cast({delete, Height, From}, X) -> 
    Data2 = delete_internal(Height, From, X#db.data),
    X2 = X#db{data = Data2},
    {noreply, X2};
handle_cast(_, X) -> {noreply, X}.
handle_call({history, Many, TopHeight}, _From, X) -> 
    %lazy update every time you look something up.
    H = X#db.height,
    D = max(0, TopHeight - H),
    Data = if
	       H =< TopHeight -> talker:talk({pubkey, config:pubkey(), D, TopHeight});
	       true -> []
	   end,
    Data2 = receives(Data),
    X2 = X#db{height = TopHeight, data = Data2 ++ X#db.data},
    H = history_after(D, Data),
    {reply, H, X2};
handle_call(_, _From, X) -> {reply, X, X}.


%% external functions
history(Many, TopHeight) ->
    if
	Many > 0 ->
	    gen_server:call(?MODULE, {history, Many, TopHeight});
	true -> ok
    end.
%After a payment has been used as part of a trade, we don't want to reuse that same payment for a different trade. So it needs to be removed from the history.
delete(Height, From) -> gen_server:cast(?MODULE, {delete, Height, From}).

%% internal functions
history_after(_, []) -> [];
history_after(D, [{Height, Tx}|T]) ->
    if
	Height > D -> [{Height, Tx}|history_after(D, T)];
	true -> []
    end.
receives([]) -> [];
receives([{Height, Tx}|T]) ->
    VB = config:spend_to(veo, Tx),
    VA = config:pubkey(),
    Fee = config:fee(veo)
    if
	((VA == VB) and 
	 (Fee =< config:veo_tx_amount(Tx))) -> %don't fill the ram with dust txs.
	    [{Height, Tx}];
	true -> []
    end,
    H ++ receives(T).

delete_internal(_, _, []) -> [];
delete_internal(Height, From, [{Height, Tx}|T]) ->
    Pub = config:spend_from(veo, Tx),
    A = if 
	    Pub == From -> [];
	    true -> [{Height, Tx}]
	end,
    A ++ delete_internal(Height, From, T);
delete_internal(Height, From, [{H2, Tx}|T]) when H2 > Height ->
    [{H2, Tx}|delete_internal(Height, From, T)];
delete_internal(_, _, T) -> T.