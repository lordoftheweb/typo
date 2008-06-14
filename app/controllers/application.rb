# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ApplicationController < ActionController::Base
  include ::LoginSystem
  before_filter :reset_local_cache, :fire_triggers, :load_lang
  after_filter :reset_local_cache

  class << self
    unless self.respond_to? :template_root
      def template_root
        ActionController::Base.view_paths.last
      end
    end
  end

  protected

  def setup_themer
    # Ick!
    self.view_paths =
      ::ActionController::Base.view_paths.dup.unshift("#{RAILS_ROOT}/themes/#{this_blog.theme}/views")
  end

  def error(message = "Record not found...", options = { })
    @message = message.to_s
    render :template => 'articles/error', :status => options[:status] || 404
  end

  def fire_triggers
    Trigger.fire
  end

  def load_lang
    Localization.lang = this_blog.lang if this_blog.lang != 'en_US'
  end

  def reset_local_cache
    CachedModel.cache_reset
    @current_user = nil
  end

  # Axe?
  def server_url
    this_blog.base_url
  end

  def cache
    $cache ||= SimpleCache.new 1.hour
  end

  # The Blog object for the blog that matches the current request.  This is looked
  # up using Blog.find_blog and cached for the lifetime of the controller instance;
  # generally one request.
  def this_blog
    @blog ||= Blog.default
  end

  helper_method :this_blog

  def reset_blog_ids
  end

  # The base URL for this request, calculated by looking up the URL for the main
  # blog index page.  This is matched with Blog#base_url to determine which Blog
  # is supposed to handle this URL
  def blog_base_url
    url_for(:controller => '/articles').gsub(%r{/$},'')
  end

  def add_to_cookies(name, value, path=nil, expires=nil)
    cookies[name] = { :value => value, :path => path || "/#{controller_name}",
                       :expires => 6.weeks.from_now }
  end
end

