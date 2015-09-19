class CitiesUpdater < Thor
  desc "get_coordinates file country_name", "get coordinates for every city/village in a given YML file"

  def get_coordinates file, country_name
    require 'geocoder'
    require "#{ENV['FETCHER_ROOT']}/config/initializers/geocoder"

    puts "[get_coordinates] opening #{file}"
    cities = YAML.load_file(file)
    results = []
    for city in cities
      sql_request = "SELECT id FROM cities WHERE name = '#{mysql.escape(city)}'"
      if mysql.query(sql_request).count > 0 and not options[:force]
        puts "\033[32m[get_coordinates] skipping look for #{city}, #{country_name}\033[0m"
        next
      else
        puts "[get_coordinates] look for #{city}, #{country_name}"
      end
      geocoded  = Geocoder.search("#{city}, #{country_name}")
      if geocoded
        latitude  = geocoded.first.geometry['location']['lat']
        longitude = geocoded.first.geometry['location']['lng']
        zip       = zipcode(geocoded.first)
        puts "latitude = #{latitude}"
        puts "longitude = #{longitude}"
        puts "zip = #{zip}"
        sql_request = <<-eos
          INSERT INTO cities (zip, name, latitude, longitude, created_at, updated_at)
          VALUES (
            '#{mysql.escape(zip)}',
            '#{mysql.escape(city)}',
            #{latitude},
            #{longitude},
            '#{Time.now}',
            '#{Time.now}'
          )
        eos
        sql_result  = mysql.query(sql_request)
        obj = OpenStruct.new({city: city, latitude: latitude, longitude: longitude, zip: zip})
        results.push(obj)
        # Google Geocoding API has a speed limit. Go get some sleep between two requests to prevent a Google Geocoding API error
        sleep(1)
      end
    end

    puts "\033[32m[get_coordinates] Done\033[0m"

  end
end

def zipcode(place)
  zip = place.address_components.detect{|addr| addr['types'].include?('postal_code')}
  if zip
    zip = zip["short_name"]
  else
    puts place.inspect
    ""
  end
end

class Fetcher < Thor
  desc "cities_updater SUBCOMMAND ARGS", "Update Places informations"
  subcommand "cities_updater", CitiesUpdater
end
