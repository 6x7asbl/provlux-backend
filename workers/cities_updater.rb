class CitiesUpdater < Thor
  desc "get_coordinates file country_name", "get coordinates for every city/village in a given YML file"

  def get_coordinates file, country_name
    require 'geocoder'
    require "#{ENV['FETCHER_ROOT']}/config/initializers/geocoder"

    puts "[get_coordinates] opening #{file}"
    cities = YAML.load_file(file)
    results = []
    for city in cities
      geocoded  = Geocoder.search("#{city}, #{country_name}")
      if geocoded
        latitude  = geocoded.first.geometry['location']['lat']
        longitude = geocoded.first.geometry['location']['lng']
        zip       = zipcode(geocoded.first)
        obj = OpenStruct.new({city: city, latitude: latitude, longitude: longitude, zip: zip})
        results.push(obj)
      end
    end

    raise results.inspect

  end
end

def zipcode(place)
  zip = place.address_components.detect{|addr| addr['types'].include?('postal_code')}
  if zip
    zip = zip["short_name"]
  else
    zip = -1
  end
end

class Fetcher < Thor
  desc "cities_updater SUBCOMMAND ARGS", "Update Places informations"
  subcommand "cities_updater", CitiesUpdater
end
