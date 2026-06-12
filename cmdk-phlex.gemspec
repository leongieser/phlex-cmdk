require_relative 'lib/cmdk/version'

Gem::Specification.new do |spec|
  spec.name = 'cmdk-phlex'
  spec.version = Cmdk::VERSION
  spec.authors = ['Leon Gieser']
  spec.email = ['leon.gieser@gmail.com']

  spec.summary = 'Fast, unstyled command menu for Phlex — a port of cmdk (React).'
  spec.description = 'Phlex components and a dependency-free JS runtime providing ' \
                     'feature parity with the cmdk React command menu. Works with Turbo and Tailwind.'
  spec.homepage = 'https://github.com/pacocoursey/cmdk'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.files = Dir['lib/**/*.rb', 'assets/**/*.js', 'README.md', 'LICENSE.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'phlex', '>= 2.0', '< 3'
end
