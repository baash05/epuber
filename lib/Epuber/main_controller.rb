
require 'pathname'
require 'fileutils'

require_relative 'main_controller/opf_generator'
require_relative 'main_controller/nav_generator'
require_relative 'main_controller/meta_inf_generator'

require_relative 'book'


module Epuber
  class MainController

    BASE_PATH = '.epuber'
    EPUB_CONTENT_FOLDER = 'OEBPS'

    # @param targets [Array<String>] targets names
    #
    def compile_targets(targets = nil)

      # TODO: DEBUG, remove next line
      FileUtils.rmtree(BASE_PATH)


      bookspecs = Pathname.glob(Pathname.pwd + '*.bookspec')

      raise 'Not found .bookspec file' if bookspecs.count.zero?

      bookspecs.each do |bookspec_file_pathname|
        # @type book [Book::Book]
        # @type bookspec_file_pathname [Pathname]

        @book = Book::Book.from_file(bookspec_file_pathname.to_s)
        @book.validate

        puts "loaded book `#{@book.title}`"

        # when the list of targets is nil use them all
        targets ||= @book.targets.map { |target| target.name }

        targets.each do |target_name|
          process_target_named(target_name)
        end

        @book = nil
      end
    end


    private

    # @param target_name [String]
    #
    def process_target_named(target_name)
      @target = target_named(target_name)

      dir_name = File.join(BASE_PATH, 'build', target_name.to_s)
      FileUtils.mkdir_p(dir_name)

      @output_dir = File.expand_path(dir_name)

      puts "  handling target `#{@target.name}` in build dir `#{@output_dir}`"

      process_other_files
      process_toc_item(@book.root_toc)

      # generate nav file (nav.xhtml or nav.ncx)
      nav_file = NavGenerator.new(@book, @target).generate_nav_file
      @target.add_to_all_files(nav_file)
      process_file(nav_file)

      # generate .opf file
      opf_file = OPFGenerator.new(@book, @target).generate_opf_file
      process_file(opf_file)

      # generate mimetype file
      mimetype_file = Epuber::Book::File.new(nil)
      mimetype_file.destination_path = '../mimetype'
      mimetype_file.content = 'application/epub+zip'
      process_file(mimetype_file)

      # generate META-INF files
      meta_inf_files = MetaInfGenerator.new(@book, @target, File.join(EPUB_CONTENT_FOLDER, opf_file.destination_path)).generate_all_files
      meta_inf_files.each { |meta_file|
        process_file(meta_file)
      }

      archive(@output_dir, "experiment-#{target_name}.epub") # TODO: correct file name

      @target = nil
    end

    def process_other_files
      @target.files.each { |file|
        process_file(file)
      }
    end

    # @param toc_item [Epuber::Book::TocItem]
    #
    def process_toc_item(toc_item)
      unless toc_item.file_obj.nil?
        file = toc_item.file_obj

        puts "    processing toc item #{file.source_path_pattern}"

        @target.add_to_all_files(file)
        process_file(file)
      end

      # process recursively other files
      toc_item.child_items.each { |child|
        process_toc_item(child)
      }
    end

    # @param file [Epuber::Book::File]
    #
    def process_file(file)
      dest_path = Pathname.new(destination_path_of_file(file))
      FileUtils.mkdir_p(dest_path.dirname)

      if !file.source_path_pattern.nil?
        file_pathname = Pathname.new(file.real_source_path)

        case file_pathname.extname
        when '.xhtml', '.css'
          FileUtils.cp(file_pathname.to_s, dest_path.to_s)
        else
          raise "unknown file extension #{file_pathname.extname} for file #{file}"
        end
      elsif !file.content.nil?
        # write file
        File.open(dest_path.to_s, 'w') { |file_handle|
          file_handle.write(file.content)
        }
      end
    end

    # @param file [Epuber::Book::File]
    # @return [String]
    #
    def destination_path_of_file(file)
      if file.destination_path.nil?
        real_path = find_file(file)

        file.destination_path = real_path
        file.real_source_path = real_path

        File.join(@output_dir, EPUB_CONTENT_FOLDER, real_path)
      else
        File.join(@output_dir, EPUB_CONTENT_FOLDER, file.destination_path)
      end
    end

    # @param file_or_pattern [String, Epuber::Book::File]
    # @return [String]
    #
    def find_file(file_or_pattern)
      pattern = if file_or_pattern.is_a?(Epuber::Book::File)
                  file_or_pattern.source_path_pattern
                else
                  file_or_pattern
                end

      # @type file_path_names [Array<Pathname>]
      file_path_names = Pathname.glob("**/#{pattern}*")

      file_path_names.select! { |file_pathname|
        !file_pathname.to_s.include?(BASE_PATH)
      }

      raise "not found file matching pattern `#{pattern}`" if file_path_names.empty?
      raise 'found too many files' if file_path_names.count >= 2

      file_path_names.first.to_s
    end

    # @param target_name [String]
    #
    # @return [Epuber::Book::Target]
    #
    def target_named(target_name)
      target = @book.targets.find { |target|
        target.name == target_name
      }

      raise "Not found target with name #{target_name}" if target.nil?
      target
    end

    # @param cmd [String]
    #
    def run_command(cmd, quite: false)
      system(cmd)

      $stdout.flush
      $stderr.flush

      code = $?
      raise 'wrong return value' if code != 0
    end

    def archive(folder_path, zip_file_path)
      abs_zip_file_path = File.expand_path(zip_file_path)

      Dir.chdir(folder_path) {
        all_files = Dir.glob('**/**')

        run_command(%{zip -q0X "#{abs_zip_file_path}" mimetype})
        run_command(%{zip -Xr9D "#{abs_zip_file_path}" "#{all_files.join('" "')}" --exclude \\*.DS_Store})
      }
    end
  end
end
