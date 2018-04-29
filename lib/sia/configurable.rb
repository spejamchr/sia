# Sia-wide and Safe-specific configuration
#
module Sia::Configurable

  DEFAULTS = {
    root_dir: File.join(Dir.home, '.sia_safes').freeze,
    index_name: 'index'.freeze,
    buffer_bytes: 512,
  }.freeze

  # The configuration options
  #
  # @return [Hash]
  #
  def options
    (@options ||= defaults).dup
  end

  private

  def validate_options(opt)
    unless opt.is_a? Hash
      raise Sia::ConfigurationError, "Expected Hash but got #{opt.class}"
    end

    illegals = opt.keys - DEFAULTS.keys
    unless illegals.empty?
      raise Sia::InvalidOptionError.new(illegals, DEFAULTS.keys)
    end
    options # If nothing is amiss, go ahead and instantiate the options
  end

end
