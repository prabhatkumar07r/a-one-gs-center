class UsersMailer < Devise::Mailer
  helper :application

  include Devise::Controllers::UrlHelpers
  include Rails.application.routes.url_helpers

  def confirmation_instructions(record, token, opts = {})
    @resource = record
    @token = token

    confirmation_url = user_confirmation_url(
      confirmation_token: token,
      host: ENV.fetch(
        "APP_HOST",
        "a-one-gs-center.onrender.com"
      ),
      protocol: "https"
    )

    html = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <title>Confirm your account</title>
        </head>

        <body style="
          margin:0;
          padding:0;
          background:#f5f7fb;
          font-family:Arial,Helvetica,sans-serif;
        ">

          <div style="
            max-width:600px;
            margin:40px auto;
            background:#ffffff;
            border-radius:12px;
            padding:40px;
            box-shadow:0 4px 20px rgba(0,0,0,0.08);
          ">

            <h1 style="
              color:#172033;
              margin-top:0;
            ">
              Welcome to A-One GS Center
            </h1>

            <p style="
              color:#555;
              font-size:16px;
              line-height:1.6;
            ">
              Hello #{ERB::Util.html_escape(@resource.name.presence || "Student")},
            </p>

            <p style="
              color:#555;
              font-size:16px;
              line-height:1.6;
            ">
              Thank you for creating your account.
              Please confirm your email address by clicking the button below.
            </p>

            <div style="margin:30px 0;">

              <a href="#{ERB::Util.html_escape(confirmation_url)}"
                 style="
                   display:inline-block;
                   padding:14px 24px;
                   background:#2563eb;
                   color:#ffffff;
                   text-decoration:none;
                   border-radius:8px;
                   font-weight:bold;
                 ">
                Confirm My Account
              </a>

            </div>

            <p style="
              color:#777;
              font-size:14px;
              line-height:1.6;
            ">
              If the button does not work, copy and paste this URL into your
              browser:
            </p>

            <p style="
              word-break:break-all;
              font-size:13px;
              color:#2563eb;
            ">
              #{ERB::Util.html_escape(confirmation_url)}
            </p>

            <p style="
              color:#777;
              font-size:14px;
              line-height:1.6;
            ">
              If you did not create this account, you can safely ignore this email.
            </p>

            <hr style="
              border:0;
              border-top:1px solid #eeeeee;
              margin:30px 0;
            ">

            <p style="
              color:#999;
              font-size:13px;
            ">
              © #{Time.current.year} A-One GS Center
            </p>

          </div>

        </body>
      </html>
    HTML

    text = <<~TEXT
      Welcome to A-One GS Center

      Hello #{@resource.name.presence || "Student"},

      Thank you for creating your account.

      Please confirm your email address using this link:

      #{confirmation_url}

      If you did not create this account, you can safely ignore this email.

      © #{Time.current.year} A-One GS Center
    TEXT

    BrevoService.send_email(
      to: [
        {
          email: @resource.email,
          name: @resource.name.presence || "Student"
        }
      ],
      subject: "Confirm your A-One GS Center account",
      html_content: html,
      text_content: text
    )
  end
end