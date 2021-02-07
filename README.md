self_configer
=====

Self configer is a erlang library that configure an OTP application with a flat file residing outside the OTP application structure. In many circustances application can change it's configuration, possibly from user inputs, and we need to persist the configuration. `self_configer` does exactly that. You read application environment using `application:get_env/1` as usual; however when you want to change anything, you use `self_configer:set_env/3` instead of `application:set_env/3`, and self_configer will take care of writing to the application environment, persist to a flat file, loading the flat file on boot automatically. 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `self_configer` to your list of dependencies in `mix.exs` or `rebar.config`:

```elixir
def deps do
  [
    {:self_configer, "~> 0.1.0"}
  ]
end
```

``` erlang
{deps, [self_configer]}.
```

In the application that want to make use of `self_configer`, put an instance of it in the supervisor:

``` elixir
  def start(_type, _args) do
    children = [
      {:self_configer, name: MyApp.Configer},
	  ...
```

``` erlang
init([]) ->
    SupFlags = #{strategy => one_for_all,
                 intensity => 0,
                 period => 1},
    ChildSpecs = [self_configer:child_spec([{name, my_configer}]),
                  ...
                 ],
    {ok, {SupFlags, ChildSpecs}}.
```

Each application should have its own configer instance, and must be named differently to avoid conflict. The instance should be started before any other processes that need to be confiured.

The default configuration dir is `$HOME/.self_configer`, and can be changed by the `config_dir` key in the `self_configer` application's env. This is the only configuration need to be done. You also need to make sure the dir exists before the application start.

## Usage

Let's suppose you have some user interfsace that can change configurations that you want to persist. Instead of calling `application:set_env/3` and `application:unset_env/2`, you call `self_configer:set_env/3` and `self_configer:unset_env/2` instead:

``` erlang
self_configer:set_env(Configer, Key1, Def1),
self_configer:unset_env(Configer, Key2),
```

where Configer is the name you gave for the configer instance for the application. The function returns the Configer on return so you can chain calls in elixir:

``` elixir
alias :self_configer, as: SelfConfiger

MyApp.Configer
|> SelfConfiger.set_env(key1, value1)
|> SelfConfiger.unset_env(key2)

```

The library will call `application:set_env/3` and `application:unset_env/2` for you so the runtime application config will be changed, and the configer instance will persist to a disk file `Config_dir/Application.config` in the background every 5 seconds when there are dirty data or on shutdown. The file is in erlang term file format so you can read, but any editting could be overwritten by the running allication. 

On next bootup, the persisted configuration will be applied on top of your build time or release run time application environment. `self_configer` write to a temp file first then do a rename afterwards, so the changes of damaged file content is minimized.


