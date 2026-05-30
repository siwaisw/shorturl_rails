class UsersController < ApplicationController
  def new
    redirect_to dashboard_path if logged_in?
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id
      logger.info { "[User] Registered user_id=#{@user.id} ip=#{request.remote_ip}" }
      redirect_to dashboard_path, notice: "Welcome to ShortURL!"
    else
      logger.warn { "[User] Registration failed error=#{@user.errors.full_messages.first.inspect} ip=#{request.remote_ip}" }
      flash.now[:alert] = @user.errors.full_messages.first
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
