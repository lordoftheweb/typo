# BlogRequest is a fake Request object, created so blog.url_for will work.
class BlogRequest

  attr_accessor :protocol, :host_with_port, :path, :symbolized_path_parameters, :relative_url_root

  def initialize(root)
    @protocol = @host_with_port = @path = ''
    @symbolized_path_parameters = {}
    @relative_url_root = root.gsub(%r{/$},'')
  end
end

# The Blog class represents one blog.  It stores most configuration settings
# and is linked to most of the assorted content classes via has_many.
#
# Typo decides which Blog object to use by searching for a Blog base_url that
# matches the base_url computed for each request.
class Blog < CachedModel
  include ConfigManager

  validate_on_create { |blog|
    unless Blog.count.zero?
      blog.errors.add_to_base("There can only be one...")
    end
  }

  serialize :settings, Hash

  # Description
  setting :blog_name,                  :string, 'My Shiny Weblog!'
  setting :blog_subtitle,              :string, ''
  setting :title_prefix,               :integer, 0
  setting :geourl_location,            :string, ''
  setting :canonical_server_url,       :string, ''  # Deprecated
  setting :lang,                       :string, 'en_US'

  # Spam
  setting :sp_global,                  :boolean, false
  setting :sp_article_auto_close,      :integer, 0
  setting :sp_allow_non_ajax_comments, :boolean, true
  setting :sp_url_limit,               :integer, 0
  setting :sp_akismet_key,             :string, ''

  # Podcasting
  setting :itunes_explicit,            :boolean, false
  setting :itunes_author,              :string, ''
  setting :itunes_subtitle,            :string, ''
  setting :itunes_summary,             :string, ''
  setting :itunes_owner,               :string, ''
  setting :itunes_email,               :string, ''
  setting :itunes_name,                :string, ''
  setting :itunes_copyright,           :string, ''

  # Mostly Behaviour
  setting :text_filter,                :string, 'markdown smartypants'
  setting :comment_text_filter,        :string, 'markdown smartypants'
  setting :limit_article_display,      :integer, 10
  setting :limit_rss_display,          :integer, 10
  setting :default_allow_pings,        :boolean, false
  setting :default_allow_comments,     :boolean, true
  setting :default_moderate_comments,  :boolean, false
  setting :link_to_author,             :boolean, false
  setting :show_extended_on_rss,       :boolean, true
  setting :theme,                      :string, 'typographic'
  setting :use_gravatar,               :boolean, false
  setting :global_pings_disable,       :boolean, false
  setting :ping_urls,                  :string, "http://blogsearch.google.com/ping/RPC2\nhttp://rpc.technorati.com/rpc/ping\nhttp://ping.blo.gs/\nhttp://rpc.weblogs.com/RPC2"
  setting :send_outbound_pings,        :boolean, true
  setting :email_from,                 :string, 'typo@example.com'
  setting :editor,                     :integer, 2
  setting :cache_option,               :string, 'caches_page'
  setting :allow_signup,               :integer, 0

  #deprecation warning for plugins removal
  setting :deprecation_warning,        :integer, 1

  def initialize(*args)
    super
    # Yes, this is weird - PDC
    begin
      self.settings ||= {}
    rescue Exception => e
      self.settings = {}
    end
  end

  # Find the Blog that matches a specific base URL.  If no Blog object is found
  # that matches, then grab the default blog.  If *that* fails, then create a new
  # Blog.  The last case should only be used when Typo is first installed.
  def self.find_blog(base_url)
    Blog.default || Blog.create
  end

  # The default Blog.  This is the lowest-numbered blog, almost always id==1.
  def self.default
    find(:first, :order => 'id')
  end

  def ping_article!(settings)
    unless global_pings_enabled? && settings.has_key?(:url) && settings.has_key?(:article_id)
      throw :error, "Invalid trackback or trackbacks not enabled"
    end
    settings[:blog_id] = self.id
    article = requested_article(settings)
    unless article.allow_pings?
      throw :error, "Trackback not saved"
    end
    article.trackbacks.create!(settings)
  end

  def global_pings_enabled?
    ! global_pings_disable?
  end

  # Check that all required blog settings have a value.
  def configured?
    settings.has_key?('blog_name')
  end

  # The +Theme+ object for the current theme.
  def current_theme
    @cached_theme ||= Theme.find(theme)
  end

  # Generate a URL based on the +base_url+.  This allows us to generate URLs
  # without needing a controller handy, so we can produce URLs from within models
  # where appropriate.
  #
  # It also uses our new RouteCache, so repeated URL generation requests should be
  # fast, as they bypass all of Rails' route logic.
  def url_for(options = {}, *extra_params)
    case options
    when String then options # They asked for 'url_for "/some/path"', so return it unedited.
    when Hash
      unless RouteCache[options]
        options.reverse_merge!(:only_path => true, :controller => '',
                               :action => 'permalink')
        @url ||= ActionController::UrlRewriter.new(BlogRequest.new(self.base_url), {})
        RouteCache[options] = @url.rewrite(options)
      end

      return RouteCache[options]
    else
      raise "Invalid URL in url_for: #{options.inspect}"
    end
  end

  # The URL for a static file.
  def file_url(filename)
    "#{base_url}/files/#{filename}"
  end

  # The base server URL.
  def server_url
    base_url
  end

  # Deprecated
  typo_deprecate :canonical_server_url => :base_url

  def [](key)  # :nodoc:
    typo_deprecated "Use blog.#{key}"
    self.send(key)
  end

  def []=(key, value)  # :nodoc:
    typo_deprecated "Use blog.#{key}="
    self.send("#{key}=", value)
  end

  def has_key?(key)  # :nodoc:
    typo_deprecated "Why?"
    self.class.fields.has_key?(key.to_s)
  end

  def find_already_published(content_type)  # :nodoc:
    typo_deprecated "Use #{content_type}.find_already_published"
    content_type.to_s.camelize.constantize.find_already_published
  end

  def current_theme_path  # :nodoc:
    typo_deprecated "use current_theme.path"
    Theme.themes_root + "/" + theme
  end

  def requested_article(params)
    Article.find_by_params_hash(params)
  end

  def requested_articles(params)
    Article.find_all_by_date(*params.values_at(:year, :month, :day))
  end

  def articles_matching(query)
    Article.search(query)
  end

  def rss_limit_params
    limit = limit_rss_display.to_i
    return limit.zero? \
      ? {} \
      : {:limit => limit}
  end
end

