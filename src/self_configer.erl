%%%-------------------------------------------------------------------
%% @doc self configer
%% @end
%%%-------------------------------------------------------------------

-module(self_configer).
-behaviour(gen_statem).

-include_lib("kernel/include/logger.hrl").

%% apis
-export([child_spec/1, start_link/1, set_env/3, unset_env/2]).

%% callbacks
-export([terminate/3, code_change/4, init/1, callback_mode/0]).

%% the states
-export([clean/3, dirty/3]).

%% the data record to hold server state
-record(configer_data, { path :: string(),
			 map = #{} :: map() }).

%% apis
start_link([]) ->
    gen_statem:start_link({local, ?MODULE}, ?MODULE, [], []);
start_link([{name, Name}]) ->
    gen_statem:start_link({local, Name}, ?MODULE, [], []).

child_spec(Args) ->
    #{id => ?MODULE,
      start => {?MODULE, start_link, [Args]},
      type => worker}.

%% set_env to the Configer instance, return the Configer instance for chainning
-spec set_env(atom(), atom(), term()) -> atom().
set_env(Configer, Par, Val) ->
    application:set_env(app_of(Configer), Par, Val),
    gen_statem:cast(Configer, {set_env, Par, Val}),
    Configer.

%% unset_env to the Configer instance, return the Configer instance for chainning
-spec unset_env(atom(), atom()) -> atom().
unset_env(Configer, Par) ->
    application:unset_env(app_of(Configer), Par),
    gen_statem:cast(Configer, {unset_env, Par}),
    Configer.

app_of(Configer) ->
    case whereis(Configer) of
	undefined ->
	    error("Configer not found.", [Configer]);
	Pid  ->
	    case application:get_application(Pid) of
		undefined ->
		    error("Application not found.", [Configer]);
		App -> App
	    end
    end.

%% Mandatory callback functions
code_change(_Vsn, State, Data, _Extra) -> {ok, State, Data}.

init([]) ->
    Dir = default_dir(),
    case filelib:is_dir(Dir) of
	false ->
	    ?LOG_ERROR("Config dir ~ts is not found or not a directory", [Dir]),
	    error("Configer failed to boot");
	true -> ok
    end,
    {ok, App} = application:get_application(),
    Path = lists:flatten([Dir, $/, atom_to_list(App), ".config"]),
    Data = load(Path),
    ok = apply_to(App, Data),
    {ok, clean, Data}.

terminate(_Reason, clean, _Data) -> ok;
terminate(_Reason, dirty, Data) -> flush(Data).
  
callback_mode() -> state_functions.

%% state callbacks

clean(cast, {set_env, Par, Val}, Data) ->
    {next_state, dirty, update(Par, Val, Data), [{state_timeout, 5000, timeout}]};
clean(cast, {unset_env, Par}, Data) ->
    {next_state, dirty, remove(Par, Data), [{state_timeout, 5000, timeout}]}.

dirty(cast, {set_env, Par, Val}, Data) ->
    {keep_state, update(Par, Val, Data)};
dirty(cast, {unset_env, Par}, Data) ->
    {keep_state, remove(Par, Data)};
dirty(state_timeout, timeout, Data) ->
    ok = flush(Data),
    {next_state, clean, Data}.


%% private functions

default_dir() ->
    case application:get_env(?MODULE, config_dir) of
	undefined -> [os:getenv("HOME"), "/.", atom_to_list(?MODULE)];
	{ok, Dir} -> Dir
    end.

update(Par, Val, Data = #configer_data{map = Map}) ->
    Data#configer_data{map = maps:put(Par, Val, Map)}.

remove(Par, Data = #configer_data{map = Map}) ->
    Data#configer_data{map = maps:remove(Par, Map)}.

apply_to(App, #configer_data{map = Map}) ->
    maps:fold(fun (Par, Val, _) -> application:set_env(App, Par, Val) end, ok, Map).

load(Path) ->
    case filelib:is_file(Path) of
	false ->
	    ?LOG_WARNING("The config file ~ts is not found", [Path]),
	    #configer_data{path = Path};
	true ->
	    {ok, Plist} = file:consult(Path),
	    #configer_data{path = Path, map = maps:from_list(Plist)}
    end.

flush(#configer_data{path = Path, map = Map}) ->
    %% ascending order. maps:to_list/1 has arbitrary order
    Plist = lists:map(fun (Key) -> {Key, maps:get(Key, Map)} end,
		      lists:sort(maps:keys(Map))),
    Format = fun(Term) -> unicode:characters_to_binary(io_lib:format("~tp.~n", [Term])) end,
    %% write to a temp file and rename after the write
    Temp = Path ++ ".tmp",
    ok = file:write_file(Temp, lists:map(Format, Plist)),
    ok = file:rename(Temp, Path).
