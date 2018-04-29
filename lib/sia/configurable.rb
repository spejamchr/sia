# Sia-wide and Safe-specific configuration
#
module Sia::Configurable

  DEFAULTS = {
    root_dir: File.join(Dir.home, '.sia_safes').freeze,
    index_name: 'index'.freeze,
    secret_name: 'secret'.freeze,
    digest_iterations: 200_000,
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

    tentatives = options.merge(opt)
    if tentatives[:index_name] == tentatives[:secret_name]
      raise Sia::ConfigurationError,
        ":index_name and :secret_name cannot be equal, but were both " +
        tentatives[:secret_name].inspect
    end

    illegals = opt.keys - DEFAULTS.keys
    unless illegals.empty?
      raise Sia::InvalidOptionError.new(illegals, DEFAULTS.keys)
    end
    options # If nothing is amiss, go ahead and instantiate the options
  end

end
