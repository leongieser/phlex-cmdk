require 'date' # phlex 2.4 references Date in attribute generation without requiring it
require 'phlex'

# Phlex port of the cmdk React command menu. Renders the same markup contract
# (cmdk-* attributes, ARIA roles) as the React package; runtime behavior is
# provided by assets/js/cmdk.js.
module Cmdk
  extend Phlex::Kit

  # Absolute path to the JS runtime, for serving or copying into asset pipelines.
  def self.javascript_path
    File.expand_path('../assets/js/cmdk.js', __dir__)
  end

  # Absolute path to the optional themes stylesheet (cmdk-vercel, cmdk-linear,
  # cmdk-raycast). Plain dependency-free CSS — serve it, copy it, or import it
  # into a Tailwind build.
  def self.stylesheet_path
    File.expand_path('../assets/css/themes.css', __dir__)
  end
end

require_relative 'cmdk/version'
require_relative 'cmdk/base'
require_relative 'cmdk/root'
require_relative 'cmdk/input'
require_relative 'cmdk/list'
require_relative 'cmdk/item'
require_relative 'cmdk/group'
require_relative 'cmdk/separator'
require_relative 'cmdk/empty'
require_relative 'cmdk/loading'
require_relative 'cmdk/footer'
require_relative 'cmdk/dialog'
