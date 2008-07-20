class AccountsController < ApplicationController

  before_filter :verify_users, :only => [:login]

  def login
    case request.method
      when :post
      self.current_user = User.authenticate(params[:user_login], params[:user_password])
            
      if logged_in?
        session[:user_id] = self.current_user.id

        flash[:notice]  = _("Login successful")
        redirect_back_or_default :controller => "admin/dashboard", :action => "index"
      else
        flash.now[:notice]  = _("Login unsuccessful")
        @login = params[:user_login]
      end
    end
  end
  
  def signup
    unless User.count.zero? or this_blog.allow_signup == 1
      redirect_to :action => 'login'
      return
    end

    @user = User.new(params[:user])

    if request.post? and @user.save
      self.current_user = @user
      session[:user_id] = @user.id
      flash[:notice]  = _("Signup successful")
      redirect_to :controller => "admin/settings", :action => "index"
      return
    end
  end

  def logout
    self.current_user = nil
    session[:user_id] = nil
  end

  def welcome
  end

  private

  def verify_users
    if User.count == 0
      redirect_to :controller => "accounts", :action => "signup"
    else
      true
    end
  end

end
