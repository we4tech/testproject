class UserController < ApplicationController

  include ApplicationHelper
  before_filter :protect, :except => :profile
  layout "iframe", :except => :show_user
  layout "template2", :only => :show_user

  def profile
    user_id = params[:id].to_i

    # halt process if user id is 0
    if user_id == 0
      raise "Do you think user should have '0' id?, we don't think so, therefore we say goodbye here!!, see you one next page!"
    end

    # find user object
    @user = User.find(user_id)

    # set category view style (list or cloud)
    set_category_view_style()

    # retrieve all items which are created by this user
    @items_pages, @items = paginate :items,
                                    :order => "id DESC",
                                    :per_page => 5,
                                    :conditions => {:user_id => user_id}
    # set partial heading text
    @say_to = %{#{@user.full_name} wants to sell...}

    # find all request from this user
    @wishe_pages, @wishes = paginate :wish,
                                     :order => "id DESC",
                                     :per_page => 5,
                                     :conditions => {:user_id => user_id}
  end

  # load user profiles and information
  def show_user
    @user = get_active_user()
    render :template => "user/update"
  end

  # update user profiles
  def update

    # collect request parameters.
    user = User.new(params[:user])
    existing_user = User.find(get_active_user().id)
    location_id = params[:location_id].to_i

    # transfer new user to old user
    existing_user.full_name = user.full_name
    existing_user.location_id = location_id
#    existing_user.mobile = user.mobile
#    existing_user.email = user.email
    # change password
    if !user.password.nil? && !user.password.empty?
      new_password = User.md5(user.password)
      if new_password != existing_user.password
        logger.debug("updating password.")
        existing_user.password = new_password
      end
    end

    if location_id != 0 && existing_user.update
      # remove existing location tree and recreate the mapping
      LocationHelper::LocationUtil.destroy_location_tree(existing_user.id)
      LocationHelper::LocationUtil.store_location_tree(existing_user, location_id)

      # update session
      session[:user] = existing_user
      flash[:notice] = "successfully updated your information."
      redirect_to :back
    else
      # set in global variable
      @user = existing_user
      # set message
      flash[:notice] = "failed to update your information."
      # redirect to the home page
      redirect_to :back
    end
  end

  def display_contact_information
    user = User.find(params[:id].to_i)
    if verify_recaptcha(user)
      session[:approved_user] = user.id
    else
      flash[:notice] = "invalid captcha"
    end
    redirect_to :back
  end

end
