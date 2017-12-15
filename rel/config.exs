use Mix.Releases.Config,
    default_release: :marathon_event_exporter,
    default_environment: Mix.env()

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/configuration.html

environment :dev do
  set dev_mode: true
  set include_erts: false
  set cookie: :dev_test_cookie
end

environment :prod do
  set include_erts: true
  set include_src: false
  # The pre_start hook sets $ERLANG_COOKIE to a random value if is unset.
  set pre_configure_hook: "rel/hooks/pre_configure"
  set cookie: "${ERLANG_COOKIE}"
end

release :marathon_event_exporter do
  set version: current_version(:marathon_event_exporter)
  set applications: [
    :runtime_tools
  ]
end
