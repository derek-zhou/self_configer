self_configer
=====

Self configer is a erlang library that configure an OTP application with a flat file residing outside the OTP application structure. In many circustances application can change it's configuration, possibly from user inputs, and we need to persist the configuration. `self_configer` does exactly that. You read application environment using `application:get_env/1` as usual; however when you want to change anything, you use `self_configer:set_env/3` instead of `application:set_env/3`, and self_configer will take care of writing to the application environment, persist to a flat file, loading the flat file on boot automatically. 

Build
-----

    $ rebar3 compile

