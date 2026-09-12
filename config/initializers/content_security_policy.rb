# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Rails.application.configure do
#   config.content_security_policy do |policy|
#     policy.default_src :self, :https
#     policy.font_src    :self, :https, :data
#     policy.img_src     :self, :https, :data
#     policy.object_src  :none
#     policy.script_src  :self, :https
#     policy.style_src   :self, :https
#     # Specify URI for violation reports
#     # policy.report_uri "/csp-violation-report-endpoint"
#   end
#
#   # Generate session nonces for permitted importmap, inline scripts, and inline styles.
#   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
#   config.content_security_policy_nonce_directives = %w(script-src style-src)
#
#   # Automatically add `nonce` to `javascript_tag`, `javascript_include_tag`, and `stylesheet_link_tag`
#   # if the corresponding directives are specified in `content_security_policy_nonce_directives`.
#   # config.content_security_policy_nonce_auto = true
#
#   # Report violations without enforcing the policy.
#   # config.content_security_policy_report_only = true
# end



# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|

    # Default
    policy.default_src :self

    # JavaScript
    policy.script_src(
      :self,
      :https,
      "https://cdn.jsdelivr.net",
      "https://checkout.razorpay.com",
      "https://www.youtube.com"
    )

    # CSS
    # unsafe-inline is temporary because the project currently
    # contains many inline <style> blocks.
    policy.style_src(
      :self,
      :https,
      :unsafe_inline,
      "https://fonts.googleapis.com",
      "https://cdn.jsdelivr.net",
      "https://cdnjs.cloudflare.com"
    )

    # Fonts
    policy.font_src(
      :self,
      :https,
      :data,
      "https://fonts.gstatic.com",
      "https://cdn.jsdelivr.net",
      "https://cdnjs.cloudflare.com"
    )

    # Images
    policy.img_src(
      :self,
      :https,
      :data,
      :blob,
      "https://res.cloudinary.com",
      "https://img.youtube.com",
      "https://placehold.co",
      
    )

    # Video / audio
    policy.media_src(
      :self,
      :https,
      :blob,
      "https://res.cloudinary.com"
    )

    # AJAX / Fetch / WebSocket connections
    policy.connect_src(
      :self,
      :https,
      "https://res.cloudinary.com",
      "https://checkout.razorpay.com",
      "https://api.razorpay.com",
      "https://www.youtube.com"
    )

    # Iframes
    policy.frame_src(
      :self,
      :https,
      "https://www.youtube.com",
      "https://www.youtube-nocookie.com",
      "https://youtube.com",
      "https://checkout.razorpay.com"
    )

    # Prevent clickjacking from other sites
    policy.frame_ancestors :self

    # Disable plugins such as Flash
    policy.object_src :none

    # Restrict <base>
    policy.base_uri :self

    # Forms can submit only to this application
    policy.form_action :self

    # Web workers
    policy.worker_src(
      :self,
      :blob
    )

    # Web app manifest
    policy.manifest_src :self

    # Upgrade HTTP resources to HTTPS
    policy.upgrade_insecure_requests
  end

  # Generate a unique CSP nonce for every request.
  config.content_security_policy_nonce_generator =
    ->(_request) { SecureRandom.base64(16) }

  # Nonces are valid for scripts and styles.
  config.content_security_policy_nonce_directives =
    %w[script-src style-src]

  # Automatically add nonce where Rails helpers support it.
  config.content_security_policy_nonce_auto = true

  # IMPORTANT:
  # Keep Report-Only initially so existing pages do not break.
  config.content_security_policy_report_only = true
end