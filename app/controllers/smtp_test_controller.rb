require "socket"

class SmtpTestController < ApplicationController
  def index
    begin
      socket = TCPSocket.new("smtp-relay.brevo.com", 587)
      socket.close

      render plain: "CONNECTED"
    rescue => e
      render plain: "#{e.class}\n#{e.message}"
    end
  end
end