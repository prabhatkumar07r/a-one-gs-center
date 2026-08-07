module ApplicationHelper
  def website_name
    "A One GS Art's & Competitive Classes"
  end

  def website_logo
    image_tag("logo.jpeg", alt: website_name, width: 60)
  end

  def website_brand
    link_to homepage_path, class: "navbar-brand d-flex align-items-center" do
      website_logo + content_tag(:span, website_name, class: "ms-2 fw-bold")
    end
  end
end
