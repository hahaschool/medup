require "http/client"

require "logger"

module Medup
  class Tool
    DIST_PATH                = "./posts"
    ASSETS_DIR_NAME          = "assets"
    SOURCE_AUTHOR_POSTS      = "overview"
    SOURCE_RECOMMENDED_POSTS = "has-recommended"
    MARKDOWN_FORMAT          = "md"
    JSON_FORMAT              = "json"

    token : String
    user : String?
    publication : String?
    articles : Array(String)
    options : Array(Options)
    logger : Logger

    def initialize(
      @token : String = "",
      dist : String? = DIST_PATH,
      format : String? = MARKDOWN_FORMAT,
      source : String? = SOURCE_AUTHOR_POSTS,
      @user : String? = nil,
      @publication : String? = nil,
      @articles : Array(String) = Array(String).new,
      @options : Array(Medup::Options) = Array(Medup::Options).new,
      @logger : Logger = Logger.new(STDOUT)
    )
      @client = Medium::Client.new(@token, @user, @publication, @logger)
      Medium::Client.default = @client
      @dist = (dist || DIST_PATH).as(String)
      @assets_dist = File.join(@dist, ASSETS_DIR_NAME)
      @source = (source || SOURCE_AUTHOR_POSTS).as(String)
      @format = (format || MARKDOWN_FORMAT).as(String)
      @update = @options.includes?(Medup::Options::UPDATE_CONTENT)
    end

    def backup
      posts = Array(String).new
      posts = if !@articles.empty?
                @client.normalize_urls(@articles)
              elsif !@user.nil?
                @client.streams(@source)
              elsif !@publication.nil?
                @client.collection_archive
              end

      raise "No articles to backup" if posts.nil? || posts.empty?

      create_directory(@dist)
      create_directory(@assets_dist)
      process_posts_async(posts)
    end

    def process_posts_async(posts)
      @logger.info "Posts count: #{posts.size}"

      channel_start = Channel(String).new(2)
      channel_finished = Channel(String).new(2)

      posts.each do |post_url|
        spawn do
          channel_start.send(post_url)
          process_post(post_url)
          channel_finished.send(post_url)
        end
      end

      posts.size.times do
        channel_start.receive?
        channel_finished.receive?
      end

      channel_start.close
      channel_finished.close
    end

    def close : Nil
      @client.close unless @client.nil?
    end

    def process_post(post_url : String)
      client = Medium::Client.new(@token, @user, @publication, @logger)
      post = client.post_by_url(post_url)
      save(post, @format)
    rescue ex : ::Medium::Error | ::Medium::InvalidContentError
      @logger.error "error: could not process #{post_url}: #{ex.message}"
    rescue ex : Exception
      @logger.error "error: #{ex.inspect}"
      @logger.error ex.inspect_with_backtrace
    ensure
      client.close unless client.nil?
    end

    def save(post, format = "json")
      slug = post.slug
      created_at = post.created_at

      filename = created_at.to_s("%F") + "-" + slug + "." + format
      filepath = File.join(@dist, filename)

      if File.exists?(filepath)
        return unless @update
        File.delete(filepath + ".old") if File.exists?(filepath + ".old")
        File.rename(filepath, filepath + ".old")
      end
      @logger.info "Create file #{filepath}"

      post.options = @options

      if format == "json"
        File.write(filepath, post.to_pretty_json)
        return
      end

      content, assets = post.to_md
      File.write(filepath, content)

      assets.each do |filename, content|
        filepath = File.join(@assets_dist, filename)
        @logger.debug "Create asset #{filepath}"
        File.write(filepath, content)
      end
    end

    def create_directory(path)
      unless File.directory?(path)
        @logger.debug "Create directory #{path}"
        Dir.mkdir_p(path)
      end
    end
  end
end
