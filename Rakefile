require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb']
end

namespace :test do
  desc 'Run the JS runtime tests in headless Chrome (needs Chrome or Chromium)'
  Rake::TestTask.new(:browser) do |t|
    t.libs << 'test'
    t.test_files = FileList['test/browser/**/*_test.rb']
  end

  desc "Run the JS runtime's pure-function tests with Node's built-in runner"
  task :js do
    sh 'node', '--test', *FileList['test/js/**/*.test.mjs']
  end

  desc 'Run every test suite (markup, JS, browser)'
  task all: %i[test test:js test:browser]
end

task default: :test

desc 'Measure per-keystroke filtering latency in headless Chrome (SIZES=200,1000,5000 HIGHLIGHT=1)'
task :bench do
  sh 'bundle exec ruby bench/filter_bench.rb'
end

desc 'Build the demo Tailwind CSS'
task :css do
  sh 'bundle exec tailwindcss -i demo/assets/application.css -o demo/public/application.css'
end

desc 'Run the demo app on http://localhost:9292'
task demo: :css do
  sh 'bundle exec rackup demo/config.ru'
end

desc 'Run Lookbook component previews on http://localhost:9293'
task lookbook: :css do
  sh 'bundle exec rackup lookbook/config.ru -p 9293'
end

desc 'Build the static GitHub Pages site into _site/'
task site: :css do
  sh 'bundle exec ruby site/build.rb'
end
