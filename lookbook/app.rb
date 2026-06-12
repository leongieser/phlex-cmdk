# Minimal single-file Rails host for Lookbook component previews.
# Lookbook is a Rails engine, so this boots just enough of Rails to mount it;
# the gem itself stays Rails-free.

ENV['RAILS_ENV'] ||= 'development'

require 'rails'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'lookbook'
require 'phlex-rails'

require_relative '../lib/cmdk'
require_relative 'scenarios'

module PhlexCmdk
  class Application < Rails::Application
    config.root = __dir__
    config.eager_load = false
    config.consider_all_requests_local = true
    config.secret_key_base = 'phlex-cmdk-lookbook-previews'
    config.hosts.clear
    config.logger = ActiveSupport::Logger.new($stdout)
    config.log_level = :warn

    # Lookbook resolves preview classes through the app autoloader.
    config.autoload_paths << File.expand_path('previews', __dir__)

    config.lookbook.project_name = 'phlex-cmdk'
    config.lookbook.preview_paths = [File.expand_path('previews', __dir__)]
    config.lookbook.preview_layout = 'preview'
    config.lookbook.live_updates = false
    # Theme dropdown in the preview toolbar; the layout maps it to data-theme.
    config.lookbook.preview_display_options = { theme: %w[system light dark] }
  end
end

Rails.application.initialize! # routes live in config/routes.rb so dev reloads keep them
