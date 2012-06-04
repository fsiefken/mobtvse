class PostsController < ApplicationController

  ##################
  ## TODO NOTES
  ## the .page functionality that needs reimplementing
  ## is a scope added to the model by the kaminari gem
  ##################

  before_filter :authenticate, :except => [:index, :show, :update_kudo]
  layout :choose_layout

  def index
    #TODO reimplement paging mongo style
    all_posts = nil
    now = DateTime.now
    unless params[:tag]
      all_posts = Post.all(conditions: {:draft=>false, :posted_at=>{"$lte"=>now}},:sort=> [[ :posted_at, :desc ]]).entries
    else
      all_posts = Post.any_in(:tags_array => [params[:tag]]).where(:posted_at=>{"$lte"=>now}).desc(:posted_at).entries
    end
    @posts = Kaminari.paginate_array(all_posts).page(params[:page]).per(10)

    respond_to do |format|
      format.html
      format.xml { render :xml => @posts }
      format.rss { render :layout => false }
    end
  end
  def tag
    @tag = params[:id]
    now = DateTime.now
    @posts = Post.any_in(:tags_array => [@tag]).where(:posted_at=>{"$lte"=>now}).desc(:posted_at).entries
      # we don't want a paginated list here
    #logger.debug("#{@posts.size} posts were found with tag #{@tag}")
    respond_to do |format|
      format.html
    end
  end

  def preview
    @post = Post.new(params[:post])
    @preview = true
    respond_to do |format|
      format.html { render 'show' }
    end
  end

  def admin
    @no_header = true
    @placeholder_post = Post.new
    #todo re-implement the paging mongoid style
    all_published = nil
    unless params[:tag]
      all_published = Post.all(conditions: {draft: false},sort: [[ :posted_at, :desc ]]).entries
    else
      all_published = Post.any_in({:tags_array => [params[:tag]]}).descending(:posted_at).entries
    end
    @tags = Post.tags #Post.tags_with_weight returns [['foo', 2],['bar', 1],['baz', 3]]
    @published = Kaminari.paginate_array(all_published).page(params[:post_page]).per(20)
    @drafts = Kaminari.paginate_array(Post.all(conditions: {draft: true}).entries).page(params[:draft_page]).per(20)
    #logger.debug("Published: #{@published.inspect}")
    #logger.debug("Drafts: #{@drafts.inspect}")
    respond_to do |format|
      format.html
    end
  end

  def show
    @single_post = true
    @post = admin? ? Post.first(conditions: {slug: params[:slug]}) : Post.first(conditions: {slug: params[:slug],  draft: false})
    unless @post.meta_description.blank?
      @meta_description = @post.meta_description
    end
    respond_to do |format|
      if @post.present?
        format.html
        format.xml { render :xml => @post }
      else
        format.any { head status: :not_found  }
      end
    end
  end

  def new
    @no_header = true
    #TODO reimplement paging mongo style
    @posts = Post.all.entries
    #@posts = Post.page(params[:page]).per(20)
    @post = Post.new

    respond_to do |format|
      format.html
      format.xml { render xml: @post }
    end
  end

  def get
    @post = Post.find(params[:id])
    render :text => @post.to_json
  end

  def edit
    @no_header = true
    @post = Post.find(params[:id])
    respond_to do |format|
      format.html
      format.json { render :json => @post }
    end
  end

  def create
logger.debug("XXX in PostsController#create")
    @post = Post.new(params[:post])

    respond_to do |format|
      if @post.save
logger.debug(" saved")
        format.html { redirect_to "/edit/#{@post.id}", :notice => "Post created successfully" }
        format.xml { render :xml => @post, :status => :created, location: @post }
        format.text { render :text => @post.to_json }
      else
logger.debug(" failed to save")
        format.html { render :action => 'new' }
        format.xml { render :xml => @post.errors, :status => :unprocessable_entity}
        format.text { head :bad_request }
      end
    end
  end

  def update
    @post = Post.find(params[:id])
    #@post = Post.first(conditions: {slug: params[:slug]})
    booleanify_params(params)
    respond_to do |format|
      if @post.update_attributes(params[:post])

        format.html { redirect_to "/edit/#{@post.id}", :notice => "Post updated successfully" }
        format.xml { head :ok }
        format.text{ render :text => @post.to_json}
      else
        format.html { render :action => 'edit' }
        format.xml { render :xml => @post.errors, :status => :unprocessable_entity}
        format.text { head :bad_request }
      end
    end
  end

  def update_kudo
     @post = Post.find(params[:id])
     @post.kudos +=1
     @post.save()
     render :nothing=>true
  end

  def destroy
    @post = Post.first(conditions: {id: params[:id]})
    @post.destroy

    respond_to do |format|
      format.html { redirect_to '/admin' }
      format.xml { head :ok }
    end
  end

  private

  def admin?
    session[:admin] == true
  end

  def booleanify_params(params)
    Post.get_boolean_fields.each do |param|
      if params[param] == '1' or params[param] == 'true'
        params[param] = true
      else
        params[param] = false
      end
    end
  end

  def choose_layout
    if ['admin', 'new', 'edit', 'create'].include? action_name
      'admin'
    else
      'application'
    end
  end
end
