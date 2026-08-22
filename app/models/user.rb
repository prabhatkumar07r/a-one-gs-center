class User < ApplicationRecord

  # ================= DEVise =================

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :confirmable,
         :omniauthable,
         omniauth_providers: [:google_oauth2]

  # ================= ASSOCIATIONS =================

  has_one :teacher
  has_one_attached :image

  has_many :enrollments, dependent: :destroy
  has_many :courses, through: :enrollments
  has_many :video_progresses, dependent: :destroy
  has_many :certificates, dependent: :destroy
  has_many :notes, dependent: :destroy

  # ================= GOOGLE LOGIN =================

  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first

    if user
      user
    else
      create do |u|
        u.email = auth.info.email
        u.name = auth.info.name
        u.password = Devise.friendly_token[0, 20]

        # Google already verifies the email
        u.skip_confirmation!
      end
    end
  end

  # ================= DEFAULT ROLE =================

  after_initialize :set_default_role, if: :new_record?

  # ================= ROLES =================

  enum :role, {
    student: "student",
    teacher: "teacher",
    admin: "admin"
  }

  validates :role, presence: true

  # ================= DEVISE EMAIL =================

  def send_devise_notification(notification, *args)

    if notification.to_sym == :confirmation_instructions

      token = args.first

      confirmation_url =
        Rails.application.routes.url_helpers.user_confirmation_url(
          confirmation_token: token,
          host: ENV.fetch("APP_HOST", "localhost:3000"),
          protocol: Rails.env.production? ? "https" : "http"
        )

      html_content = <<~HTML
        <!DOCTYPE html>
        <html>
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
            ">

              <h1 style="color:#172033;">
                Welcome to A-One GS Center
              </h1>

              <p style="color:#555;font-size:16px;">
                Hello #{ERB::Util.html_escape(name.presence || "Student")},
              </p>

              <p style="color:#555;font-size:16px;line-height:1.6;">
                Thank you for creating your account.
                Please confirm your email address by clicking the button below.
              </p>

              <p>
                <a
                  href="#{ERB::Util.html_escape(confirmation_url)}"
                  style="
                    display:inline-block;
                    padding:14px 24px;
                    background:#2563eb;
                    color:#ffffff;
                    text-decoration:none;
                    border-radius:8px;
                    font-weight:bold;
                  "
                >
                  Confirm My Account
                </a>
              </p>

              <p style="color:#777;font-size:14px;">
                If the button does not work, copy and paste this URL:
              </p>

              <p style="
                word-break:break-all;
                font-size:13px;
                color:#2563eb;
              ">
                #{ERB::Util.html_escape(confirmation_url)}
              </p>

              <p style="color:#777;font-size:14px;">
                If you did not create this account, you can safely ignore this email.
              </p>

              <hr>

              <p style="color:#999;font-size:13px;">
                © #{Time.current.year} A-One GS Center
              </p>

            </div>

          </body>
        </html>
      HTML

      text_content = <<~TEXT
        Welcome to A-One GS Center

        Hello #{name.presence || "Student"},

        Thank you for creating your account.

        Please confirm your account using this link:

        #{confirmation_url}

        If you did not create this account, you can safely ignore this email.

        © #{Time.current.year} A-One GS Center
      TEXT

      BrevoService.send_email(
        to: [
          {
            email: email,
            name: name.presence || "Student"
          }
        ],
        subject: "Confirm your A-One GS Center account",
        html_content: html_content,
        text_content: text_content
      )

    else
      super
    end
  end

  private

  def set_default_role
    self.role ||= "student"
  end

end