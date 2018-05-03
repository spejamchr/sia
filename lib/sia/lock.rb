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
    DIGEST = OpenSSL::Digest::SHA256

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
    # @param [Pathname] string The string to encrypt
    # @param [Pathname] secure Absolute path to the secure file
    #
    def encrypt_to_file(string, secure)
      secure.open('wb') { |s| basic_encrypt(StringIO.new(string), s) }
    end

    # Used for decrypting the index file into memory
    #
    # @param [Pathname] secure Absolute path to the secure file
    # @return [String]
    #
    def decrypt_from_file(secure)
      secure.open('rb') { |s| basic_decrypt(StringIO.new, s).string }
    end

    # Encrypt a clear file into a secure file, removing the clear file.
    #
    # This is better set up to handle large amounts of data than
    # {#encrypt_to_file}, which has to hold the entire clear string in memory.
    #
    # @param [Pathname] clear Absolute path to the clear file.
    # @param [Pathname] secure Absolute path to the secure file.
    #
    def encrypt(clear, secure)
      clear.open('rb') { |c| secure.open('wb') { |s| basic_encrypt(c, s) } }
      clear.delete
    end

    # Decrypt a secure file into a clear file, removing the secure file.
    #
    # This is better set up to handle large amounts of data than
    # {#decrypt_from_file}, which has to hold the entire clear string in memory.
    #
    # @param [Pathname] clear Absolute path to the clear file.
    # @param [Pathname] secure Absolute path to the secure file.
    #
    def decrypt(clear, secure)
      clear.open('wb') { |c| secure.open('rb') { |s| basic_decrypt(c, s) } }
      secure.delete
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

    def basic_encrypt(clear_io, secure_io)
      cipher = new_cipher.encrypt
      cipher.key = @symmetric_key
      iv = cipher.random_iv
      cipher.iv  = iv

      secure_io << iv
      until clear_io.eof?
        secure_io << cipher.update(clear_io.read(@buffer_bytes))
      end
      secure_io << cipher.final
    end

    def basic_decrypt(clear_io, secure_io)
      decipher = new_cipher.decrypt
      decipher.key = @symmetric_key
      first_block = true

      until secure_io.eof?
        if first_block
          decipher.iv = secure_io.read(decipher.iv_len)
          first_block = false
        else
          clear_io << decipher.update(secure_io.read(@buffer_bytes))
        end
      end

      clear_io << decipher.final

      clear_io

    rescue OpenSSL::Cipher::CipherError
      raise Sia::Error::PasswordError, 'Invalid password'
    end

  end # class Lock
end # module Sia
