module ApplicationHelper
  def time_remaining(expires_at)
    diff = expires_at - Time.current
    return { label: "Expired", expired: true } if diff <= 0

    days  = (diff / 1.day).floor
    hours = ((diff % 1.day)  / 1.hour).floor
    mins  = ((diff % 1.hour) / 1.minute).floor

    label = if days >= 365
      "#{(days / 365.0).floor}y #{((days % 365) / 30.0).floor}mo"
    elsif days >= 30
      "#{(days / 30.0).floor}mo #{days % 30}d"
    elsif days > 0
      "#{days}d #{hours}h"
    elsif hours > 0
      "#{hours}h #{mins}m"
    else
      "#{mins}m"
    end

    { label: label, expired: false }
  end
end
