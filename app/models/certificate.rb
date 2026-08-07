class Certificate < ApplicationRecord
  belongs_to :user
  belongs_to :course

  has_one_attached :director_signature

  before_create :generate_certificate_no
  after_create :attach_director_signature

  private

  def generate_certificate_no
    self.certificate_no = "AONE-#{Time.current.year}-#{SecureRandom.hex(4).upcase}"
  end

  def attach_director_signature
    director_signature.attach(
      io: File.open(
        Rails.root.join("app/assets/images/director_signature.jpeg")
      ),
      filename: "director_signature.jpeg",
      content_type: "image/jpeg"
    )
  end
end