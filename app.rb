require 'sinatra'
require 'sinatra/activerecord'

set :database, { adapter: "sqlite3", database: "cdf_data.sqlite3" }

class Population < ActiveRecord::Base
end

get '/' do
  "Hello, World"
end

get '/data' do
  params.inspect
end
