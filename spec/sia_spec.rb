RSpec.describe Sia do
  it "has a version number" do
    expect(Sia::VERSION).not_to be nil
  end

  describe Sia::Configurable do
    after :each do
      Sia.set_default_options!
    end

    it 'has defaults set without any configuration' do
      expect(Sia.options[:root_dir]).to eq(def_conf[:root_dir])
      expect(Sia.options[:index_name]).to eq(def_conf[:index_name])
      expect(Sia.options[:salt_name]).to eq(def_conf[:salt_name])
      expect(Sia.options[:digest_iterations]).to eq(def_conf[:digest_iterations])
      expect(Sia.options[:buffer_bytes]).to eq(def_conf[:buffer_bytes])
      expect(Sia.options[:in_place]).to eq(def_conf[:in_place])
    end

    it 'has valid defaults' do
      Sia.send(:clean_options, Sia::Configurable::DEFAULTS)
    end

    it 'cannot be changed by manipulating the options object directly' do
      before = Sia.options.dup
      Sia.options.merge!(a: 1, b: 2)
      expect(Sia.options).to eq(before)
    end

    it 'cannot be changed by manipulating options values' do
      before = Sia.options[:salt_name].dup
      Sia.options[:salt_name] << 'hacky something'
      expect(Sia.options[:salt_name]).to eq(before)
    end

    describe '#config' do
      it 'works with all config options' do
        all_options = {
          root_dir: 'a',
          index_name: 'b',
          salt_name: 'c',
          digest_iterations: 1,
          buffer_bytes: 1,
          in_place: true,
          extension: :sia,
          portable: true,
        }
        expect(all_options.keys.sort).to eq(def_conf.keys.sort)
        Sia.config(**all_options)
      end

      it 'respects customizations' do
        Sia.config(root_dir: '/a/b', index_name: 'c', buffer_bytes: 2)
        expect(Sia.options[:root_dir]).to eq(Pathname('/a/b'))
        expect(Sia.options[:index_name]).to eq('c')
        expect(Sia.options[:buffer_bytes]).to eq(2)
      end

      it 'respects partial customizations' do
        Sia.config(root_dir: '/c')
        expect(Sia.options[:root_dir]).to eq(Pathname('/c'))
        expect(Sia.options[:index_name]).to eq(def_conf[:index_name])
        expect(Sia.options[:buffer_bytes]).to eq(def_conf[:buffer_bytes])
      end

      it 'duck types settings' do
        Sia.config(buffer_bytes: '1')
        expect(Sia.options[:buffer_bytes]).to eq(1)
      end

      it 'raises error if index_name and secret_name are equal' do
        expect { Sia.config(index_name: 'a', secret_name: 'a') }.to(
          raise_error(Sia::Error::ConfigurationError)
        )
      end

      it 'raises error when setting invalid option' do
        expect {
          Sia.config(some_key_not_in_def_conf: 'hi')
        }.to(raise_error(Sia::Error::InvalidOptionError))
      end

      it 'raises error when setting option to invalid type' do
        expect { Sia.config(buffer_bytes: []) }.to(
          raise_error(Sia::Error::ConfigurationError)
        )
      end

      it 'raises error for blank root_dir option' do
        expect { Sia.config(root_dir: '') }.to(
          raise_error(Sia::Error::ConfigurationError)
        )
      end

      it 'raises error for blank index_name option' do
        expect { Sia.config(index_name: '') }.to(
          raise_error(Sia::Error::ConfigurationError)
        )
      end

      it 'raises error for url-unsafe options' do
        expect { Sia.config(root_dir: '&^%$#!') }.to(
          raise_error(Sia::Error::ConfigurationError)
        )
      end
    end # describe '#config'

    describe '#set_default_options!' do
      it 'resets options to default' do
        Sia.config(root_dir: '/a/b', index_name: 'c', buffer_bytes: 2)
        Sia.set_default_options!
        expect(Sia.options[:root_dir]).to eq(def_conf[:root_dir])
        expect(Sia.options[:index_name]).to eq(def_conf[:index_name])
        expect(Sia.options[:buffer_bytes]).to eq(def_conf[:buffer_bytes])
      end

      it 'partially resets options to default with args' do
        Sia.config(root_dir: '/a/b', index_name: 'c', buffer_bytes: 2)
        Sia.set_default_options!(:root_dir)
        expect(Sia.options[:root_dir]).to eq(def_conf[:root_dir])
        expect(Sia.options[:index_name]).to eq('c')
        expect(Sia.options[:buffer_bytes]).to eq(2)
      end
    end
  end # describe Sia::Configurable

  describe Sia::Lock do
    describe '#new' do
      it 'does not throw an error' do
        new_lock
      end
    end

    describe '#encrypt_to_file' do
      before :each do
        @secure_file = Pathname('/tmp/safe.spec.secure_file.txt')
        @string = 'some clear string'
      end

      after :each do
        @secure_file.delete if @secure_file.exist?
      end

      it 'creates the secure_file' do
        expect(@secure_file).to_not exist
        new_lock.encrypt_to_file(@string, @secure_file)
        expect(@secure_file).to exist
      end

      it 'encrypts the secure_file' do
        new_lock.encrypt_to_file(@string, @secure_file)
        expect(@secure_file.read).to_not eq(@string)
      end
    end # describe '#encrypt_to_file'

    describe '#decrypt_from_file' do
      before :each do
        @secure_file = Pathname('/tmp/safe.spec.secure_file.txt')
        @string = 'some clear string'
        new_lock.encrypt_to_file(@string, @secure_file)
      end

      after :each do
        @secure_file.delete if @secure_file.exist?
      end

      it 'does not delete the secure_file' do
        new_lock.decrypt_from_file(@secure_file)
        expect(@secure_file).to exist
      end

      it 'restores the clear message' do
        msg = new_lock.decrypt_from_file(@secure_file)
        expect(msg).to eq(@string)
      end
    end # describe '#decrypt_from_file'

    describe '#encrypt' do
      before :each do
        @secure_file = Pathname('/tmp/safe.spec.secure_file.txt')
        @clear_file = Pathname('/tmp/safe.spec.clear_file.txt')
        @string = 'some clear string'
        @clear_file.write(@string)
      end

      after :each do
        @secure_file.delete if @secure_file.exist?
        @clear_file.delete if @clear_file.exist?
      end

      it 'creates the secure_file' do
        expect(@secure_file).to_not exist
        new_lock.encrypt(@clear_file, @secure_file)
        expect(@secure_file).to exist
      end

      it 'destroys the clear file' do
        expect(@clear_file).to exist
        new_lock.encrypt(@clear_file, @secure_file)
        expect(@clear_file).to_not exist
      end

      it 'encrypts the secure_file' do
        new_lock.encrypt(@clear_file, @secure_file)
        expect(@secure_file.read).to_not eq(@string)
      end
    end # describe '#encrypt'

    describe '#decrypt' do
      before :each do
        @secure_file = Pathname('/tmp/safe.spec.secure_file.txt')
        @clear_file = Pathname('/tmp/safe.spec.clear_file.txt')
        @string = 'some clear string'
        @clear_file.write(@string)
        new_lock.encrypt(@clear_file, @secure_file)
      end

      after :each do
        @secure_file.delete if @secure_file.exist?
        @clear_file.delete if @clear_file.exist?
      end

      it 'destroys the secure_file' do
        expect(@secure_file).to exist
        new_lock.decrypt(@clear_file, @secure_file)
        expect(@secure_file).to_not exist
      end

      it 'creates the clear file' do
        expect(@clear_file).to_not exist
        new_lock.decrypt(@clear_file, @secure_file)
        expect(@clear_file).to exist
      end

      it 'decrypts the secure_file' do
        new_lock.decrypt(@clear_file, @secure_file)
        expect(@clear_file.read).to eq(@string)
      end
    end # describe '#decrypt'
  end # describe Sia::Lock

  describe Sia::Safe do
    before :each do
      Sia.config(root_dir: test_dir, digest_iterations: 1)
    end

    after :each do
      test_dir.rmtree if test_dir.exist?
    end

    describe 'configuring a safe' do
      it 'overrides Sia config' do
        Sia.config(buffer_bytes: 1)
        safe = new_safe(buffer_bytes: 10)
        expect(safe.options[:buffer_bytes]).to be(10)
      end

      it 'does not overwrite Sia config' do
        Sia.config(buffer_bytes: 1)
        new_safe(buffer_bytes: 10)
        expect(Sia.options[:buffer_bytes]).to be(1)
      end

      it 'cannot be done by manipulating options' do
        safe = new_safe
        before = safe.options.dup
        safe.options.merge!(a: 1, b: 2)
        expect(safe.options).to eq(before)
      end
    end # describe 'configuring a safe'

    describe 'instance methods' do
      before :each do
        @clear_file = Pathname('/tmp/safe.spec.clear_file.txt')
        @clear_file_contents = "Some string\nwith linebreaks\nand stuff\n"
        @clear_file.write(@clear_file_contents)
      end

      after :each do
        @clear_file.delete if @clear_file.exist?
      end

      describe '#new' do
        it 'does not create the safe dir' do
          expect(test_dir).to_not exist
          new_safe
          expect(test_dir).to_not exist
        end

        it 'does not create the index file' do
          expect(new_safe.index_path).to_not exist
          new_safe
          expect(new_safe.index_path).to_not exist
        end

        it 'assigns a salt' do
          expect(new_safe.salt).to be_a(String)
        end

        it 'assigns different salts per new instance' do
          expect(new_safe.salt).not_to eq(new_safe.salt)
        end

        it 'raises exception with the wrong password if safe already exists' do
          new_safe.close(@clear_file) # persist the good safe by using it

          expect { new_safe(password: 'bad password') }
            .to raise_error(Sia::Error::PasswordError)
        end

        it 'uses Sia config' do
          Sia.config(buffer_bytes: 1)
          expect(new_safe.options[:buffer_bytes]).to be(1)
        end

        describe 'argument validation' do
          it 'accepts symbols for name and password' do
            Sia::Safe.new(name: :name, password: :password)
          end
        end

        describe 'setting options' do
          it 'overrides Sia config' do
            Sia.config(buffer_bytes: 1)
            safe = new_safe(buffer_bytes: 10)
            expect(safe.options[:buffer_bytes]).to be(10)
          end

          it 'does not overwrite Sia config' do
            Sia.config(buffer_bytes: 1)
            new_safe(buffer_bytes: 10)
            expect(Sia.options[:buffer_bytes]).to be(1)
          end
        end # describe 'setting options'
      end # describe '#new'

      describe '#close' do
        it 'works with string path' do
          new_safe.close(@clear_file.to_s)
        end

        it 'works with Pathname' do
          new_safe.close(@clear_file)
        end

        it 'removes the clear file' do
          expect(@clear_file).to exist
          new_safe.close(@clear_file)
          expect(@clear_file).not_to exist
        end

        it 'creates the index file' do
          expect(new_safe.index_path).to_not exist
          new_safe.close(@clear_file)
          expect(new_safe.index_path).to exist
        end

        it 'encrypts the index file' do
          new_safe.close(@clear_file)
          expect { YAML.load(new_safe.index_path.read) }
            .to(raise_error(Psych::SyntaxError))
        end

        it 'creates the safe directory' do
          expect(new_safe.safe_dir).to_not exist
          new_safe.close(@clear_file)
          expect(new_safe.safe_dir).to exist
        end

        it 'creates a new encrypted file' do
          before = encrypted_file_count
          new_safe.close(@clear_file)
          after = encrypted_file_count
          expect(after).to be(before + 1)
        end

        it 'creates the index entry for the clear file' do
          expect(new_safe.index).to_not have_key(:files)

          new_safe.close(@clear_file)

          i = new_safe.index
          expect(i).to have_key(:files)

          f = i[:files]
          expect(f).to have_key(@clear_file)

          c = f[@clear_file]
          expect(c).to have_key(:secure_file)
          expect(c).to have_key(:last_closed)
          expect(c).to have_key(:safe)
        end

        it 'creates the salt file for the safe' do
          expect(new_safe.salt_path).not_to exist
          new_safe.close(@clear_file)
          expect(new_safe.salt_path).to exist
        end

        it 'handles files with funky names' do
          funky_file = Pathname('/tmp/s@fe.$p3c."funky" c|ear file.txt')
          funky_file_contents = "Some string\nwith linebreaks\nand stuff\n"
          funky_file.write(funky_file_contents)
          new_safe.close(funky_file)
        end
      end # describe '#close'

      describe '#open' do
        before :each do
          new_safe.close(@clear_file)
        end

        it 'works with string path' do
          new_safe.open(@clear_file.to_s)
        end

        it 'works with Pathname' do
          new_safe.open(@clear_file)
        end

        it 'creates the clear file' do
          expect(@clear_file).not_to exist
          new_safe.open(@clear_file)
          expect(@clear_file).to exist
        end

        it 'removes the encrypted file' do
          before = encrypted_file_count
          new_safe.open(@clear_file)
          after = encrypted_file_count
          expect(after).to be(before - 1)
        end

        it 'decrypts the file' do
          new_safe.open(@clear_file)
          expect(@clear_file.read).to eq(@clear_file_contents)
        end

        it 'handles files with funky names' do
          funky_file = Pathname('/tmp/s@fe.$p3c."funky" c|ear file.txt')
          funky_file_contents = "Some string\nwith linebreaks\nand stuff\n"
          funky_file.write(funky_file_contents)
          new_safe.close(funky_file)
          new_safe.open(funky_file)
        end
      end # describe '#open'

      describe '#empty' do
        before :each do
          @other_file = Pathname('/tmp/safe.spec.other_file.txt')
          @other_file_contents = "Some other string\nwith stuff\n"
          @other_file.write(@other_file_contents)

          new_safe.close(@clear_file)
          new_safe.close(@other_file)
        end

        it 'restores all the clearfiles' do
          new_safe.empty
          expect(@clear_file).to exist
          expect(@other_file).to exist

          expect(@clear_file.read).to eq(@clear_file_contents)
          expect(@other_file.read).to eq(@other_file_contents)
        end

        it 'works if some files are already open' do
          new_safe.open(@clear_file)
          new_safe.empty
        end

        it 'removes all the secure files from the safe' do
          new_safe.empty
          new_safe.send(:files).each do |_, data|
            expect(data[:secure_file]).not_to exist
          end
        end
      end # describe '#empty'

      describe '#fill' do
        before :each do
          @other_file = Pathname('/tmp/safe.spec.other_file.txt')
          @other_file_contents = "Some other string\nwith stuff\n"
          @other_file.write(@other_file_contents)

          new_safe.close(@clear_file)
          new_safe.close(@other_file)
          new_safe.empty
        end

        it 'removes all the clearfiles' do
          new_safe.fill
          expect(@clear_file).not_to exist
          expect(@other_file).not_to exist
        end

        it 'works if some files are already closed' do
          new_safe.close(@clear_file)
          new_safe.fill
        end

        it 'restores all the secure files to the safe' do
          new_safe.fill
          new_safe.send(:files).each do |filename, _|
            expect(new_safe.send(:secure_filepath, filename)).to exist
          end
        end
      end # describe '#empty'

      describe '#index' do
        it 'returns a hash' do
          expect(new_safe.index).to be_a(Hash)
        end
      end # describe '#index'

      describe '#delete' do
        it 'removes the safe_dir for this safe' do
          new_safe.close(@clear_file)
          new_safe.delete
          expect(new_safe.safe_dir).to_not exist
        end

        it 'does not remove safe_dir if there are other files in it' do
          new_safe.close(@clear_file)
          (new_safe.safe_dir / 'personal_file.txt').write('I am here')
          new_safe.delete
          expect(new_safe.safe_dir).to exist
        end

        it 'does not affect open files' do
          new_safe.close(@clear_file)
          new_safe.open(@clear_file)
          new_safe.delete
          expect(@clear_file).to exist
        end

        it 'removes closed files' do
          new_safe.close(@clear_file)
          before = encrypted_file_count
          expect(before).to eq(1)

          new_safe.delete

          after = encrypted_file_count
          expect(after).to eq(0)
        end
      end # describe '#delete'
    end # describe 'instance methods'

    describe 'an in-place safe' do
      before :each do
        Sia.config(in_place: true)
        (test_dir / 'test').mkpath

        @in_clear_file = test_dir / 'test' / 'in_clear_file.txt'
        @out_clear_file = Pathname('/tmp/safe.spec.out_clear_file.txt')
        @clear_text = 'this is the clear text'
        [@in_clear_file, @out_clear_file].each do |f|
          f.write(@clear_text)
        end

        @closed = Pathname(@in_clear_file.to_s + '.sia_closed')
      end

      after :all do
        Sia.set_default_options!(:in_place)
      end

      describe '#close' do
        it 'works for clear files in root_dir' do
          new_safe.close(@in_clear_file)
        end

        it 'works for clear files outside root_dir' do
          new_safe.close(@out_clear_file)
        end

        it 'adds the .sia_closed extension to the filename' do
          expect(@closed).to_not exist
          new_safe.close(@in_clear_file)
          expect(@in_clear_file).to_not exist
          expect(@closed).to exist
        end

        it 'does not add encrypted files to safe_dir' do
          before = encrypted_file_count
          new_safe.close(@out_clear_file)
          after = encrypted_file_count
          expect(before).to eq(after)
        end

        it 'respects the extension option' do
          ext = '.some_new_extension'
          s = new_safe(extension: ext)
          s.close(@in_clear_file)
          expect(Pathname(@in_clear_file.to_s + ext)).to exist
        end
      end # describe '#close'

      describe '#open' do
        before :each do
          new_safe.close(@in_clear_file)
        end

        after :each do
          new_safe.delete
        end

        it 'removes the .sia_closed extension from the filename' do
          expect(@closed).to exist
          new_safe.open(@in_clear_file)
          expect(@in_clear_file).to exist
          expect(@closed).to_not exist
          expect(@in_clear_file.read).to eq(@clear_text)
        end

        it 'works when passed the file with the .sia_closed extension' do
          new_safe.open(@closed)
          expect(@in_clear_file.read).to eq(@clear_text)
        end

        it 'respects the extension option' do
          new_safe.open(@in_clear_file)

          ext = '.some_new_extension'
          s = new_safe(extension: ext)

          s.close(@in_clear_file)
          s.open(@in_clear_file)
          s.close(@in_clear_file)
          s.open(Pathname(@in_clear_file.to_s + ext))
          expect(@in_clear_file.read).to eq(@clear_text)
        end
      end # describe '#open'
    end # describe 'an in-place safe'

    describe 'a portable safe' do
      before :each do
        Sia.config(portable: true)
        (test_dir / 'test').mkpath

        @in_clear_file = test_dir / 'test' / 'in_clear_file.txt'
        @out_clear_file = Pathname('/tmp/safe.spec.out_clear_file.txt')
        @clear_text = 'this is the clear text'
        [@in_clear_file, @out_clear_file].each do |f|
          f.write(@clear_text)
        end
      end

      after :each do
        Sia.set_default_options!(:portable)
        [@in_clear_file, @out_clear_file].each do |f|
          f.delete if f.exist?
        end
      end

      describe '#close' do
        it 'works for clear files in root_dir' do
          new_safe.close(@in_clear_file)
        end

        it 'does not work for clear files outside root_dir' do
          expect { new_safe.close(@out_clear_file) }
            .to(raise_error(Sia::Error::FileOutsideScopeError))
        end
      end # describe '#close'

      describe '#open' do
        before :each do
          new_safe.close(@in_clear_file)
        end

        it 'works for files in root_dir' do
          new_safe.open(@in_clear_file)
          expect(@in_clear_file.read).to eq(@clear_text)
        end

        it 'does not work for files outside root dir' do
          new_safe(portable: false).close(@out_clear_file)
          expect { new_safe.open(@out_clear_file) }
            .to(raise_error(Sia::Error::FileOutsideScopeError))
        end

      end # describe '#open'
    end # describe 'a portable safe'

    describe 'a Sia::Safe integration test' do
      it 'does not break' do
        clear_file1 = Pathname('/tmp/safe.spec.clear_file1.txt')
        clear_file2 = Pathname('/tmp/safe.spec.clear_file2.txt')
        clear_file1_contents = "Some string\nwith linebreaks\nand stuff\n"
        clear_file2_contents = "Some other string\nwith linebreaks\nand stuff\n"
        clear_file1.write(clear_file1_contents)
        clear_file2.write(clear_file2_contents)

        # Should not raise an error because the good safe has not been persisted
        new_safe(password: 'bad password')

        10.times do
          new_safe.close(clear_file1)
          new_safe.close(clear_file2)
          new_safe.open(clear_file1)
          new_safe.open(clear_file2)
          new_safe.delete
        end

        expect(clear_file1.read).to eq(clear_file1_contents)
        expect(clear_file2.read).to eq(clear_file2_contents)

        new_safe.close(clear_file1)
        new_safe.close(clear_file2)
        new_safe.open(clear_file1)
        new_safe.open(clear_file2)

        expect { new_safe(password: 'bad password') }
          .to raise_error(Sia::Error::PasswordError)

        new_safe.fill
        new_safe.empty
        new_safe.fill
        new_safe.empty
      end
    end # describe 'an integration test'
  end # describe Sia::Safe

end # RSpec.describe Sia
