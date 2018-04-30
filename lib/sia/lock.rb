module Sia
  # Every good safe needs a safe lock
  #
  # Used by Sia::Safe to do the heavy cryptographical lifting
  #
  # * Securely derives its symmetric key from a user's password using
  #   OpenSSL::PKCS5
  # * Uses an OpenSSL::Cipher for encryption
  #
  # Ex:
  #
  #     lock = Sia::Lock.new('pass', 'salt', 1_000, 1_000_000)
  #     lock.encrypt_to_file('Hello World!', '/path/to/secure/file')
  #     File.read('/path/to/secure/file')
  #     # => "\u0016\x8A\x88/%\x90\xDF\u007F\xFC@\xCB\t\u001FTp`(\xBF\x8DR\x9E\x91\x8F\xC1FX\x8F7\xF6-+2"
  #     lock.decrypt_from_file('/path/to/secure/file')
  #     # => "Hello World!"
  #
  class Lock

    # The digest to use. Safes use the length of the digest to make the salt.
    DIGEST = ::OpenSSL::Digest::SHA256

    # @param [String] password
    # @param [String] salt
    # @param [Integer] buffer_bytes The buffer size for reading/writing to file.
    # @param [Integer] digest_iterations Increase this to increase hashing time.
    # @return [Lock]
    #
    def initialize(password, salt, buffer_bytes, digest_iterations)
      @buffer_bytes = buffer_bytes
      @symmetric_key = digest_password(password, salt, digest_iterations)
    end

    # Used for encrypting the index file from memory
    #
    # @param [String] string The string to encrypt
    # @param [String] secure_file Absolute path to the secure file
    #
    def encrypt_to_file(string, secure_file)
      basic_encrypt(StringIO.new(string), secure_file)
    end

    # Used for decrypting the index file into memory
    #
    # @param [String] secure_file Absolute path to the secure file
    # @return [String]
    #
    def decrypt_from_file(secure_file)
      basic_decrypt(StringIO.new, secure_file).string
    end

    # Encrypt a clear file into a secure file, removing the clear file.
    #
    # This is better set up to handle large amounts of data than
    # {#encrypt_to_file}, which has to hold the entire clear string in memory.
    #
    # @param [String] clear_file Absolute path to the clear file.
    # @param [String] secure_file Absolute path to the secure file.
    #
    def encrypt(clear_file, secure_file)
      File.open(clear_file, 'rb') { |r| basic_encrypt(r, secure_file) }
      File.delete(clear_file)
    end

    # Decrypt a secure file into a clear file, removing the secure file.
    #
    # This is better set up to handle large amounts of data than
    # {#decrypt_from_file}, which has to hold the entire clear string in memory.
    #
    # @param [String] clear_file Absolute path to the clear file.
    # @param [String] secure_file Absolute path to the secure file.
    #
    def decrypt(clear_file, secure_file)
      File.open(clear_file, 'wb') { |w| basic_decrypt(w, secure_file) }
      File.delete(secure_file)
    end

    private

    def new_cipher
      OpenSSL::Cipher.new('AES-256-CBC')
    end

    # Get a password digest from the password
    #
    # @param [String] password The password to digest
    # @return [String] The digested password, a binary string
    #
    def digest_password(password, salt, iter)
      len = DIGEST.new.digest_length
      OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iter, len, DIGEST.new)
    end

    def basic_encrypt(clear_io, secure_file)
      cipher = new_cipher.encrypt
      cipher.key = @symmetric_key
      iv = cipher.random_iv
      cipher.iv  = iv

      File.open(secure_file, 'wb') do |w|
        w << iv
        w << cipher.update(clear_io.read(@buffer_bytes)) until clear_io.eof?
        w << cipher.final
      end
    end

    def basic_decrypt(clear_io, secure_file)
      decipher = new_cipher.decrypt
      decipher.key = @symmetric_key
      first_block = true

      File.open(secure_file, 'rb') do |r|
        until r.eof?
          if first_block
            decipher.iv = r.read(decipher.iv_len)
            first_block = false
          else
            clear_io << decipher.update(r.read(@buffer_bytes))
          end
        end
      end

      clear_io << decipher.final

      clear_io

    rescue ::OpenSSL::Cipher::CipherError
      raise Sia::Error::PasswordError, 'Invalid password'
    end

  end # class Lock
end # module Sia
