# frozen_string_literal: true

class InvitationsController < ApplicationController
  layout "pages"
  skip_before_action :authenticate_user!

  before_action :load_invitation
  before_action :require_pending

  # GET /invitations/:token
  def show
    return unless user_signed_in?

    if current_user.email == @entity_user.invited_email
      accept_and_redirect
    else
      flash.now[:alert] = "You are signed in as #{current_user.email}, but this invitation was sent to " \
                           "#{@entity_user.invited_email}. Sign out to accept it with that account."
    end
  end

  # GET /invitations/:token/register
  def register
    return redirect_to invitation_path(params[:token]) if user_signed_in?

    @user = User.new(email: @entity_user.invited_email)
  end

  # POST /invitations/:token/register
  def create_account
    return redirect_to invitation_path(params[:token]) if user_signed_in?

    @user = User.new(
      email: @entity_user.invited_email,
      password: account_params[:password],
      password_confirmation: account_params[:password_confirmation]
    )

    if @user.save
      @entity_user.accept_for!(@user)
      sign_in(@user)
      redirect_to entity_path(@entity_user.entity), notice: "Welcome! You've joined #{@entity_user.entity.name}."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :register, status: :unprocessable_content
    end
  end

  private

  def load_invitation
    @entity_user = EntityUser.find_by(invitation_token: params[:token])

    redirect_to root_path, alert: "This invitation link is invalid." unless @entity_user
  end

  def require_pending
    return if @entity_user&.pending?

    redirect_to root_path, notice: "This invitation has already been accepted."
  end

  def accept_and_redirect
    @entity_user.accept_for!(current_user)
    redirect_to entity_path(@entity_user.entity), notice: "Welcome! You've joined #{@entity_user.entity.name}."
  end

  def account_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
