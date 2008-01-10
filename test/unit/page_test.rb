require File.dirname(__FILE__) + '/../test_helper'

class PageTest < Test::Unit::TestCase
  def setup
    @page = Page.find(contents(:first_page))
  end

  def test_permalink_url
    p = contents(:first_page)
    assert_equal 'http://myblog.net/pages/page_one', p.permalink_url
  end

  def test_edit_url
    p = contents(:first_page)
    assert_equal "http://myblog.net/admin/pages/edit/#{contents(:first_page).id}", p.edit_url
  end

  def test_delete_url
    p = contents(:first_page)
    assert_equal "http://myblog.net/admin/pages/destroy/#{contents(:first_page).id}", p.delete_url
  end

  def test_validate
    a = Page.new
    a.name = 'a-new-name'
    a.title = 'A Fabulous Page yo!'
    a.body = 'x'

    assert a.save

    b = Page.new
    b.name = a.name
    b.body = a.body
    b.title = a.title

    assert !b.save
  end

  def test_default_filter
    a = Page.find(:first)
    assert_equal 'textile', a.default_text_filter.name
  end
end
