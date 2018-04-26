RSpec.describe Sia do
  it "has a version number" do
    expect(Sia::VERSION).not_to be nil
  end

  it 'has an index' do
    expect(Sia::index).to be_a(Hash)
  end

  describe Sia::Configurable do
    after :each do
      Sia.set_default_options!
    end

    DEFAULTS = Sia::Configurable::DEFAULTS

    it 'has defaults set without any configuration' do
      expect(Sia.safe_dir).to eq(DEFAULTS[:safe_dir])
      expect(Sia.index_name).to eq(DEFAULTS[:index_name])
      expect(Sia.buffer_bytes).to eq(DEFAULTS[:buffer_bytes])
      expect(Sia.index_path).to eq(File.join(
        DEFAULTS[:safe_dir], DEFAULTS[:index_name]
      ))
    end

    describe '#config' do
      it 'respects customizations' do
        Sia.config do |config|
          config.safe_dir = '/a'
          config.index_name = 'b'
          config.buffer_bytes = 1
        end
        expect(Sia.safe_dir).to eq('/a')
        expect(Sia.index_name).to eq('b')
        expect(Sia.index_path).to eq('/a/b')
        expect(Sia.buffer_bytes).to eq(1)
      end

      it 'respects partial customizations' do
        Sia.config do |config|
          config.safe_dir = '/a'
          config.buffer_bytes = 1
        end
        expect(Sia.safe_dir).to eq('/a')
        expect(Sia.index_name).to eq(DEFAULTS[:index_name])
        expect(Sia.index_path)
          .to eq('/a/' + DEFAULTS[:index_name])
        expect(Sia.buffer_bytes).to eq(1)
      end
    end # describe '#config'

    describe '#options=' do
      it 'respects customizations' do
        Sia.options = {
          safe_dir: '/a/b',
          index_name: 'c',
          buffer_bytes: 2,
        }
        expect(Sia.safe_dir).to eq('/a/b')
        expect(Sia.index_name).to eq('c')
        expect(Sia.index_path).to eq('/a/b/c')
        expect(Sia.buffer_bytes).to eq(2)
      end

      it 'respects partial customizations' do
        Sia.options = { safe_dir: '/c' }
        expect(Sia.safe_dir).to eq('/c')
        expect(Sia.index_name).to eq(DEFAULTS[:index_name])
        expect(Sia.index_path)
          .to eq('/c/' + DEFAULTS[:index_name])
        expect(Sia.buffer_bytes).to eq(DEFAULTS[:buffer_bytes])
      end
    end # describe '#options='
  end # describe Sia::Configurable

  describe Sia::Safe do
    TEST_DIR = File.join(Dir.home, '.test_sia_safes').freeze

    before :all do
      Sia.config do |c|
        c.safe_dir = TEST_DIR
      end
    end

    after :each do
      FileUtils.rm_rf(TEST_DIR)
    end

    def encrypted_file_count
      Dir[File.join(TEST_DIR, '**', '*')].count { |f|
        File.file?(f) && f != new_safe.index_path
      }
    end

    describe 'configuring a safe' do
      describe 'via hash' do
        it 'overrides Sia config' do
          Sia.options = { buffer_bytes: 1 }
          safe = new_safe
          safe.options = { buffer_bytes: 10 }
          expect(safe.buffer_bytes).to be(10)
        end

        it 'does not overwrite Sia config' do
          Sia.options = { buffer_bytes: 1 }
          new_safe.options = { buffer_bytes: 10 }
          expect(Sia.buffer_bytes).to be(1)
        end
      end # describe 'via hash'

      describe 'via block' do
        it 'overrides Sia config' do
          Sia.options = { buffer_bytes: 1 }
          safe = new_safe
          safe.config { |s| s.buffer_bytes = 10 }
          expect(safe.buffer_bytes).to be(10)
        end

        it 'does not overwrite Sia config' do
          Sia.options = { buffer_bytes: 1 }
          new_safe.config { |s| s.buffer_bytes = 10 }
          expect(Sia.buffer_bytes).to be(1)
        end
      end # describe 'via block'
    end # describe 'configuring a safe'

    describe 'instance methods' do
      before :each do
        @clear_file = '/tmp/safe.spec.clear_file.txt'
        @clear_file_contents = "Some string\nwith linebreaks\nand stuff\n"
        File.write(@clear_file, @clear_file_contents)
      end

      after :each do
        File.delete(@clear_file) if File.exists?(@clear_file)
      end

      describe '#new' do
        it 'does not create the safe dir' do
          FileUtils.rm_rf(TEST_DIR)
          new_safe
          expect(File).to_not exist(File.expand_path(TEST_DIR))
        end

        it 'does not create the index file' do
          safe = new_safe
          expect(safe.send(:entry)).to eq({})
        end

        it 'assigns a salt' do
          expect(new_safe.send(:salt)).to be_a(String)
        end

        it 'assigns different salts per new instance' do
          expect(new_safe.send(:salt))
            .not_to(eq(new_safe.send(:salt)))
        end

        it 'raises exception with the wrong password if safe already exists' do
          new_safe.close(@clear_file) # persist the good safe by using it

          expect { new_safe(password: 'bad password') }
            .to raise_error(Sia::PasswordError)
        end

        it 'uses Sia config' do
          Sia.options = { buffer_bytes: 1 }
          expect(new_safe.buffer_bytes).to be(1)
        end

        describe 'argument validation' do
          it 'raises a name and password error with no args' do
            expect { Sia::Safe.new }.to(
              raise_error(/name.*password|password.*name/)
            )
          end

          it 'raises a name (not password) error when missing name' do
            expect { Sia::Safe.new(password: 'hi') }.to(
              raise_error(/^(?>(?:.*?password)?)^.*name.*$/)
            )
          end

          it 'raises a password (not name) error when missing password' do
            expect { Sia::Safe.new(name: 'hi') }.to(
              raise_error(/^(?>(?:.*?name)?)^.*password.*$/)
            )
          end
        end

        describe 'setting options via hash' do
          it 'overrides Sia config' do
            Sia.options = { buffer_bytes: 1 }
            safe = new_safe(buffer_bytes: 10)
            expect(safe.buffer_bytes).to be(10)
          end

          it 'does not overwrite Sia config' do
            Sia.options = { buffer_bytes: 1 }
            new_safe(buffer_bytes: 10)
            expect(Sia.buffer_bytes).to be(1)
          end
        end # describe 'setting options via hash'

        describe 'setting options via block' do
          it 'overrides Sia config' do
            Sia.options = { buffer_bytes: 1 }
            safe = new_safe do |s|
              s.buffer_bytes = 10
            end
            expect(safe.buffer_bytes).to be(10)
          end

          it 'does not overwrite Sia config' do
            Sia.options = { buffer_bytes: 1 }
            new_safe do |s|
              s.buffer_bytes = 10
            end
            expect(Sia.buffer_bytes).to be(1)
          end
        end # describe 'setting options via hash'
      end # describe '#new'

      describe '#close' do
        it 'removes the clear file' do
          expect(File).to exist(@clear_file)
          new_safe.close(@clear_file)
          expect(File).not_to exist(@clear_file)
        end

        it 'creates the index file' do
          expect(File).to_not exist(new_safe.index_path)
          new_safe.close(@clear_file)
          expect(File).to exist(new_safe.index_path)
        end

        it 'creates a new encrypted file' do
          before = encrypted_file_count
          new_safe.close(@clear_file)
          after = encrypted_file_count
          expect(after).to be(before + 1)
        end
      end # describe '#close'

      describe '#open' do
        before :each do
          new_safe.close(@clear_file)
        end

        it 'creates the clear file' do
          expect(File).not_to exist(@clear_file)
          new_safe.open(@clear_file)
          expect(File).to exist(@clear_file)
        end

        it 'removes the encrypted file' do
          before = encrypted_file_count
          new_safe.open(@clear_file)
          after = encrypted_file_count
          expect(after).to be(before - 1)
        end

        it 'decrypts the file' do
          new_safe.open(@clear_file)
          expect(File.read(@clear_file)).to eq(@clear_file_contents)
        end
      end # describe '#open'

      describe '#empty' do
        before :each do
          @other_file = '/tmp/safe.spec.other_file.txt'
          @other_file_contents = "Some other string\nwith stuff\n"
          File.write(@other_file, @other_file_contents)

          new_safe.close(@clear_file)
          new_safe.close(@other_file)
        end

        it 'restores all the clearfiles' do
          new_safe.empty
          expect(File).to exist(@clear_file)
          expect(File).to exist(@other_file)

          expect(File.read(@clear_file)).to eq(@clear_file_contents)
          expect(File.read(@other_file)).to eq(@other_file_contents)
        end

        it 'works if some files are already open' do
          new_safe.open(@clear_file)
          new_safe.empty
        end

        it 'removes all the secure files from the safe' do
          new_safe.empty
          new_safe.send(:files).each do |_, data|
            expect(File).not_to exist(data[:secure_file])
          end
        end
      end # describe '#empty'

      describe '#fill' do
        before :each do
          @other_file = '/tmp/safe.spec.other_file.txt'
          @other_file_contents = "Some other string\nwith stuff\n"
          File.write(@other_file, @other_file_contents)

          new_safe.close(@clear_file)
          new_safe.close(@other_file)
          new_safe.empty
        end

        it 'removes all the clearfiles' do
          new_safe.fill
          expect(File).not_to exist(@clear_file)
          expect(File).not_to exist(@other_file)
        end

        it 'works if some files are already closed' do
          new_safe.close(@clear_file)
          new_safe.fill
        end

        it 'restores all the secure files to the safe' do
          new_safe.fill
          new_safe.send(:files).each do |_, data|
            expect(File).to exist(data[:secure_file])
          end
        end
      end # describe '#empty'

      describe '#index' do
        it 'returns a hash' do
          expect(new_safe.index).to be_a(Hash)
        end
      end # describe '#index'

      describe '#delete' do
        it 'removes the index entry for this safe' do
          new_safe.close(@clear_file)
          skip('index does not have :test key') unless Sia.index.has_key?(:test)
          new_safe.delete
          expect(Sia.index).to_not have_key(:test)
        end

        it 'does not affect open files' do
          new_safe.close(@clear_file)
          new_safe.open(@clear_file)
          new_safe.delete
          expect(File).to exist(@clear_file)
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

    describe 'a Sia::Safe integration test' do
      it 'does not break' do
        clear_file1 = '/tmp/safe.spec.clear_file1.txt'
        clear_file2 = '/tmp/safe.spec.clear_file2.txt'
        clear_file1_contents = "Some string\nwith linebreaks\nand stuff\n"
        clear_file2_contents = "Some other string\nwith linebreaks\nand stuff\n"
        File.write(clear_file1, clear_file1_contents)
        File.write(clear_file2, clear_file2_contents)

        # Should not raise an error because the good safe has not been persisted
        new_safe(password: 'bad password')

        new_safe.close(clear_file1)
        new_safe.close(clear_file2)
        new_safe.open(clear_file1)
        new_safe.open(clear_file2)
        new_safe.close(clear_file1)
        new_safe.close(clear_file2)
        new_safe.open(clear_file1)
        new_safe.open(clear_file2)

        expect(File.read(clear_file1)).to eq(clear_file1_contents)
        expect(File.read(clear_file2)).to eq(clear_file2_contents)

        expect { new_safe(password: 'bad password') }
          .to raise_error(Sia::PasswordError)

        new_safe.fill
        new_safe.empty
        new_safe.fill
        new_safe.empty
      end
    end # describe 'an integration test'
  end # describe Sia::Safe

end # RSpec.describe Sia
