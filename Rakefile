# frozen_string_literal: true

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new(:rubocop) do |task|
    # These make the rubocop experience maybe slightly less terrible
    task.options = ['-D', '-S', '-E']
  end
rescue LoadError
  desc 'rubocop is not available in this installation'
  task :rubocop do
    raise 'rubocop is not available in this installation'
  end
end
