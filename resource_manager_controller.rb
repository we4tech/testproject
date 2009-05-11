# $Id: resource_manager_controller.rb 333 2008-04-07 11:44:39Z hasan $
# *****************************************************************************
# Copyright (C) 2005 - 2007 somewhere in .Net ltd.
# All Rights Reserved.  No use, copying or distribution of this
# work may be made except in accordance with a valid license
# agreement from somewhere in .Net LTD.  This notice must be included on
# all copies, modifications and derivatives of this work.
# *****************************************************************************
# $LastChangedBy: hasan $
# $LastChangedDate: 2008-04-07 17:44:39 +0600 (Mon, 07 Apr 2008) $
# $LastChangedRevision: 333 $
# *****************************************************************************

=begin :rdoc
  Resource manager is used for performing CRUD related functionalities which
  are related with classified core models.

  typically classified ad engine used to controller <tt>Item, Request,
  Category, Location</tt>
  and related mapping configurations.

  = for developer: =
  except Create, Delete and Update related functionalities this class is
  not intended.
=end
class ResourceManagerController < ApplicationController

  # include common functionalities
  include ApplicationHelper

  # include resource helper
  include Resource::UtilHelper

  # include paginated content services
  include Service::PaginationSupportedContent

  # include item view helper
  include ItemViewsHelper

  # verify authentication before performing any action from this controller
  before_filter :protect, :except => [:save_item_details]

  # create new request object.
  public
  def new_request
    # TODO: define context
    # initiate model objects.
    @form_object = Wish.new

    # render template
    render_template(true)
  end

  # store a request object
  # use *layout*, *success_url*, *failure_url*, *render* parameters to
  # customize the default behavior
  public
  def save_request
    logger.debug("storing request object")

    # find user submitted parameter
    form_object = params[:form_object]
    form_object[:category_tree_ref] = ""
    categories = params[:categories]

    old_wish = nil
    wish = Wish.new(form_object)

    # find existing wish id
    wish_id = params[:form_object][:id].to_i
    if wish_id != 0
      wish.id = wish_id
      old_wish = Wish.find(wish_id)
      old_wish.name = wish.name
      old_wish.description = wish.description
      old_wish.category_tree_ref = wish.category_tree_ref
      old_wish.status = wish.status
      old_wish.price = wish.price

      wish = old_wish
    end

    # verify user ownership
    if !old_wish.nil? && !permitted?(old_wish)
      flash[:notice] = "you are not authorized!"
      render_template(false)
      return
    end

    # create new request object
    request_object = ItemRequest.new(wish)

    # set categories
    request_object.add_categories(categories)

    # set user
    request_object << get_active_user()

    # set status
    request_object.base.status = Constant::Item::STATUS_PUBLISHED

    # perform save operations
    if request_object.save
      flash[:notice] = Constant::Message::REQUEST_STORED
      flash[:state] = true
      render_template(true)
    else
      @form_object = request_object.base
      if !categories.nil? && !categories.empty? && categories.first != "0"
        @category_id = categories.first
      end
      flash[:notice] = Constant::Message::REQUEST_STORED_FAILED
      flash[:state] = false
      render_template(false)
    end

  end

  # this method is allowed for get operation, a new variable *item* is assigned.
  # generic render module is also supported by this method.
  def new_item
    @item = Item.new
    render_template(true)
  end

  # edit item object
  def edit_item
    item_id = params[:id].to_i
    logger.debug("opening item for edit mode - #{item_id}")

    begin
      item = Item.find(item_id)
    rescue
      flash[:notice] = "you are not allowed to access this item."
      redirect_to home_with_locale_url()
    end

    if permitted?(item)
      @item = item
      @name = @item.name
      # load all assocated categories
      @categories = @item.category_tree_ref.split(":")

      # load all associated properties and values
      @property_values = @item.property_values || []

      # load all related images
      @related_images = @item.images || []

      # load recent wishes.
      @wish_pages, @wishes = get_paginated_wishes_by_categories(@categories, Constant::PaginationLimit::ITEM_LIST)

      render :template => "advertise/create"
    else
      flash[:notice] = "you are not allowed to access this item."
      redirect_to home_with_locale_url()
    end
  end

  # first step to take the required information
  # this step doesnt require any authentication
  # the information which will be collected fromt his step
  # will be kept into the session space if user is not logged on.
  # otherwise this step will move to step - 2
  #
  # if this step will validate categories and name if not found it will
  # mark an error message
  def save_item_details
    logger.debug("Item creational wizard has been started - 1, "+
                 "collect all required information")
    # retrieve parameter from http request
    @name = get_from_wizard_scope(:name) || params[:name]
    @new_category = get_from_wizard_scope(:new_category) || params[:new_category]
    @categories = get_from_wizard_scope(:categories) || params[:categories]
    logger.debug("Item name - #{@name}, categories - #{@categories} new_category - #{@new_category}")

    # validate parameters
    errors = validate_parameters(@name, @categories, @new_category)

    # handle error request
    if errors
      logger.debug("Error occured - #{errors}")
      message = ""
      errors.each do |k, v|
        message << "&nbsp;'#{k}' #{v}&nbsp;"
      end
      flash[:notice] = message
      @errors = errors
      redirect_to home_url() and return
    end

    # if user is not logged in just bring the login page,
    # beforing bringing the login page store all records in session
    unless logged_in?
      logger.debug(%{user is not logged on, storing everything in session
                    and protect this page with calling back the login page.})
      store_parameters() and protect(item_save_details_url()) and return
    else
      cleanup_wizard_scope()
      load_properties(@categories)
      @ajax_request = true
    end
  end

  def preview_item
    item = Item.new(params[:item])
    user = get_active_user()
    render :partial => "/browse/item-parts/advertise/preview",
        :locals => {:item => item, :user => user}
  end
  # store submitted item to the storage. if an error occured this returns to
  # the front page. with error message and the reason which is also
  # flashed in a message box.
  def save_item
    logger.debug("performing item saving operation.")

    old_item = nil

    # create new item from the request parameters
    item = Item.new(params[:item])

    # find item id
    item_id = params[:item][:id].to_i
    if item_id != 0
      item.id = item_id
      old_item = Item.find(item_id)
      old_item.name = item.name
      old_item.description = item.description
      old_item.location_id = item.location_id
      old_item.category_id = item.category_id
      old_item.category_tree_ref = item.category_tree_ref
      old_item.status = item.status
      old_item.updated_at = Time.now
      item = old_item
    end

    # verify user ownership
    if !old_item.nil? && !permitted?(old_item)
      flash[:notice] = "you are not authorized!".t
      render_template(false)
      return
    end

    # retrieve categories, properties and images
    categories = params[:categories].to_a || []
    properties = params[:properties].to_a || []
    images = params[:images] || []
    new_category = params[:new_category] || nil

    # set active user as the author of the item
    item.user_id = get_active_user.id

    # create new item request object
    item_request = ItemRequest.new(item)
    item_request.add_categories(categories)
    item_request.add_properties(properties)
    item_request.add_images(images)
    item_request.new_category(new_category)   

    # perform the step by step operation
    if item_request.save()
      logger.debug("Successfully completed save operation.")
      flash[:notice] = "congratulation!!, your ad has been published.".t
      setup_global_variables(item, categories, properties, images)
      redirect_to browse_item_url(item, item.categories.last)
    else
      logger.debug("Failed to complete the save operation.")
      flash[:notice] = "we are sorry for not accepting your ad, please try again.".t
      setup_global_variables(item_request.base, categories, properties, images)
      redirect_to :back
    end
  end

  public
  def upload_image
    # show existing images
    @item = Item.find(params[:id])

    # check user ownership
    if !permitted?(@item)
      flash[:notice] = "you are not authorized!".t
      render_template(false) and return
    end

    @images = @item.images
    render :template => 'image/upload', :layout => false
  end

  public
  def save_image
    @item = Item.find(params[:id])

    # check user ownership
    if !permitted?(@item)
      flash[:notice] = "you are not authorized!".t
      render_template(false)
      return
    end

    image = Image.new()
    image.set_file_data(params[:image][:file_data])
    image.user_id = @item.user_id
    if image.save
      redirect_to :action => "upload_image", :id => @item.id
    end
    @item.images << image
    
    flash[:notice] = "failed to upload image!".t    
  end

  public
  def crop_image
    begin
      @image = Image.find(params[:id])
    rescue
      flash[:message] = "image not found"
    end
    render :template => "image/crop", :layout => false
        
    # check user ownership
    if !permitted?(@image)
      flash[:notice] = "you are not authorized!".t
      render_template(false)
      return
    end
  end

  public
  def update_crop
    crop_x1 = params[:crop][:x1].to_i
    crop_y1 = params[:crop][:y1].to_i
    crop_x2 = params[:crop][:x2].to_i
    crop_y2 = params[:crop][:y2].to_i

    # generate parameters for Magick image crop
    x = (crop_x1 < crop_x2) ? crop_x1 : crop_x2
    y = (crop_y1 < crop_y2) ? crop_y1 : crop_y2
    width = (crop_x1 - crop_x2).abs
    height = (crop_y1 - crop_y2).abs

    image_id = params[:id]
    # load source image
    image = Image.find(image_id)

    if image.nil?
      error_page("wrong image")
      return
    end

    # check user ownership
    if !permitted?(image)
      flash[:notice] = "you are not authorized!".t
      render_template(false)
      return
    end


    # see if any previously cropped image exists. it will be deleted later
    prev_image = Image.find(:first, :conditions => {:parent_id => image_id, :version => 'icon'})

    # create one if couldn't find any
    if prev_image.nil?
      prev_image = Image.new()
      prev_image.user_id = image.user_id
      prev_image.parent_id = image.id
      prev_image.version = 'icon'
    end

    img = Magick::Image.read(image.full_path).first

    # crop and save the crop image
    cropped = img.crop(x, y, width, height)

    # resize to meet maximum height, width
    dimension = ApplicationConfig::Image::SIZES[:icon].split("x")
    cropped.resize!(dimension[0].to_i, dimension[1].to_i)
    prev_image.set_temp_file_data(cropped)
    prev_image.save

    redirect_to :action => 'upload_image', :id => image.items[0].id
  end

  public
  def bookmark_add
    item_id = params[:id]
    item = Item.find(item_id)
    if item.nil?
      return
    end
    user = get_active_user()

    if Bookmark.add(user, item)
      @content = render_bookmark_link(item)
    end
    render :template => "resource_manager/bookmark", :layout => false
  end

  public
  def bookmark_remove
    item_id = params[:id]
    item = Item.find(item_id)
    if item.nil?
      return
    end

    user = get_active_user()
    if Bookmark.remove(user, item)
      @content = render_bookmark_link(item)      
    end
    render :template => "resource_manager/bookmark", :layout => false
  end

  private
  def render_template(p_success)
    # find required parameters
    layout_name = params[:layout] || Constant::Global::DEFAULT_LAYOUT
    template_partial = params[:render]
    success_url = params[:success_url]
    failure_url = params[:failure_url]

    # forward for success url
    if p_success && !success_url.nil?
      redirect_to success_url and return
    end

    # forward for failure url
    if !p_success && !failure_url.nil?
      redirect_to failure_url and return
    end

    # render template with layout
    if !template_partial.nil?
      render template_partial, :layout => layout_name and return
    else
      render :layout => layout_name and return
    end
  end
end
