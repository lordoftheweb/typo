class Feedback < Content
  # Empty, for now, ready to hoist up methods from Comment & Trackback
  set_table_name "feedback"

  include TypoGuid
  validates_age_of :article_id

  before_create :create_guid, :article_allows_this_feedback
  before_save :correct_url
  after_save :post_trigger
  after_save :report_classification

  has_state(:state,
            :valid_states => [:unclassified, #initial state
                              :presumed_spam, :just_marked_as_spam, :spam,
                              :just_presumed_ham, :presumed_ham, :just_marked_as_ham, :ham],
            :handles => [:published?, :status_confirmed?, :just_published?,
                         :mark_as_ham, :mark_as_spam, :confirm_classification,
                         :withdraw, :before_save, :after_initialize,
                         :send_notifications, :post_trigger, :report_classification])

  include States

  def self.default_order
    'created_at ASC'
  end

  def to_params(builder)
    builder.feedback_params(self)
  end

  def to_param
    guid
  end

  def permalink_url(anchor=:ignored, only_path=true)
    article.permalink_url("#{self.class.to_s.downcase}-#{id}",only_path)
  end

  def edit_url(anchor=:ignored, only_path=true)
    blog.url_for(:controller => "/admin/#{self.class.to_s.downcase}s", :action =>"edit", :id => id)
  end

  def delete_url(anchor=:ignored, only_path=true)
    blog.url_for(:controller => "/admin/#{self.class.to_s.downcase}s",
                 :action =>"destroy", :id => id)
  end

  def html_postprocess(field, html)
    helper = ContentTextHelpers.new
    helper.sanitize(helper.auto_link(html)).nofollowify
  end

  def correct_url
    return if url.blank?
    returning(url) do
      url.to_s.gsub!(%r{^(?:http://)?(.+)},"http://\\1")
    end
  end

  def article_allows_this_feedback
    article &&
      blog_allows_feedback? &&
      article_allows_feedback?
  end

  def blog_allows_feedback?
    true
  end

  def akismet_options
    {:user_ip => ip,
      :comment_type => self.class.to_s.downcase,
      :comment_author => originator,
      :comment_author_email => email,
      :comment_author_url => url,
      :comment_content => body}.merge(additional_akismet_options)
  end

  def additional_akismet_options
    { }
  end

  def spam_fields
    [:title, :body, :ip, :url]
  end

  def classify
    begin
      return :spam if blog.default_moderate_comments
      return :ham unless blog.sp_global
    rescue NoMethodError
    end

    # Yeah, three state logic is evil...
    case sp_is_spam? || akismet_is_spam?
    when nil; :spam
    when true; :spam
    when false; :ham
    end
  end

  def sp_is_spam?(options={})
    sp = SpamProtection.new(blog)
    Timeout.timeout(defined?($TESTING) ? 10 : 30) do
      spam_fields.any? do |field|
        sp.is_spam?(self.send(field))
      end
    end
  rescue Timeout::Error => e
    nil
  end

  def akismet
    Akismet.new(blog.sp_akismet_key, blog.base_url)
  end

  def akismet_is_spam?(options={})
    return false if blog.sp_akismet_key.blank?
    begin
      Timeout.timeout(defined?($TESTING) ? 30 : 60) do
        akismet.commentCheck(akismet_options)
      end
    rescue Timeout::Error => e
      nil
    end
  end

  def mark_as_ham!
    mark_as_ham
    save!
  end

  def mark_as_spam!
    mark_as_spam
    save
  end

  def report_as_spam
    return if blog.sp_akismet_key.blank?
    Timeout.timeout(defined?($TESTING) ? 5 : 3600) { akismet.submitSpam(akismet_options) }
  end

  def report_as_ham
    return if blog.sp_akismet_key.blank?
    Timeout.timeout(defined?($TESTING) ? 5 : 3600) { akismet.submitHam(akismet_options) }
  end

  def withdraw!
    withdraw
    self.save!
  end

  def confirm_classification!
    confirm_classification
    self.save
  end
end
