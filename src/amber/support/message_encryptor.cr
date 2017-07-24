require "json"
require "openssl/cipher"

module Amber::Support
  class MessageEncryptor
    getter verifier : MessageVerifier

    def initialize(@secret : Bytes, @cipher = "aes-256-cbc", @digest = :sha1, @sign_secret : Bytes? = nil)
      @verifier = MessageVerifier.new(@secret, digest: @digest)
    end

    # Encrypt and sign a message. We need to sign the message in order to avoid
    # padding attacks. Reference: http://www.limited-entropy.com/padding-oracle-attacks.
    def encrypt_and_sign(message : Slice(UInt8)) : String
      cipher = new_cipher
      cipher.encrypt
      cipher.key = @secret

      # Rely on OpenSSL for the initialization vector
      iv = cipher.random_iv

      encrypted_data = IO::Memory.new
      encrypted_data.write(cipher.update(message))
      encrypted_data.write(cipher.final)

      "#{::Base64.strict_encode encrypted_data}--#{::Base64.strict_encode iv}"
    end

    def encrypt_and_sign(message : String) : String
      encrypt_and_sign(message.to_slice)
    end

    # Decrypt and verify a message. We need to verify the message in order to
    # avoid padding attacks. Reference: http://www.limited-entropy.com/padding-oracle-attacks.
    def decrypt_and_verify(encrypted_message : String) : Bytes
      cipher = new_cipher
      encrypted_data, iv = encrypted_message.split("--").map { |v| ::Base64.decode(v) }

      cipher.decrypt
      cipher.key = @secret
      cipher.iv = iv

      decrypted_data = IO::Memory.new
      decrypted_data.write cipher.update(encrypted_data)
      decrypted_data.write cipher.final
      decrypted_data.to_slice
    rescue OpenSSL::Cipher::Error
      raise Exceptions::InvalidMessage.new
    end

    private def _encrypt(value)
    end

    private def _decrypt(encrypted_message)
    end

    private def new_cipher
      OpenSSL::Cipher.new(@cipher)
    end

    private def verifier
      @verifier
    end
  end
end
