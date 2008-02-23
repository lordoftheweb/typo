class BlogSweeper < ActionController::Caching::Sweeper
  observe Category, Blog, Sidebar, User, Article, Page, Categorization

  def pending_sweeps
    @pending_sweeps ||= Set.new
  end

  def run_pending_page_sweeps
    logger.debug "Running pending page_sweeps: #{pending_sweeps.to_a.inspect}"
    pending_sweeps.each do |each|
      self.send(each)
    end
  end

  def after_comments_create
    logger.debug 'BlogSweeper#after_comments_create'
    expire_for(controller.send(:instance_variable_get, :@comment))
  end

  alias_method :after_comments_update, :after_comments_create
  alias_method :after_articles_comment, :after_comments_create

  def after_comments_destroy
    logger.debug 'BlogSweeper#after_comments_destroy'
    expire_for(controller.send(:instance_variable_get, :@comment), true)
  end

  alias_method :after_articles_nuke_comment, :after_comments_destroy

  def after_articles_trackback
    logger.debug 'BlogSweeper#after_articles_trackback'
    expire_for(controller.send(:instance_variable_get, :@trackback))
  end

  def after_articles_nuke_trackback
    logger.debug 'BlogSweeper#after_articles_nuke_trackback'
    expire_for(controller.send(:instance_variable_get, :@trackback), true)
  end

  def after_save(record)
    logger.info "Expiring #{record}, with controller: #{controller}"
    expire_for(record)
  end

  def after_destroy(record)
    logger.info "Caught #{record.title rescue record.inspect}, with controller: #{controller}"
    expire_for(record, true)
  end

  def expire_for(record, destroying = false)
    case record
    when Page
      pending_sweeps << :sweep_pages
    when Content
      if record.invalidates_cache?(destroying)
        pending_sweeps << :sweep_articles << :sweep_pages
      end
    when Sidebar, Category, Categorization
      pending_sweeps << :sweep_articles << :sweep_pages
    when Blog, User
      pending_sweeps << :sweep_all << :sweep_theme
    end
    unless controller
      run_pending_page_sweeps
    end
  end

  def sweep_all
    PageCache.sweep_all
    expire_fragment(/.*/)
  end

  def sweep_theme
    PageCache.sweep_theme_cache
  end

  def sweep_articles
    expire_fragment(%r{.*/articles/.*})
    unless Blog.default && Blog.default.cache_option == "caches_action_with_params"
      PageCache.zap_pages %w{index.* articles.* articles feedback
                             comments comments.* categories categories.* tags tags.* }
    end
  end

  def sweep_pages
    expire_fragment(/.*\/pages\/.*/)
    expire_fragment(/.*\/view_page.*/)
    unless Blog.default && Blog.default.cache_option == "caches_action_with_params"
      PageCache.zap_pages('pages')
    end
  end

  def logger
    @logger ||= RAILS_DEFAULT_LOGGER || Logger.new(STDERR)
  end

  private
  def callback(timing)
    super
    if timing == :after
      run_pending_page_sweeps
    end
  end
end
