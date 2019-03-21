class Admin < ActiveRecord::Base
  UnsupportedDeviceNotification = Class.new(StandardError)

  include HasLanguage
  include HasSessions

  NOTIFICATIONS = %w[new_inscription new_absence]
  RIGHTS = %w[superadmin admin standard readonly none]

  scope :notification, ->(notification) { where('? = ANY (notifications)', notification) }

  validates :name, presence: true
  validates :rights, inclusion: { in: RIGHTS }
  validates :email, presence: true, uniqueness: true, format: URI::MailTo::EMAIL_REGEXP

  def notifications=(notifications)
    super(notifications.select(&:presence).compact)
  end

  def superadmin?
    rights == 'superadmin'
  end

  def right?(right)
    RIGHTS.index(self[:rights]) <= RIGHTS.index(right)
  end
end
