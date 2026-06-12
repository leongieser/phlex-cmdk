require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
end

task default: :test

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
