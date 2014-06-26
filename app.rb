require 'sinatra'
require 'sinatra/activerecord'
require 'json'

set :database, { adapter: "sqlite3", database: "cdf_data.sqlite3" }

class Population < ActiveRecord::Base
end

METADATA = {
  :races      => Population.pluck(:race).uniq,
  :counties   => Population.pluck(:county).uniq,
  :age_groups => Population.pluck(:age_group).uniq,
  :years      => Population.pluck(:year).uniq,
  :genders    => Population.pluck(:gender).uniq
}

get '/' do
  "Hello, World"
end

get '/data.json' do
  content_type :json
  Population.where(params).to_json
end

get '/meta.json' do
  content_type :json
  METADATA.to_json
end
