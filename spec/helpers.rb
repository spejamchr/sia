module Helpers
  def new_safe(name: 'test', password: 'abc', **opt)
    args = opt.merge(name: name, password: password)
    Sia::Safe.new(args)
  end

  def test_dir
    Pathname('~').expand_path / '.test_sia_safes'
  end

  def def_conf
    Sia::Configurable::DEFAULTS
  end

  def encrypted_file_count
    Dir[File.join(test_dir, '**', '*')].count { |f|
      File.file?(f) && f != new_safe.index_path && f != new_safe.salt_path
    }
  end

  def new_lock(password: 'abc', salt: 'salt', buff_bytes: 1000, digest_iter: 1)
    Sia::Lock.new(password, salt, buff_bytes, digest_iter)
  end
end
