require "bundler/gem_tasks"

require "rspec/core/rake_task"

task default: [:spec]

desc "Run all rspec files"
RSpec::Core::RakeTask.new("spec") do |c|
  c.rspec_opts = "-t ~unresolved"
end
