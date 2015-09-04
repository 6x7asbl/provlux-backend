ENV['TZ']='UTC0'
require 'thor'
require 'rubygems'
require 'json'
require 'open-uri'
require 'dotenv'
Dotenv.load

ENV['FETCHER_ROOT'] = File.dirname(__FILE__)

errors = []
errors << "Missing .env file" unless File.exist?("#{ENV['FETCHER_ROOT']}/.env")
errors << "Missing GOOGLE_PLACES_API_KEY environment variable" if ENV['GOOGLE_PLACES_API_KEY'].nil?

STDOUT.sync = true

class Fetcher < Thor
end

require "#{ENV['FETCHER_ROOT']}/workers/places_updater"

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
