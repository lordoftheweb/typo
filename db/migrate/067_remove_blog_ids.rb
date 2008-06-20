class RemoveBlogIds < ActiveRecord::Migration
  def self.up
    drop_column :contents, :blog_id rescue nil
    drop_column :sidebars, :blog_id rescue nil
    drop_column :feedback, :blog_id rescue nil
  end

  def self.down
    add_column :contents, :blog_id, :integer
    add_column :sidebars, :blog_id, :integer
    add_column :feedback, :blog_id, :integer

    default_blog_id = Blog.find(:first, :order => 'id').id

    Content.update_all("blog_id = #{default_blog_id}")
    Feedback.update_all("blog_id = #{default_blog_id}")
    Sidebar.update_all("blog_id = #{default_blog_id}")

    change_column :sidebars, :blog_id, :integer, :null => false
  end
end
