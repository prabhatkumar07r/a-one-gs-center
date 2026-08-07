ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Add this line
require "devise"

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors, with: :threads)

    fixtures :all
  end
end