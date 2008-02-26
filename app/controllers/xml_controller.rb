class XmlController < ApplicationController
  caches_page :feed
  session :off

  NORMALIZED_FORMAT_FOR = {'atom' => 'atom', 'rss' => 'rss',
    'atom10' => 'atom', 'atom03' => 'atom', 'rss20' => 'rss',
    'googlesitemap' => 'googlesitemap', 'rsd' => 'rsd' }

  CONTENT_TYPE_FOR = { 'rss' => 'application/xml',
    'atom' => 'application/atom+xml',
    'googlesitemap' => 'application/xml' }

  before_filter :adjust_format

  def feed
    @format = params[:format]

    unless @format
      return render(:text => 'Unsupported format', :status => 404)
    end

    case params[:type]
    when 'feed'
      head :moved_permanently, :location => formatted_articles_url(@format)
    when 'comments'
      head :moved_permanently, :location => formatted_admin_comments_url(@format)
    when 'article'
      head :moved_permanently, :location => formatted_article_url(Article.find(params[:id]), @format)
    when 'category', 'tag', 'author'
      head :moved_permanently, \
        :location => self.send("formatted_#{params[:type]}_url", params[:id], @format)
    else
      @items = Array.new
      @blog = this_blog
      @feed_title = this_blog.blog_name
      @link = this_blog.base_url

      if respond_to?("prep_#{params[:type]}")
        self.send("prep_#{params[:type]}")
      else
        render :text => 'Unsupported action', :status => 404
        return
      end
      respond_to do |format|
        format.googlesitemap
        format.atom
        format.rss
      end
    end
  end

  def itunes
    @feed_title = "#{this_blog.blog_name} Podcast"
    @items = Resource.find(:all, :order => 'created_at DESC',
      :conditions => ['itunes_metadata = ?', true], :limit => this_blog.limit_rss_display)
    respond_to do |format|
      format.rss { render :action => "itunes_feed" }
    end
  end

  def articlerss
    redirect_to :action => 'feed', :format => 'rss', :type => 'article', :id => params[:id]
  end

  def commentrss
    redirect_to :action => 'feed', :format => 'rss', :type => 'comments'
  end
  def trackbackrss
    redirect_to :action => 'feed', :format => 'rss', :type => 'trackbacks'
  end

  def rsd

  end

  protected

  def adjust_format
    if params[:format]
      params[:format] = NORMALIZED_FORMAT_FOR[params[:format]]
    else
      params[:foramt] = 'rss'
    end
    return true
  end

  def fetch_items(association, order='published_at DESC', limit=nil)
    if association.instance_of?(Symbol)
      association = association.to_s.singularize.classify.constantize
    end
    limit ||= this_blog.limit_rss_display
    @items += association.find_already_published(:all, :limit => limit, :order => order)
  end

  def prep_feed
    fetch_items(:articles)
  end

  def prep_comments
    fetch_items(:comments)
    @feed_title << " comments"
  end

  def prep_trackbacks
    fetch_items(:trackbacks)
    @feed_title << " trackbacks"
  end

  def prep_article
    article = this_blog.articles.find(params[:id])
    fetch_items(article.comments, 'published_at DESC', 25)
    @items.unshift(article)
    @feed_title << ": #{article.title}"
    @link = article.permalink_url
  end

  def prep_category
    category = Category.find_by_permalink(params[:id])
    fetch_items(category.articles)
    @feed_title << ": Category #{category.name}"
    @link = category.permalink_url
  end

  def prep_tag
    tag = Tag.find_by_name(params[:id])
    fetch_items(tag.articles)
    @feed_title << ": Tag #{tag.display_name}"
    @link = tag.permalink_url
  end

  def prep_sitemap
    fetch_items(:articles, 'created_at DESC', 1000)
    fetch_items(:pages, 'created_at DESC', 1000)
    @items += Category.find_all_with_article_counters(1000)
    @items += Tag.find_all_with_article_counters(1000)
  end
end
