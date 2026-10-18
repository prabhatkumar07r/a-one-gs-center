
# frozen_string_literal: true

SitemapGenerator::Sitemap.default_host = "https://aonegscenter.com"

# Generate a normal sitemap.xml instead of sitemap.xml.gz
SitemapGenerator::Sitemap.compress = false

SitemapGenerator::Sitemap.create do
  # Homepage is included automatically.
  # Add only additional public pages here.
end
