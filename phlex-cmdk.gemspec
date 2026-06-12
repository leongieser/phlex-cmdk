require_relative 'lib/cmdk/version'

Gem::Specification.new do |spec|
  spec.name = 'phlex-cmdk'
  spec.version = Cmdk::VERSION
  spec.authors = ['Leon Gieser']
  spec.email = ['leon.gieser@gmail.com']

  spec.summary = 'Fast, composable command menu for Phlex — a port of cmdk (React).'
  spec.description = 'Phlex components and a dependency-free JS runtime providing ' \
                     'feature parity with the cmdk React command menu, plus scoped search, ' \
                     'footer hints and ready-made themes. Works with Turbo and Tailwind.'
  spec.homepage = 'https://github.com/dip/phlex-cmdk'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'assets/**/*.{js,css}', 'README.md', 'LICENSE.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'phlex', '>= 2.0', '< 3'
end
