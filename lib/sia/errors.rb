module Sia

  # Class for all custom Sia errors to inherit from
  class SiaError < StandardError; end

  # Raised when creating a safe with the incorrect password
  class PasswordError < SiaError; end

end
