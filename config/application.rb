require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Aero502
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0
    config.generators.test_framework :rspec
    # Deferred constraints and history triggers are part of the approved design.
    config.active_record.schema_format = :sql

    # SAE AERO works in College Station, so "today" and timestamps use US Central time.
    config.time_zone = "Central Time (US & Canada)"

    # Practice accounts sign in with a password; set PASSWORD_SIGN_IN=off once
    # everyone signs in with Google.
    config.x.password_sign_in = ENV.fetch("PASSWORD_SIGN_IN", "on") != "off"

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

       # Configuration for the application, engines, and railties goes here.
       #
       # These settings can be overridden in specific environments using the files
       # in config/environments, which are processed later.
       #
       # config.time_zone = "Central Time (US & Canada)"
       # config.eager_load_paths << Rails.root.join("extras")
  end
end
