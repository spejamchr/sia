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
  # `:in_place` - If true, closed files will be encrypted where they are with
  #     a Sia file extension attached to the name. If false, closed files will
  #     be moved to the safe dir and renamed to a url-safe hash.
  #
  # `:extension` - In-place safes will attach this extension to closed files.
  #     Ignored unless `:in_place` is truthy. Can include the period or not (so
  #     `'.thing'` and `'thing'` will both work the same).
  #
  # `:portable` - If true, all clear files must be children of the safe dir.
  #     Useful if the safe will be shared.
  #
  DEFAULTS = {
    root_dir: Pathname("~").expand_path / '.sia_safes',
    index_name: '.sia_index',
    salt_name: '.sia_salt',
    digest_iterations: 200_000,
    buffer_bytes: 512,
    in_place: false,
    extension: '.sia_closed',
    portable: false,
  }.freeze

  # The configuration options
  #
  # @return [Hash]
  #
  def options
    (@options ||= defaults).transform_values(&:dup).dup
  end

  private

  def clean_options(opt)
    opt = opt.dup
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

    validation_for(opt) do
      not_empty :root_dir, :index_name, :salt_name, :extension

      convert(:root_dir) { |v| Pathname(v).expand_path }
      convert(:index_name, :salt_name) { |v| v.to_s}
      convert(:digest_iterations, :buffer_bytes) { |v| v.to_i }
      convert(:in_place, :portable) { |v| !!v }
      convert(:extension) { |v| ".#{v.to_s.reverse.chomp('.').reverse}" }
    end

    opt
  end

  def validation_for(opt, &block)
    Validator.new(opt).instance_eval(&block).done
  end

  # Validate the options
  # @private
  class Validator
    def initialize(opt)
      @opt = opt
      @converted = []
    end

    def not_empty(*keys)
      (keys & @opt.keys).each do |k|
        next unless @opt[k].empty?
        raise Sia::Error::ConfigurationError, "#{k.inspect} must not be empty"
      end
      self
    end

    def convert(*keys, &block)
      @converted += keys
      (keys & @opt.keys).each do |k|
        @opt[k] = yield @opt[k]
      rescue NoMethodError => nme
        raise Sia::Error::ConfigurationError,
          "#{k.inspect} was #{nme.args} and could not be converted using " +
          "`#{nme.name.inspect}`"
      end
      self
    end

    # Make sure Sia converts each option exactly one time. Any time a new
    # option is added, it needs to be converted.
    def done
      return if DEFAULTS.keys.sort == @converted.sort

      bads = DEFAULTS.transform_values { 0 }.merge(
        @converted.group_by(&:itself).transform_values(&:count)
      ).select { |k, v| v != 1 }

      raise "Options were not converted exactly once! #{bads}"
    end
  end # class Validator
end # module Sia::Configurable
