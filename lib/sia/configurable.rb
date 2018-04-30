# Sia-wide and Safe-specific configuration
#
# Any Sia-wide custom configuration is passed along to new safes.
#
#     Sia.options
#     # => {:root_dir=>"~/.sia_safes", :index_name=>".sia_index", ...}
#     Sia.config(root_dir: '/custom/dir')
#     # => {:root_dir=>"/custom/dir", :index_name=>".sia_index", ...}
#     Sia::Safe.new(name: 'test', password: 'secret').options
#     # => {:root_dir=>"/custom/dir", :index_name=>".sia_index", ...}
#
# Safes can only be configured at creation. There is intentionally no API for
# configuring safes that already exist.
#
#     safe = Sia::Safe.new(name: 'test', password: 'secret', index_name: 'hi')
#     safe.options
#     # => {:root_dir=>"/custom/dir", :index_name=>"hi", ...}
#
# Hmm... the `:root_dir` option is still set to our custom directory before, but
# we don't want to use that anymore. We could manually reset it back to its
# default, or we can just use {Sia.set_default_options!}.
#
#     Sia.set_default_options!(:root_dir)
#     safe = Sia::Safe.new(name: 'test', password: 'secret', index_name: 'hi')
#     safe.options
#     # => {:root_dir=>"~/.sia_safes", :index_name=>"hi", ...}
#
module Sia::Configurable

  # Configuration defaults for Sia as a whole and for individual safes
  #
  # `:root_dir` - The directory holding all the safes. Within this directory,
  #     each safe will have its own directory
  #
  # `:index_name` - The name of the encrypted index file within the safe
  #     directory. It hold information like which files are in the safe and when
  #     they were last opened/closed.
  #
  # `:salt_name` - The name of the file within the safe directory that holds the
  #     salt string.
  #
  # `:digest_iterations` - Changes how long computing the symmetric key from the
  #     password will take. The longer the computation takes, the harder for
  #     someone to break into the safe.
  #
  # `:buffer_bytes` - The buffer size to use when reading/writing files.
  #
  DEFAULTS = {
    root_dir: File.join(Dir.home, '.sia_safes').freeze,
    index_name: '.sia_index'.freeze,
    salt_name: '.sia_salt'.freeze,
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
      raise Sia::Error::ConfigurationError, "Expected Hash but got #{opt.class}"
    end

    illegals = opt.keys - DEFAULTS.keys
    unless illegals.empty?
      raise Sia::Error::InvalidOptionError.new(illegals, DEFAULTS.keys)
    end

    tentatives = options.merge(opt)
    if tentatives[:index_name] == tentatives[:salt_name]
      raise Sia::Error::ConfigurationError,
        ":index_name and :salt_name cannot be equal, but were both " +
        tentatives[:salt_name].inspect
    end

    must_be String, opt, :root_dir, :index_name, :salt_name
    must_be Integer, opt, :digest_iterations, :buffer_bytes

    options # If nothing is amiss, go ahead and instantiate the options
  end

  def must_be(klass, opt, *keys)
    keys.each do |k|
      next if !opt.has_key?(k) || opt[k].is_a?(klass)

      raise Sia::Error::ConfigurationError,
        "#{k.inspect} should be a #{klass} but was a #{opt[k].class}"
    end
  end

end
