require_dependency 'spam_protection'

class Trackback < Feedback
  belongs_to :article
  content_fields :excerpt
  validates_presence_of :title, :excerpt, :url

  attr_accessible :blog_id, :url, :blog_name, :title, :excerpt, :ip, :published, :article_id

  def initialize(*args, &block)
    super(*args, &block)
    self.title ||= self.url
    self.blog_name ||= ""
  end

  before_create :process_trackback

  def make_nofollow
    typo_deprecated 'Do it via postprocessing.'
  end

  def process_trackback
    if excerpt.length >= 251
      # this limits excerpt to 250 chars, including the trailing "..."
      self.excerpt = excerpt[0..246] << "..."
    end
  end

  def article_allows_feedback?
    return true if article.allow_pings?
    errors.add(:article, 'Article is not pingable')
    false
  end

  def blog_allows_feedback?
    return true unless blog.global_pings_disable
    errors.add(:article, "Pings are disabled")
    false
  end

  def originator
    blog_name
  end

  def body
    excerpt
  end

  def body=(newval)
    self.excerpt = newval
  end

  def rss_author(xml)
  end

  def atom_author(xml)
    xml.author do
      xml.name blog_name
      xml.uri url
    end
  end

  def atom_title(xml)
    xml.title "Trackback from #{blog_name}: #{title} on #{article.title}", :type => 'text/html'
  end

  def rss_title(xml)
    xml.title "Trackback from #{blog_name}: #{title} on #{article.title}"
  end
end

