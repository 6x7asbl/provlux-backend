class WebParser
  require 'nokogiri'
  require 'open_uri_redirections'

  @social_networks = %w(instagram pinterest linkedin youtube vimeo vine medium xing foursquare)

  def initialize(url)
    @url = url
    puts "parsing #{@url}"
  end

  def facebook_regexp
    Regexp.new(/http(s)?:\/\/(www.)?facebook\.com\/(.+)/)
  end

  def facebook_blacklist_regexp
    Regexp.new(/\/media(\W)|\/(.*)\.php(\W)|\=PixelInitialized|ev\=NoScript|\/fbml(\W)|javascript\:/)
  end

  def youtube_regexp
    Regexp.new(/http(s)?:\/\/(www.)?youtube\.com\/(user|channel)\/(.+)/)
  end

  def youtube_blacklist_regexp
    Regexp.new(/javascript\:/)
  end

  def vimeo_regexp
    Regexp.new(/http(s)?:\/\/(www.)?vimeo\.com\/(.+)/)
  end

  def vimeo_blacklist_regexp
    Regexp.new(/javascript\:/)
  end

  def vine_regexp
    Regexp.new(/http(s)?:\/\/(www.)?vine\.co\/u\/(.+)/)
  end

  def vine_blacklist_regexp
    Regexp.new(/javascript\:/)
  end

  def medium_regexp
    Regexp.new(/http(s)?:\/\/(www.)?medium\.com\/@(.+)/)
  end

  def medium_blacklist_regexp
    Regexp.new(/javascript\:/)
  end

  def xing_regexp
    Regexp.new(/http(s)?:\/\/(www.)?xing\.com\/profile\/(.+)/)
  end

  def xing_blacklist_regexp
    Regexp.new(/javascript\:/)
  end

  def twitter_regexp
    Regexp.new(/http(s)?:\/\/(www.)?twitter\.com\/(.+)/)
  end

  def twitter_blacklist_regexp
    Regexp.new(/\/share(\W)|\/home(\W)|\/search(\W)|\/intent(\W)|javascript\:|\?status=/)
  end

  def pinterest_regexp
    Regexp.new(/http(s)?:\/\/(.{2,3}.)?pinterest\.com\/(.+)/)
  end

  def pinterest_blacklist_regexp
    Regexp.new(/\/create(\W)|javascript\:/)
  end

  def instagram_regexp
    Regexp.new(/http(s)?:\/\/(www.)?instagram\.com\/(.+)/)
  end

  def instagram_blacklist_regexp
    Regexp.new(/javascript\:/)
  end

  def foursquare_regexp
    Regexp.new(/http(s)?:\/\/(www.)?foursquare\.com\/(.+)/)
  end

  def foursquare_blacklist_regexp
    Regexp.new(/javascript\:/)
  end

  def linkedin_regexp
    Regexp.new(/http(s)?:\/\/(www.)?linkedin\.com\/company\/(.+)/)
  end

  def linkedin_blacklist_regexp
    Regexp.new(/\/shareArticle(\W)|javascript\:/)
  end

  def document
    begin
      @document ||= open(URI.parse(@url), :allow_redirections => :safe).read
    rescue URI::InvalidURIError
      puts "[error] URI::InvalidURIError (#{@url})"
    rescue OpenURI::HTTPError
      puts "[error] OpenURI::HTTPError (#{@url})"
    rescue Zlib::DataError
      puts "[error] Zlib::DataError (#{@url})"
    rescue => e
      puts "[error] #{e} (#{@url})"
    end
  end

  def links
    URI.extract(@document.to_html)
  end

  def html_document
    Nokogiri::HTML(document)
  end

  @social_networks.each do |social_network|
    define_method "#{social_network}_urls" do
      scanned_url(eval("#{social_network}_regexp")).reject{|url| url.match(eval("#{social_network}_blacklist_regexp"))}
    end
  end

  def facebook_urls
    if meta_article_publisher
      if meta_article_publisher.match(facebook_regexp)
        [meta_article_publisher]
      end
    else
      scanned_url(facebook_regexp).reject{|url| url.match(facebook_blacklist_regexp)}
    end
  end

  def scanned_url(regexp)
    begin
      URI.extract(html_document.to_html).select{|href|
        href.match(regexp)[0] if href.match(regexp)
      }
    rescue
      puts "TODO : unknown error"
      return []
    end
  end

  def twitter_urls
    if meta_twitter_site
      # TODO: force active field to true?
      meta_twitter_site.gsub(/@/, '')
    elsif meta_twitter_site_id
      raise meta_twitter_site_id.inspect
    elsif meta_twitter_creator
      raise meta_twitter_creator.inspect
    else
      scanned_url(twitter_regexp).reject{|url| url.match(twitter_blacklist_regexp)}
    end
  end


  def meta_description
    tag = html_document.at("//meta[@name='description']/@content")
    tag.value if tag
  end

  def meta_article_publisher
    tag = html_document.at("//meta[@property='article:publisher']/@content")
    tag.value if tag
  end

  def meta_twitter_site
    tag = html_document.at("//meta[@property='twitter:site']/@content")
    tag.value if tag
  end

  def meta_twitter_site_id
    tag = html_document.at("//meta[@property='twitter:site:id']/@content")
    tag.value if tag
  end

  def meta_twitter_creator
    tag = html_document.at("//meta[@property='twitter:creator']/@content")
    tag.value if tag
  end

end

