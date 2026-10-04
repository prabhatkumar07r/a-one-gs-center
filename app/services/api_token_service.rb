class ApiTokenService
  TOKEN_BYTES = 32
  TOKEN_TTL = 30.days

  class << self
    def issue!(user)
      raw_token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
      digest = digest_token(raw_token)

      api_token = user.api_tokens.create!(
        token_digest: digest,
        expires_at: TOKEN_TTL.from_now
      )

      {
        token: raw_token,
        expires_at: api_token.expires_at
      }
    end

    def find_active(raw_token)
      return nil if raw_token.blank?

      digest = digest_token(raw_token)

      token = ApiToken.active.find_by(token_digest: digest)
      return nil unless token

      token.update_columns(last_used_at: Time.current)

      token
    end

    def revoke!(raw_token)
      token = find_active(raw_token)
      return false unless token

      token.revoke!
      true
    end

    private

    def digest_token(raw_token)
      Digest::SHA256.hexdigest(raw_token)
    end
  end
end