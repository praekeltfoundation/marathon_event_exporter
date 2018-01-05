# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :marathon_event_exporter, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:marathon_event_exporter, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

# These are the minimal required defaults. Full configuration defined in
# marathon_event_exporter.schema.exs and marathon_event_exporter.*.conf
config :marathon_event_exporter, [
  # Assume localhost unless told otherwise
  marathon_url: "http://localhost:8080/v2/events",
  # We should get several keepalives per minute
  stream_timeout: 60_000,
  # Arbitrarily chosen to not conflict with anything in
  # https://github.com/prometheus/prometheus/wiki/Default-port-allocations
  exporter_port: 9595,
]
