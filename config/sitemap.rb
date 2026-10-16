
# frozen_string_literal: true

SitemapGenerator::Sitemap.default_host = "https://aonegscenter.com"

SitemapGenerator::Sitemap.create do
  add "/", priority: 1.0, changefreq: "weekly"
end
