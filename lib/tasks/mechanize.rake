require 'mechanize'
require 'nokogiri'
require 'uri'

namespace :mech do
  desc "Import wish list"
  task :scrape => :environment do
    @agent = Mechanize.new

    #login to github
    @agent.get('https://github.com/login')
    form = @agent.page.form_with(:action => '/session')
    form.login = ''
    form.password = ''
    form.submit

    #access railscast
    @agent.get('http://example.com/')
    @agent.page.link_with(:text => 'Sign in through GitHub')
    sign_in = @agent.page.link_with(:text => 'Sign in through GitHub')
    sign_in.click

    (1..2).each do |page|
      get_episodes_on_page(page)
      puts "completed page " + page.to_s
    end
  end

  def get_episodes_on_page(page_id)
    @agent.get("http://example.com/?page=#{page_id}")

    #get all episodes on page
    all_episodes_on_page = @agent.page.search('.episode')

    root_path = 'archive'

    all_episodes_on_page.each do |episode|
      episode_link = Mechanize::Page::Link.new(episode.search('h2 a').first, @agent, @agent.page)
      episode_dirname = episode_link.href.sub '/episodes/', ''
      episode_path = "#{root_path}/#{episode_dirname}/"
      FileUtils.mkpath episode_path
      episode_link.click
     
      #scrape notes,
      scrape_page(@agent.page.link_with(:text => 'Show Notes') , 'notes_files', 'notes.html', episode_path)

      download_source_and_video(episode_path)
      sleep(rand(10))
    end
  end

  def download_source_and_video(episode_path)
    begin
      @agent.transact do
        puts 'downloading vids'
        downloader = Mechanize::DirectorySaver.save_to "#{episode_path}"
        @agent.pluggable_parser.default = Mechanize::DirectorySaver.save_to "#{episode_path}"
        @agent.pluggable_parser['image'] = downloader

        src_code_href = @agent.page.link_with(:text => 'source code').href
        video_src = @agent.page.link_with(:text => 'mp4').href
        
        puts 'download ' +  src_code_href
        @agent.get src_code_href 

        puts 'download ' + video_src
        @agent.get video_src 
      end
    rescue => e
        puts "#{e.class}: #{e.message}"
    end
  end

  def scrape_page (page_link, directory, page_name, episode_path)
    begin
      @agent.transact do
        page_link.click
        scrape_assets(directory, episode_path)
        File.open("#{episode_path}/#{page_name}", 'w') {|f| f.write(@agent.page.parser.to_html) }
      end
    rescue => e
        puts "#{e.class}: #{e.message}"
    end
  end

  def make_uri_absolute(doc)
    tags = {
      'img'    => 'src',
      'script' => 'src',
      'a'      => 'href',
      'link'   => 'href',
    }

    doc.search(tags.keys.join(',')).each do |node|
      url_param = tags[node.name]
      src = node[url_param]
      if (src.present?)
        uri = URI.parse(src)
        unless uri.host
          uri.scheme = @agent.page.uri.scheme
          uri.host = @agent.page.uri.host
          node[url_param] = uri.to_s
        end
      end
    end
  end

  def scrape_assets (directory, episode_path)
    tags = {
      'img'    => 'src',
      'script' => 'src',
      'link'   => 'href',
    }

    @agent.page.search(tags.keys.join(',')).each do |node|
      url_param = tags[node.name]
      src = node[url_param]

      if(src.present?)
        begin
          @agent.transact do
            puts 'download ' + src
            downloader = Mechanize::DirectorySaver.save_to "#{episode_path}/#{directory}/"
            @agent.pluggable_parser.default = Mechanize::DirectorySaver.save_to "#{episode_path}/#{directory}/"
            @agent.pluggable_parser['image'] = downloader
            @agent.get src 
            filename = src.gsub(/.+\/(.+)/,'\1')
            puts 'filename = ' + filename
            node[url_param] = "#{directory}/#{filename}"
          end
        rescue => e
          puts "#{e.class}: #{e.message}"
        end
      end
    end
  end
end
