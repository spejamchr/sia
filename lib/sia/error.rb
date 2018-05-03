module Sia
  # Sia-specific errors live here
  #
  # To catch any Sia error, just rescue `Sia::Error`.
  #
  #     begin
  #       # Code stuffs
  #     rescue Sia::Error
  #       # Handle the exceptiom
  #     end
  #
  class Error < StandardError

    # Raised when creating a safe with the incorrect password
    class PasswordError < Error; end

    # Raised when attempting to set bad configuration
    class ConfigurationError < Error; end

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

    # Raised with in-place safes when trying to close a file not in the safe_dir
    class FileOutsideScopeError < Error; end

  end
end
