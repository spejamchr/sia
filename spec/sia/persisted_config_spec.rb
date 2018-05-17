RSpec.describe Sia::PersistedConfig do
  before :all do
    if Sia::PersistedConfig::PATH.exist?
      @original_config = Sia::PersistedConfig::PATH.read
    end
  end

  before :each do
    @sia = Sia::PersistedConfig.new
    @safe = Sia::PersistedConfig.new(:test)
  end

  after :each do
    Sia::PersistedConfig::PATH.delete if Sia::PersistedConfig::PATH.exist?
  end

  after :all do
    if @original_config
      Sia::PersistedConfig::PATH.write(@original_config)
    elsif Sia::PersistedConfig::PATH.exist?
      Sia::PersistedConfig::PATH.delete
    end
  end

  it 'can be initialized without args' do
    Sia::PersistedConfig.new
  end

  it 'can be initialized with a safe name' do
    Sia::PersistedConfig.new(:test)
  end

  describe '#persist' do
    it 'creates the persisted file' do
      @sia.persist({})
      expect(Sia::PersistedConfig::PATH).to exist
    end

    it 'writes valid Yaml' do
      @sia.persist({})
      YAML.load(Sia::PersistedConfig::PATH.read)
    end

    it 'records the sia entry for sia' do
      @sia.persist({})
      expect(YAML.load(Sia::PersistedConfig::PATH.read)).to have_key(:sia)
    end

    it 'does not overwrite missing options' do
      @sia.persist({a: 1})
      @sia.persist({b: 2})
      expect(@sia.options[:a]).to eq(1)
    end
  end # describe '#persist'

  describe '#options' do
    it 'works without a persisted file' do
      @sia.options
      expect(Sia::PersistedConfig::PATH).to_not exist
    end

    it 'works with a persisted file for sia' do
      @sia.persist(a: 1)
      expect(@sia.options[:a]).to eq(1)
    end

    it 'works with a persisted file for a safe' do
      @safe.persist(a: 1)
      expect(@safe.options[:a]).to eq(1)
    end

    it 'does not give sia or safe access to the other' do
      @sia.persist({a: :sia})
      @safe.persist({a: :safe})
      expect(@sia.options[:a]).to eq(:sia)
      expect(@safe.options[:a]).to eq(:safe)
    end
  end # describe '#options'

  describe '#delete' do
    it 'works without a persisted_file' do
      @sia.delete
      @safe.delete
    end

    it 'removes the sia entry for sia' do
      @sia.persist({a: 1})
      @sia.delete
      expect(YAML.load(Sia::PersistedConfig::PATH.read)).to_not have_key(:sia)
    end
  end
end # Rspec.describe Sia::PersistedConfig
