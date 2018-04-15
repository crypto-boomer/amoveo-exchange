%we are waiting for a confirmed veo tx to know that the customer has funded their side of the trade.

-module(unconfirmed_veo).
-behaviour(gen_server).
-export([start_link/0,code_change/3,handle_call/3,handle_cast/2,handle_info/2,init/1,terminate/2,
	 read/1, trade/2, 
	 confirm/1, %attempts to confirm a single trade.
	 test/0]).
-include("records.hrl").
init(ok) -> {ok, dict:new()}.
start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, ok, []).
code_change(_OldVsn, State, _Extra) -> {ok, State}.
terminate(_, _) -> io:format("died!"), ok.
handle_info(_, X) -> {noreply, X}.
handle_cast({trade, Trade, TID}, X) -> 
    X2 = dict:store(TID, Trade, X),
    id_lookup:add_veo(TID),
    {noreply, X2};
handle_cast(_, X) -> {noreply, X}.
handle_call({erase, TID}, _From, X) -> 
    Y = dict:erase(TID, X),
    {reply, Y, X};
handle_call({read, TID}, _From, X) -> 
    Y = dict:find(TID, X),
    {reply, Y, X};
handle_call(_, _From, X) -> {reply, X, X}.

read(TID) ->
    gen_server:call(?MODULE, {read, TID}).
trade(Trade, TID) ->%adds a new trade to the gen_server's memory.
    gen_server:cast(?MODULE, {trade, Trade, TID}).
confirm(TID) ->
    Fee = config:fee(veo),
    {ok, Trade} = read(TID),
    VA = Trade#trade.veo_address,
    TA = Trade#trade.veo_amount + Fee,
    B = balance_veo:read(VA),
    if
	(B < TA) -> ok;
	true -> 
	    id_lookup:confirm(TID),
	    balance_veo:remove(TA, VA),
	    io:fwrite("removing trade\n"),
	    gen_server:cast(?MODULE, {erase, TID})
%remove(TID)
    end.

test() ->
    VA = base64:decode(<<"BGRv3asifl1g/nACvsJoJiB1UiKU7Ll8O1jN/VD2l/rV95aRPrMm1cfV1917dxXVERzaaBGYtsGB5ET+4aYz7ws=">>),
    TID = crypto:strong_rand_bytes(32),
    Trade = #trade{veo_address = VA, veo_amount = 500000, bitcoin_amount = 10000},
    trade(Trade, TID),
    timer:sleep(100),
    {ok, Trade} = read(TID),
    io:fwrite("balance before trade confirms"),
    io:fwrite(packer:pack(balance_veo:read(VA))),%10.000.000
    io:fwrite("\n"),
    confirm(TID),
    io:fwrite("balance after trade confirms"),
    io:fwrite(packer:pack(balance_veo:read(VA))),%2.500.000
    io:fwrite("\n"),
    io:fwrite(packer:pack(id_lookup:read(TID))),%unmatched
    success.
    
