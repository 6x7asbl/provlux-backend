ENV['TZ']='UTC0'
require 'thor'
require 'rubygems'
require 'json'
require 'open-uri'
require 'dotenv'
require 'dragonfly'
Dotenv.load

ENV['FETCHER_ROOT'] = File.dirname(__FILE__)

errors = []
errors << "Missing .env file" unless File.exist?("#{ENV['FETCHER_ROOT']}/.env")
errors << "Missing GOOGLE_PLACES_API_KEY environment variable" if ENV['GOOGLE_PLACES_API_KEY'].nil?
errors << "Missing MYSQL_HOST environment variable"            if ENV['MYSQL_HOST'].nil?
errors << "Missing MYSQL_USERNAME environment variable"        if ENV['MYSQL_USERNAME'].nil?
errors << "Missing MYSQL_PASSWORD environment variable"        if ENV['MYSQL_PASSWORD'].nil?
errors << "Missing MYSQL_DATABASE environment variable"        if ENV['MYSQL_DATABASE'].nil?
errors << "Missing IMAGE_PATH environment variable"            if ENV['IMAGE_PATH'].nil?


Dragonfly.app.configure do
  datastore :file,
  :root_path => ENV['IMAGE_PATH'],    # directory under which to store files
                                       # - defaults to 'dragonfly' relative to current dir
  :server_root => 'public',            # root for urls when serving directly from datastore
                                       #   using remote_url
  :url_format => "/media/:job/:name"
end

STDOUT.sync = true

class Fetcher < Thor
end

require "#{ENV['FETCHER_ROOT']}/workers/places_updater"
require "#{ENV['FETCHER_ROOT']}/workers/cities_updater"

def dragonfly
  Dragonfly.app
end

begin
  if errors.any?
    puts errors
  else
    Fetcher.start(ARGV)
  end
rescue => e
  # Do something with the error, like notifying Airbrake
  raise e
end
