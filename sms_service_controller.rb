class SmsServiceController < ApplicationController

  #searchable item query field
  FIELD_MERGED = "merged_text"
  # rejected words
  REJECTED_WORDS = ["is", "this", "that", "was", "were", "those",
      "the", "there", "here", "am", "have", "has",
      "had", "been", "being", "they", "my", "whould",
      "should", "have", "in", "of", "for", "then", "that"]

  def find_ad
    mobile_number = params[:from]
    sms_content = params[:content]
    #split the string
    sms_content = sms_content.split("\s")
    #avoid the rejected words
    sms_content = sms_content - REJECTED_WORDS
    #remove the first 2 keywords from sms_content
    sms_content = sms_content[2..sms_content.length]
    #join the rest of the keywords and split it with comma
    sms_content = sms_content.join(" ").split(",")

    keywords = sms_content.first
    price = sms_content.last

    # use fuzzy search for looking up appropriate content
    separated_keywords = keywords.split("\s")
    keywords = separated_keywords.join("~ ")
    keywords = "#{keywords}~"

    #run query, check the content length for keywords and price
    #and set "-" for price range if its not there.
    query = "merged_text: #{keywords}"
    if sms_content.length > 1
      if !price.match(/\-/)
        price = "0-#{price}"
      end
      query << "AND #price[#{price.strip}]"
    end

    #search items through index_service
    result = IndexService.find(query, 0, 5)
    if result.nil? && result == 0
      response = " no result found."
    else
      response = "#{result.max_rows} items found, "
      result.each do|e_item_id|
        #ask index service to return item object
        index_item = IndexService.get_item(e_item_id)
        #find item_id from index and retrieve items using this id
        item = Item.find(index_item["item_id"])
        response << "##{item.id}, #{item.name}, #{item.price}, item owner:@#{item.user.user_name} "
      end
    end
    response << query
    #send text output to browser
    render :text => response
  end

  def view_ad
    mobile_number = params[:from]
    item_id = params[:content]
    item_id = item_id.split("\s")
    item_id = item_id - REJECTED_WORDS
    item_id = item_id[2..item_id.length].first

    #find item
    item = Item.find(item_id.to_i)
    #build response for reply sms
    response = "#item-id:#{item.id}, item-name: #{item.name}, price: #{item.price} tk"

    #find last location of the item
    last_location = item.locations.last
    if last_location
      response << ", location: #{last_location.name}"
    end

    #find last categories of the item
    last_category = item.categories.last
    if last_category
      response << ", item category: #{last_category.name},
                       #send comment: @#{item.user.user_name}  #{item.id} your message"
    end
    #@emon1, 121 <your message>
    # send text output to browser
    render :text => response
  end

  def post_ad
    # retrieve mobile number
    # retrieve & parse requested sms content
    # |post ad|macbook pro 16 2.16Ghz dual core|,50000, jashim uddin road
    mobile_number = params[:from]

    # find user by the given mobile number
    user = User.find(:first, :conditions => {:mobile => mobile_number})
    if user.nil?
      render :text => "you are not registered user, please send reg <your_nick> to 5455"
      return
    end
    item_content = params[:content]
    item_content = item_content.split("\s")
    item_content = item_content - REJECTED_WORDS
    item_content = item_content[2..item_content.length]
    item_content = item_content.join(" ").split(",")
    # find item title
    name = item_content[0]
    # find item price
    price = item_content[1]
    # find item location
    location = item_content[2]

    # create item object
    item = Item.new()
    item.name = name
    item.price = price
    #item.location = location

    # create new ItemRequest
    item_request = ItemRequest.new(item)
    category = Category.find(:first, :conditions => {:name => "sms"})
    item_request.add_category(category)
    item_request.add_location(user.locations.last)
    item_request.add_user(user)
    item.location_id = user.locations.last.id
    if item_request.save()
      response = "#{item.id},#{item.name}#{item.price}"
      render :text => response
      # use category suggestion system to find the most appropriate category
      # if category not found use "sms" category as the default one
      # store item
      # create response
      # send resonse to the browser
    else
      render :text => "sorry can't store your ad. #{item.errors.inspect}"
    end
  end

  def comment_ad
    mobile_number = params[:from]
    comment_content = params[:content]
    # find user by mobile number
    user = User.find(:first, :conditions => {:mobile => mobile_number})
    if user.nil?
      render :text => "you are not registered user, please send reg <your_nick> to 5455"
      return
    end
    # split the comment content
    comment_content = comment_content.split("\s")
    # avoid the first keyword"@user_name"
    comment_content  = comment_content[1..comment_content.length]

    # comment contents
    item_id = comment_content[0].to_i
    comment_texts = comment_content[1..comment_content.length].join(" ")
    comment_type = Constant::Comment::PRIVATE

    # create comment object
    comment = Comment.new()
    comment.item_id = item_id
    comment.user_id = user.id
    comment.content = comment_texts
    comment.comment_type = comment_type
    if comment.save()
      render :text => "your comment is created"
    else
      render :text => "sorry you need to sign up to place a comment"
    end

  end

end
