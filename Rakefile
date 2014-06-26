require './app'
require 'sinatra/activerecord/rake'

require 'csv'

namespace :db do
  task :import_csv, [:csv] do |t, args|
    puts Population.all.inspect
    CSV.foreach(args[:csv], headers: true) do |row|
      Population.create row.to_hash
    end
  end
end
