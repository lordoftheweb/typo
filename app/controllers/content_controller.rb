# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ContentController < ApplicationController
  class ExpiryFilter
    def before(controller)
      @request_time = Time.now
    end

    def after(controller)
       future_article =
         Article.find(:first,
                      :conditions => ['published = ? AND published_at > ?', true, @request_time],
                      :order =>  "published_at ASC" )
       if future_article
         delta = future_article.published_at - Time.now
         controller.response.lifetime = (delta <= 0) ? 0 : delta
       end
    end
  end

  include LoginSystem
#  model :user
  before_filter :setup_themer
  helper :theme
#  before_filter :auto_discovery_defaults

  def self.caches_action_with_params(*actions)
    super
    around_filter ExpiryFilter.new, :only => actions
  end

  def self.cache_page(content, path)
    begin
      # Don't cache the page if there are any questionmark characters in the url
      unless path =~ /\?\w+/ or path =~ /page\d+$/
        super(content,path)
      end
    rescue # if there's a caching error, then just return the content.
      content
    end
  end

  protected

  def auto_discovery_defaults
    auto_discovery_feed
  end

  def auto_discovery_feed(options = { })
    with_options(options.reverse_merge(:only_path => true)) do |opts|
      @auto_discovery_url_rss = opts.url_for(:format => 'rss')
      @auto_discovery_url_atom = opts.url_for(:format => 'atom')
    end
  end

  def theme_layout
    this_blog.current_theme.layout
  end

  helper_method :contents
  def contents
    if @articles
      @articles
    elsif @article
      [@article]
    elsif @page
      [@page]
    else
      []
    end
  end
end
