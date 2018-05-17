module Helpers
  def new_safe(name: 'test', password: 'abc', **opt)
    args = opt.merge(name: name, password: password)
    Sia::Safe.new(args)
  end

  def test_dir
    Pathname(Dir.home) / '.test_sia_safes'
  end

  def def_conf
    Sia::Configurable::DEFAULTS
  end

  def encrypted_file_count
    Dir[File.join(test_dir, '**', '*')].map{ |s| Pathname(s) }.count { |f|
      f.file? && ![
        new_safe.index_path,
        new_safe.salt_path,
        Sia::PersistedConfig::PATH,
      ].include?(f)
    }
  end

  def new_lock(password: 'abc', salt: 'salt', buff_bytes: 1000, digest_iter: 1)
    Sia::Lock.new(password, salt, buff_bytes, digest_iter)
  end
end
