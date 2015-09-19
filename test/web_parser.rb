class Test < Thor
  require File.join(ENV['FETCHER_ROOT'], "lib", "web_parser")


  desc "web_parser", "web_parser"
  def web_parser
    start = Time.now
    webparser = WebParser.new("http://www.lamaisonvirtonaise.com/")
    puts "#{(Time.now - start)}ms"
    %w(facebook twitter pinterest instagram linkedin youtube vimeo medium xing foursquare).each do |provider|
      puts "[#{provider}] 1"
      if provider_urls = webparser.send("#{provider}_urls")
        puts "[#{provider}] 2"
        provider_urls.each do |provider_url|
          puts "[#{provider}] 3"
          urls.push OpenStruct.new(url: mysql.escape(provider_url), provider: provider)
        end
        puts "#{(Time.now - start)}ms [#{provider}]"
      end
    end
    puts "#{(Time.now - start)}ms"
  end
end

class Fetcher < Thor
  desc "test SUBCOMMAND ARGS", "test a command"
  subcommand "test", Test
end
