module Helpers
  def new_safe(name: 'test', password: 'abc', **opt, &block)
    args = opt.merge(name: name, password: password)
    block_given? ? Sia::Safe.new(args, &block) : Sia::Safe.new(args)
  end

  def test_dir
    File.join(Dir.home, '.test_sia_safes')
  end

  def def_conf
    Sia::Configurable::DEFAULTS
  end
end
