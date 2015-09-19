class PlacesUpdater < Thor
  require File.join(ENV['FETCHER_ROOT'], "lib", "database")
  require File.join(ENV['FETCHER_ROOT'], "lib", "web_parser")
  require 'geocoder'

  class_option :force, :type => :boolean, :default => false
  class_option :reverse, :type => :boolean, :default => false

  desc "get place_id", "fetch infor for a given place_id"
  def get(args)
    place_id = args.first
    # puts "[places_updater/get] get place id #{place_id}"
    url = "https://maps.googleapis.com/maps/api/place/details/json?placeid=#{place_id}&key=#{ENV['GOOGLE_PLACES_API_KEY']}"
    begin
      sleep(5)
      doc = open(URI.parse(url)).read
      json = JSON.parse(doc)
      result = json['result']
      return result
    rescue => e
      raise e
    end
  end

  desc "find_by_category category coordinates radius", "find every place for a given <category> within <radius> around <coordinates>"
  def find_by_category(category, coordinates, radius = 5000)
    url = "https://maps.googleapis.com/maps/api/place/radarsearch/json?location=#{coordinates}&radius=#{radius}&types=#{category}&key=#{ENV['GOOGLE_PLACES_API_KEY']}"
    sleep(5)
    doc = open(URI.parse(url)).read
    json = JSON.parse(doc)
    if json['error_message']
      raise json['error_message']
    else
      results = json['results']
      puts "[places_updater/find_by_category] #{results.length} results found for #{category} within #{radius} around #{coordinates}".colorize(:light_green)
      if results.length == 200
        puts "[places_updater/find_by_category] going deeper for #{category}".colorize(:blue)
        latitude, longitude = coordinates.split(',').map(&:to_f)
        center_point = [latitude, longitude]
        distance = 2.5
        lat1, long1, lat2, long2 = Geocoder::Calculations.bounding_box(center_point, distance)
        distance = 1
        lat3, long3, lat4, long4 = Geocoder::Calculations.bounding_box(center_point, distance)

        results = results.concat find_by_category(category, "#{lat1},#{long1}", (radius.to_i*0.6).to_i)
        results = results.concat find_by_category(category, "#{lat1},#{long2}", (radius.to_i*0.6).to_i)
        results = results.concat find_by_category(category, "#{lat2},#{long1}", (radius.to_i*0.6).to_i)
        results = results.concat find_by_category(category, "#{lat2},#{long2}", (radius.to_i*0.6).to_i)
        results = results.concat find_by_category(category, "#{lat3},#{long3}", (radius.to_i*0.6).to_i)
        results = results.concat find_by_category(category, "#{lat3},#{long4}", (radius.to_i*0.6).to_i)
        results = results.concat find_by_category(category, "#{lat4},#{long3}", (radius.to_i*0.6).to_i)
        results = results.concat find_by_category(category, "#{lat4},#{long4}", (radius.to_i*0.6).to_i)

        return results.uniq
      else
        return results
      end
    end
  end

  desc "update_all_by_category category coordinates radius", "update every place for a given <category> within <radius> around <coordinates>"
  def update_all_by_category(args)
    category, coordinates, radius = args
    results = find_by_category(category, coordinates, radius)
    results.each do |result|
      sql_request = "SELECT id FROM interests WHERE source = 'google_api' AND source_id = '#{result['place_id']}'"
      if mysql.query(sql_request).count > 0 and not options[:force]
        # puts "use --force"
        next
      end
      ironmq.queue("PLACES_UPDATER").post("update_place|#{result['place_id']}", :timeout => 3600)
    end
  end

  desc "update_all_by_category category coordinates radius", "update every place in every category within <radius> around <coordinates>"
  def update_all_categories(coordinates, radius = 5000)
    categories = %w(
      accounting
      airport
      amusement_park
      aquarium
      art_gallery
      atm
      bakery
      bank
      bar
      beauty_salon
      bicycle_store
      book_store
      bowling_alley
      bus_station
      cafe
      campground
      car_dealer
      car_rental
      car_repair
      car_wash
      casino
      cemetery
      church
      city_hall
      clothing_store
      convenience_store
      courthouse
      dentist
      department_store
      doctor
      electrician
      electronics_store
      embassy
      establishment
      finance
      fire_station
      florist
      food
      funeral_home
      furniture_store
      gas_station
      general_contractor
      grocery_or_supermarket
      gym
      hair_care
      hardware_store
      health
      hindu_temple
      home_goods_store
      hospital
      insurance_agency
      jewelry_store
      laundry
      lawyer
      library
      liquor_store
      local_government_office
      locksmith
      lodging
      meal_delivery
      meal_takeaway
      mosque
      movie_rental
      movie_theater
      moving_company
      museum
      night_club
      painter
      park
      parking
      pet_store
      pharmacy
      physiotherapist
      place_of_worship
      plumber
      police
      post_office
      real_estate_agency
      restaurant
      roofing_contractor
      rv_park
      school
      shoe_store
      shopping_mall
      spa
      stadium
      storage
      store
      subway_station
      synagogue
      taxi_stand
      train_station
      travel_agency
      university
      veterinary_care
      zoo
    )

    for category in categories
      ironmq.queue("PLACES_UPDATER").post("update_all_by_category|#{category}|#{coordinates}|#{radius}", :timeout => 3600)
    end
  end

  desc "update_all_categories_in_every_city radius", "update every place in every category within <radius> around every city"
  def update_all_categories_in_every_city(radius = 5000)
    sql_request = "SELECT * FROM cities"
    if options[:reverse]
      puts "reversing cities"
      sql_request += " ORDER BY id DESC"
    end
    sql_result = mysql.query(sql_request)
    sql_result.each do |city|
      # next if city['id'] < 670
      puts "[update_all_categories_in_every_city] looking for results in #{city['name']}".colorize(:green)
      coordinates = "#{city['latitude']},#{city['longitude']}"

      update_all_categories(coordinates, radius = 5000)
    end
  end

  desc "execute MESSAGE", "Execute the given MQ message and output the result. Check The workers doc for the MQ message format"
  def execute(message)
    (STDERR.puts "Wrong message format for message : #{msg}"; Process.exit!) unless message
    options = message.split('|')
    command = options.first
    args    = options[1..-1]
    STDERR.puts "#{command} #{args}".colorize(:green)
    send(command, args)
  end


  desc "start", "Fetches and executes messages found in the MQ. Runs forever but does not daemonize."
  def start
    begin
      queue_base_name = "PLACES_UPDATER"
      sleep_time_when_empty_queue = 15
      while true
        ironmq.queue(queue_base_name).poll :sleep_duration => sleep_time_when_empty_queue do |message|
          self.execute message.body
        end
      end
    rescue Interrupt => e
      # Current messgae wont be ack as expected
    rescue Errno::EHOSTUNREACH
      retry
    end

  end

  private

  def update_place(place_id)
    sql_request = "SELECT id FROM interests WHERE source = 'google_api' AND source_id = '#{place_id.first}'"
    if mysql.query(sql_request).count > 0 and not options[:force]
      puts "already existing place"
    else
      place = get(place_id)
      formatted_place = format_place(place)
      category_ids = get_category_ids(place)
      sql_request =  <<-eos
        INSERT INTO interests (
          name,
          address,
          zip,
          city,
          phone,
          website,
          latitude,
          longitude,
          source,
          source_id,
          city_id,
          country_code,
          created_at,
          updated_at
        )
        VALUES (
          '#{formatted_place["name"]}',
          '#{formatted_place["address"]}',
          '#{formatted_place["zip"]}',
          '#{formatted_place["city"]}',
          '#{formatted_place["phone"]}',
          '#{formatted_place["website"]}',
          '#{formatted_place["latitude"]}',
          '#{formatted_place["longitude"]}',
          '#{formatted_place["source"]}',
          '#{formatted_place["source_id"]}',
          '#{formatted_place["city_id"]}',
          '#{formatted_place["country_code"]}',
          '#{Time.now}',
          '#{Time.now}'
        );
      eos
      mysql.query(sql_request)
      interest_id = mysql.last_id

      # Handle URLs
      for url in urls(place)
        sql_request = "INSERT INTO interest_urls (interest_id, url, provider, created_at, updated_at) VALUES (#{interest_id}, '#{url.url}', '#{url.provider}', '#{Time.now}', '#{Time.now}')"
        begin
          mysql.query(sql_request)
        rescue Mysql2::Error
          # Duplicate entry, skip
        end
      end

      # Handle categories
      for category_id in category_ids
        sql_request = "INSERT INTO categories_interests (category_id, interest_id) VALUES ('#{category_id}', '#{interest_id}')"
        mysql.query(sql_request)
      end

      # Handle photos
      get_photos(place['photos'], interest_id) if place['photos']

      # Handle opening hours
      get_opening_hours(place['opening_hours']['periods'], interest_id) if place['opening_hours'] && place['opening_hours']['periods']
    end
  end

  def zipcode(place)
    zip = place['address_components'].select{|addr| addr['types'].include?('postal_code')}
    if zip && zip.first
      zip = zip.first["short_name"]
    else
      zip = -1
    end
  end

  def urls(place)
    urls = []
    if place['website']
      webparser       = WebParser.new(place['website'])
      %w(facebook twitter pinterest instagram linkedin youtube vimeo medium xing foursquare).each do |provider|
        if provider_urls = webparser.send("#{provider}_urls")
          provider_urls.each do |provider_url|
            urls.push OpenStruct.new(url: mysql.escape(provider_url), provider: provider)
          end
        end
      end
    end
    if place['url']
      urls.push OpenStruct.new(url: mysql.escape(place['url']), provider: 'google_plus')
    end
  end

  def format_place(place)
    street_number = place['address_components'].detect{|addr| addr['types'].include?('street_number')}
    street_number = street_number['long_name'] if street_number
    route = place['address_components'].detect{|addr| addr['types'].include?('route')}
    route = route['long_name'] if route
    city = place['address_components'].detect{|addr| addr['types'].include?('locality')}
    city = city['long_name'] if city
    if city.nil?
      city = place['address_components'].detect{|addr| addr['types'].include?('sublocality')}
      city = city['long_name'] if city
    end
    country_code = place['address_components'].detect{|addr| addr['types'].include?('country')}['short_name']
    if street_number
      address = "#{route}, #{street_number}"
    else
      address = "#{route}"
    end
    object = {}
    object['name']            = mysql.escape(place['name']) if place['name']
    object['address']         = mysql.escape(address) if address
    object['city']            = mysql.escape(city) if city
    object['country_code']    = mysql.escape(country_code) if country_code
    object['zip']             = zipcode(place)
    object['phone']           = mysql.escape(place["international_phone_number"]) if place["international_phone_number"]
    object['website']         = mysql.escape(place['website']) if place['website']
    object['latitude']        = place['geometry']['location']['lat']
    object['longitude']       = place['geometry']['location']['lng']
    object['source']          = 'google_api'
    object['source_id']       = place['place_id']
    object['city_id']         = place['']

    object
  end

  def get_category_ids(place)
    results = []
    categories = place['types']
    for category in categories
      sql_request = "SELECT id FROM categories WHERE label = '#{category}' limit 1"
      if mysql.query(sql_request).count == 0
        sql_request = "INSERT INTO categories (label, created_at, updated_at) VALUES ('#{category}', '#{Time.now}', '#{Time.now}')"
        sql_result  = mysql.query(sql_request)
        sql_request = "SELECT id FROM categories WHERE label = '#{category}' limit 1"
        sql_result  = mysql.query(sql_request).first
        results << sql_result['id']
      else
        sql_result  = mysql.query(sql_request).first
        results << sql_result['id']
      end
    end
    results
  end


  def get_photos(photos, interest_id)
    # puts "photos detection disabled"
    for photo in photos
      filename  = photo['photo_reference']
      image_uid = dragonfly.store(open("https://maps.googleapis.com/maps/api/place/photo?photoreference=#{photo['photo_reference']}&maxwidth=#{photo['width']}&key=#{ENV['GOOGLE_PLACES_API_KEY']}").read)
      sql_request = "INSERT INTO pictures (image_uid, image_name, interest_id, created_at, updated_at) VALUES ('#{image_uid}', '#{image_uid.split('/').last}', '#{interest_id}', '#{Time.now}', '#{Time.now}')"
      sql_result  = mysql.query(sql_request)
    end
  end

  def get_opening_hours(opening_hours, interest_id)
    begin
      values = []
      for opening_hour in opening_hours
        if opening_hour['open'] and opening_hour['close']
          values.push("('#{interest_id}', '#{opening_hour['open']['day']}', '#{opening_hour['open']['time']}00', '#{opening_hour['close']['time']}00', '#{Time.now}', '#{Time.now}')")
        end
      end
      if values.any?
        sql_request = "INSERT INTO opening_hours (interest_id, day_of_week, open_time, close_time, created_at, updated_at) VALUES #{values.join(',')}"
        sql_result  = mysql.query(sql_request)
      end
    rescue => e
      puts "opening_hours #{opening_hours.inspect}".colorize(:red)
      puts "interest_id #{interest_id.inspect}".colorize(:red)
      puts "values #{values.inspect}".colorize(:red)
      raise e
    end
  end
end

class Fetcher < Thor
  desc "places_updater SUBCOMMAND ARGS", "Update Places informations"
  subcommand "places_updater", PlacesUpdater
end
