class User < ActiveRecord::Base

  has_many :friendships
  has_many :friends, :through => :friendships

  has_many :inverse_friendships, :class_name => "Friendship", :foreign_key => "friend_id"
  has_many :inverse_friends, :through => :inverse_friendships, :source => :user

  TEMP_EMAIL_PREFIX = 'change@me'
  TEMP_EMAIL_REGEX = /\Achange@me/

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable
  devise :database_authenticatable, :registerable, :confirmable,
    :recoverable, :rememberable, :trackable, :validatable, :omniauthable

  validates_format_of :email, :without => TEMP_EMAIL_REGEX, on: :update

  def self.find_for_oauth(auth, signed_in_resource = nil)

    # Get the identity and user if they exist
    identity = Identity.find_for_oauth(auth)

    # If a signed_in_resource is provided it always overrides the existing user
    # to prevent the identity being locked with accidentally created accounts.
    # Note that this may leave zombie accounts (with no associated identity) which
    # can be cleaned up at a later date.
    user = signed_in_resource ? signed_in_resource : identity.user

    # Create the user if needed
    if user.nil?

      # Get the existing user by email if the provider gives us a verified email.
      # If no verified email was provided we assign a temporary email and ask the
      # user to verify it on the next step via UsersController.finish_signup
      email_is_verified = auth.info.email && (auth.info.verified || auth.info.verified_email)
      email = auth.info.email if email_is_verified
      user = User.where(:email => email).first if email

      # Create the user if it's a new registration
      if user.nil?
        user = User.new(
          name: auth.extra.raw_info.name,
          #username: auth.info.nickname || auth.uid,
          email: email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
          password: Devise.friendly_token[0,20]
        )
        user.skip_confirmation!
        user.save!
      end
    end

    # Associate the identity with the user if needed
    if identity.user != user
      identity.user = user
      identity.save!
    end
    user
  end

  def email_verified?
    self.email && self.email !~ TEMP_EMAIL_REGEX
  end

  popular friendship_profile: true

   # You can also use a symbol here but the friendship won't be passed to your method
  after_befriend 'notify_friendship_created value'
  after_unfriend 'notify_unfriended value'

  def notify_friendship_created(friendship)
    puts "#{name} friended #{friendship.friend.name}"
  end

  def notify_unfriended(friendship)
    puts "#{name} unfriended #{friendship.friend.name}"
  end
end

###### SAMPLE #####
@sam = User.create name: "Samuel"
@jackson = User.create name: "Jackson"

@justin = User.create name: "Justin"
@jenny = User.create name: "Jenny"


# Adding and removing friends
@sam.friends_with? @jackson         #=> false
@sam.friended_by? @jackson          #=> false

@sam.befriend @jackson
@sam.friends_with? @jackson         #=> true

@sam.unfriend @jackson
@sam.friends_with? @jackson         #=> false

@jackson.befriend @sam
@sam.friended_by? @jackson          #=> true

@sam.befriend @jackson
@sam.mutual_friends_with? @jackson  #=> true

@sam.follow @jackson
@sam.following? @jackson          #=> true

@jackson.follow @sam
@sam.followers.include? @jackson  #=> true

@justin.befriend @jenny #=> "Justin friended Jenny"
@justin.unfriend @jenny #=> "Justin unfriended Jenny"

