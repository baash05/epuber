# encoding: utf-8

require_relative '../../../spec_helper'

require 'epuber/book'
require 'epuber/compiler'
require 'epuber/compiler/file_types/abstract_file'


module Epuber
  class Compiler
    module FileTypes



      describe AbstractFile do
        include FakeFS::SpecHelpers

        context 'write_to_file?' do
          it 'do not need to write when the file is same' do
            File.write('a.txt', 'some content, so we can compare it')

            expect(AbstractFile.write_to_file?('some content, so we can compare it', 'a.txt')).to be_falsey
          end

          it 'needs to write when the file is different' do
            File.write('a.txt', 'some content, so we can compare it')

            expect(AbstractFile.write_to_file?('some different content', 'a.txt')).to be_truthy
          end
        end

        context 'copy_file?' do
          it 'does not need to copy when the source file is older' do
            content = 'some content, so we can compare it'
            File.write('source.txt', content)
            File.write('dest.txt', content)

            # source file is older then dest file
            expect(File.mtime('source.txt') < File.mtime('dest.txt')).to be_truthy

            expect(AbstractFile.file_copy?('source.txt', 'dest.txt')).to be_falsey
          end

          it 'needs to copy when the file is newer and has different content' do
            File.write('dest.txt', 'some content, so we can compare it')
            File.write('source.txt', 'some new content, looks very shiny, right?')

            expect(File.mtime('source.txt') > File.mtime('dest.txt')).to be_truthy

            expect(AbstractFile.file_copy?('source.txt', 'dest.txt')).to be_truthy
          end
        end
      end



    end
  end
end
