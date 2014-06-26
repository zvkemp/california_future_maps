require 'sinatra'
require 'sinatra/activerecord'
require 'json'

set :database, { adapter: "sqlite3", database: "cdf_data.sqlite3" }

class Population < ActiveRecord::Base
  # groups and sums results, combining the given keys and returning an array of hashes

  def self.condense(*keys)
    keep_columns = column_names - keys.map(&:to_s) - ['id', 'estimate']
    mask         = -> (row) { Hash[keep_columns.map {|c| [c, row.send(c)] }]}
    puts mask[first].inspect
    Hash.new(0).tap do |result|
      all.each {|row| result[mask[row]] += row.estimate }
    end.map do |key, estimate|
      key.merge({ estimate: estimate })
    end
  end
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

# /data.json?county=SanFrancisco&race=all&age_group=all&year=2010
get '/data.json' do
  content_type :json

  query_params = {}
  condense_keys = []

  params.each do |key, value|
    if value == "all"
      condense_keys << key
    else
      query_params[key] = value
    end
  end

  Population.where(query_params).condense(*condense_keys).to_json
end

get '/meta.json' do
  content_type :json
  METADATA.to_json
end
