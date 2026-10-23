Cloudinary.config do |config|
  config.cloud_name = ENV["CLOUDINARY_CLOUD_NAME"] if ENV["CLOUDINARY_CLOUD_NAME"].present?
  config.api_key = ENV["CLOUDINARY_API_KEY"] if ENV["CLOUDINARY_API_KEY"].present?
  config.api_secret = ENV["CLOUDINARY_API_SECRET"] if ENV["CLOUDINARY_API_SECRET"].present?
end