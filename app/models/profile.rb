class Profile < ActiveRecord::Base
  serialize :modules
  validates_uniqueness_of :label
  
  def modules
    read_attribute(:modules) || []
  end
  
  def modules=(perms)
    perms = perms.collect {|p| p.to_sym unless p.blank? }.compact if perms
    write_attribute(:modules, perms)
  end
end
