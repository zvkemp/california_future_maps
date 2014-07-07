require 'sinatra/base'
require 'sinatra/activerecord'
require 'json'
require 'haml'

class CaliMaps < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  set :database, { adapter: "sqlite3", database: "cdf_data.sqlite3" }
end


class Population < ActiveRecord::Base
  # groups and sums results, combining the given keys and returning an array of hashes

  EXCLUDE_FROM_CONDENSATION = {
    'county' => ["California"]
  }

  def self.condense(*keys)
    keep_columns = column_names - keys.map(&:to_s) - ['id', 'estimate']
    mask         = -> (row) { Hash[keep_columns.map {|c| [c, row.send(c)] }]}
    puts mask[first].inspect
    Hash.new(0).tap do |result|
      all.each do |row| 
        next if EXCLUDE_FROM_CONDENSATION.any? {|key, exclusions| keys.include?(key) && exclusions.include?(row.send(key)) }
        result[mask[row]] += row.estimate 
      end
    end.map do |key, estimate|
      key.merge({ estimate: estimate })
    end
  end

  def self.spacify_county_names
    all.each do |row|
      row.county = row.county.gsub(/[A-Z]/){ " #{$&}" }.strip
      row.save
    end
  end
end

class CaliMaps < Sinatra::Base
  METADATA = {
    :race      => Population.pluck(:race).uniq,
    :county    => Population.pluck(:county).uniq,
    :age_group => Population.pluck(:age_group).uniq,
    :year      => Population.pluck(:year).uniq,
    :gender    => Population.pluck(:gender).uniq
  }

  get '/' do
    haml :map
  end

  get '/percent_change' do
    haml :percent_change
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

  run! if app_file == $0
end
