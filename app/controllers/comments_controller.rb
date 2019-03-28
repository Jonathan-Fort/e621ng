class CommentsController < ApplicationController
  respond_to :html, :xml, :json
  respond_to :js, only: [:new, :destroy, :undelete]
  before_action :member_only, :except => [:index, :search, :show]
  skip_before_action :api_check

  def index
    if params[:group_by] == "comment" || request.format == Mime::Type.lookup("application/atom+xml")
      index_by_comment
    elsif request.format == Mime::Type.lookup("text/javascript")
      index_for_post
    else
      index_by_post
    end
  end

  def search
  end

  def new
    @comment = Comment.new(comment_params(:create))
    @comment.body = Comment.find(params[:id]).quoted_response if params[:id]
    respond_with(@comment)
  end

  def update
    @comment = Comment.find(params[:id])
    check_privilege(@comment)
    @comment.update(comment_params(:update))
    respond_with(@comment, :location => post_path(@comment.post_id))
  end

  def create
    @comment = Comment.create(comment_params(:create))
    flash[:notice] = @comment.valid? ? "Comment posted" : @comment.errors.full_messages.join("; ")
    respond_with(@comment) do |format|
      format.html do
        redirect_back fallback_location: (@comment.post || comments_path)
      end
    end
  end

  def edit
    @comment = Comment.find(params[:id])
    check_privilege(@comment)
    respond_with(@comment)
  end

  def show
    @comment = Comment.find(params[:id])
    respond_with(@comment)
  end

  def destroy
    @comment = Comment.find(params[:id])
    check_privilege(@comment)
    @comment.delete!
    respond_with(@comment)
  end

  def undelete
    @comment = Comment.find(params[:id])
    check_privilege(@comment)
    @comment.undelete!
    respond_with(@comment)
  end

private
  def index_for_post
    @post = Post.find(params[:post_id])
    @comments = @post.comments
    render :action => "index_for_post"
  end

  def index_by_post
    tags = params[:tags] || ""
    @posts = Post.tag_match(tags + " order:comment_bump").paginate(params[:page], :limit => 5, :search_count => params[:search])
    @posts.each # hack to force rails to eager load
    respond_with(@posts) do |format|
      format.xml do
        render :xml => @posts.to_xml(:root => "posts")
      end
    end
  end

  def index_by_comment
    @comments = Comment.search(search_params).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@comments) do |format|
      format.atom do
        @comments = @comments.includes(:post, :creator).load
      end
      format.xml do
        render :xml => @comments.to_xml(:root => "comments")
      end
    end
  end

  def check_privilege(comment)
    if !comment.editable_by?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def comment_params(context)
    permitted_params = %i[body post_id]
    permitted_params += %i[do_not_bump_post] if context == :create
    permitted_params += %i[is_deleted] if context == :update
    permitted_params += %i[is_sticky] if CurrentUser.is_moderator?

    params.fetch(:comment, {}).permit(permitted_params)
  end
end
