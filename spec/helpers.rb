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

  def encrypted_file_count
    Dir[File.join(test_dir, '**', '*')].count { |f|
      File.file?(f) && f != new_safe.index_path && f != new_safe.secret_path
    }
  end
end
