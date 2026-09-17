# Records successful and failed sign-ins for the Developer Panel.
Rails.application.config.after_initialize do
  Warden::Manager.after_set_user except: :fetch do |user, auth, opts|
    if opts[:event] == :authentication && opts[:scope] == :user
      LoginEvent.record(user: user, email: user.email, success: true, request: auth.request)
    end
  end

  Warden::Manager.before_failure do |env, opts|
    request = ActionDispatch::Request.new(env)
    email = request.params.dig("user", "email")
    if opts[:scope] == :user && request.post? && email.present?
      LoginEvent.record(user: User.find_by(email: email.to_s.strip.downcase), email: email, success: false,
        reason: opts[:message], request: request)
    end
  end
end
