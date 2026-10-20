require "openssl"

module Portal
  # Reads the customer id from the signed cookie the identity service sets.
  module Session
    COOKIE = "mw_session".freeze

    def self.customer_id(request)
      value = request.cookies[COOKIE] or return nil
      id, signature = value.split("--", 2)
      return nil unless signature && OpenSSL.secure_compare(sign(id), signature)

      id
    end

    def self.sign(id)
      OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("SESSION_SECRET"), id)
    end
  end
end
