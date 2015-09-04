class PlacesUpdater < Thor
  desc "get place_id", "fetch infor for a given place_id"
  def get(place_id)
    puts "[places_updater/get] get place id #{place_id}"
    url = "https://maps.googleapis.com/maps/api/place/details/json?placeid=#{place_id}&key=#{ENV['GOOGLE_PLACES_API_KEY']}"
    doc = open(URI.parse(url)).read
    json = JSON.parse(doc)
    result = json['result']
    return result
  end

  desc "find_by_category category coordinates radius", "find every place for a given <category> within <radius> around <coordinates>"
  def find_by_category(category, coordinates, radius = 5000)
    # "49.68333,5.81667"
    url = "https://maps.googleapis.com/maps/api/place/radarsearch/json?location=#{coordinates}&radius=#{radius}&types=#{category}&key=#{ENV['GOOGLE_PLACES_API_KEY']}"
    doc = open(URI.parse(url)).read
    json = JSON.parse(doc)
    results = json['results']
    puts "[places_updater/find_by_category] #{results.length} results found for #{category} within #{radius} around #{coordinates}"
    return results
  end

  desc "update_all_by_category category coordinates radius", "update every place for a given <category> within <radius> around <coordinates>"
  def update_all_by_category(category, coordinates, radius = 5000)
    results = find_by_category(category, coordinates, radius)
    results.each do |result|
      place = get(result['place_id'])
    end
  end
end

class Fetcher < Thor
  desc "places_updater SUBCOMMAND ARGS", "Update Places informations"
  subcommand "places_updater", PlacesUpdater
end
