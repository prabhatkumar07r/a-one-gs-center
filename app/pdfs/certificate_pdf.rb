require "prawn"
require "rqrcode"

class CertificatePdf < Prawn::Document

  def initialize(certificate)

    super(
      page_size: "A4",
      page_layout: :landscape,
      margin: 40
    )

    @certificate = certificate


    # Border
    stroke_color "000000"
    line_width 3
    stroke_rectangle [0, cursor], bounds.width, bounds.height


    # Logo

    logo_path = Rails.root.join(
      "app/assets/images/logo.jpeg"
    )

    if File.exist?(logo_path)
      image logo_path,
        width: 90,
        position: :center
    end


    move_down 20


    text "A ONE GS ART'S AND COMPETITIVE CLASSES",
      size: 26,
      style: :bold,
      align: :center


    move_down 15


    text "CERTIFICATE OF COMPLETION",
      size: 24,
      style: :bold,
      align: :center


    move_down 40


    text "This certificate is proudly presented to",
      size: 16,
      align: :center


    move_down 20


    text @certificate.user.name,
      size: 32,
      style: :bold,
      align: :center


    move_down 20


    text "For successfully completing the course",
      size: 16,
      align: :center


    move_down 15


    text @certificate.course.Course_name,
      size: 24,
      style: :bold,
      align: :center



    move_down 30


    text "Certificate No : #{@certificate.certificate_no}",
      size: 12,
      align: :center


    text "Issued On : #{@certificate.issued_on.strftime("%d %B %Y")}",
      size: 12,
      align: :center



    # Signature

    move_down 40


    if @certificate.director_signature.attached?

      image(
        StringIO.new(
          @certificate.director_signature.download
        ),
        width: 100,
        position: :right
      )

    end


    text "Director",
      align: :right



    # QR Code

    move_down 20


    verification_url =
      "http://localhost:3000/certificates/#{@certificate.id}"


    qrcode = RQRCode::QRCode.new(
      verification_url
    )


    png = qrcode.as_png(
      size: 150
    )


    image(
      StringIO.new(png.to_s),
      width: 80,
      position: :left
    )


    text "Scan QR to Verify Certificate",
      size: 10,
      align: :left


  end

end