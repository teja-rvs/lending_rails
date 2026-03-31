module RequestAuthHelpers
  def set_signed_session_cookie(session_record)
    cookie_jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::TestRequest.create(Rails.application.env_config),
      {}
    )
    cookie_jar.signed[:session_id] = session_record.id
    cookies[:session_id] = cookie_jar[:session_id]
  end
end

RSpec.configure do |config|
  config.include RequestAuthHelpers, type: :request
end
