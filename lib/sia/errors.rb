module Sia

  # Class for all custom Sia errors to inherit from
  class SiaError < StandardError; end

  # Raised when creating a safe with the incorrect password
  class PasswordError < SiaError; end

  # Raised when attempting to set bad configuration
  class ConfigurationError < SiaError; end

  # Raised when trying to set invalid option(s)
  class InvalidOptionError < ConfigurationError
    def initialize(invalids, available)
      msg = <<~MSG
        Got invalid option(s):
          #{invalids.map(&:inspect).join("\n  ")}
        Available options:
          #{available.map(&:inspect).join("\n  ")}
      MSG
      super(msg)
    end
  end

end
