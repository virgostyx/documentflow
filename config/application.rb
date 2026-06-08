require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Documentflow
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Floating labels for all forms (see concept note)
    config.action_view.default_form_builder = "FloatingLabelsRails::FormBuilder"

    # ViewComponent previews available at /rails/view_components
    config.view_component.previews.paths << Rails.root.join("spec/components/previews").to_s

    # Render previews in a minimal layout (no authenticated header) since previews
    # are rendered outside of a signed-in session and `current_user` is unavailable.
    config.view_component.previews.default_layout = "component_preview"

    # Application, engine, etc. configuration.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
