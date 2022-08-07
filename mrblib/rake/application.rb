module Rake
  class Application
    attr_accessor :tasks

    DEFAULT_RAKEFILES = %w[Rakefile rakefile Rakefile.rb rakefile.rb]

    def initialize
      @rakefiles = DEFAULT_RAKEFILES.dup
      # @rakefile = nil
      # @original_dir = Dir.pwd
      @tasks = {}

      # The name of the application (typically 'rake')
      @name = "rake"
      # The original directory where rake was invoked.
      @original_dir = Dir.pwd
      # Name of the actual rakefile used.
      @rakefile = nil
      # Number of columns on the terminal
      @terminal_columns = nil # ENV["RAKE_COLUMNS"].to_i
      # List of the top level task names (task names from the command line).
      @top_level_tasks = []
      # Override the detected TTY output state (mostly for testing)
      # @tty_output = nil
    end

    # public ----------------------------------------------------------------

    def run
      init_args
      load_rakefile
      top_level
    rescue Exception => e
      puts "mrake aborted!"
      p e
      Dir.chdir(@original_dir)
    end

    # attr_accessor, attr_reader, attr_writer, attr_*

    def args
      @args.dup
    end

    def top_level_tasks
      @top_level_tasks
    end

    # Application options from the command line
    def options
      @options ||= OpenStruct.new # MRUBY: support for OpenStruct?
    end

    # internal ----------------------------------------------------------------

    # Invokes a task with arguments that are extracted from +task_string+
    def invoke_task(task_string)
      name, args = parse_task_string(task_string)
      # t = self[name] # MRUBY: TODO: not the same.
      t = @tasks[name]
      puts "name: #{name}"
      t.invoke(*args)
    end

    def parse_task_string(string)
      /^([^\[]+)(?:\[(.*)\])$/ =~ string.to_s

      name           = $1
      remaining_args = $2

      return string, [] unless name
      return name,   [] if     remaining_args.empty?

      args = []

      begin
        /\s*((?:[^\\,]|\\.)*?)\s*(?:,\s*(.*))?$/ =~ remaining_args

        remaining_args = $2
        args << $1.gsub(/\\(.)/, '\1')
      end while remaining_args

      return name, args
    end

    def init_args
      @argv = ARGV.dup
    end

    def define_task(task_klass, *args, &block)
      name, deps = resolve_args(args)
      t = task_klass.new(name)
      @tasks[name] = t
      deps = deps.map{|d| d.to_s}
      t.enhance(deps, &block)
      t
    end

    def resolve_args(args)
      task_name = args.first
      case task_name
      when Hash
        n = task_name.keys[0]
        [n.to_s, task_name[n].flatten]
      else
        [task_name.to_s, []]
      end
    end

    def load_rakefile
      rakefile, location = find_rakefile
      fail "No Rakefile found (looking for: #{@rakefiles.join(', ')})" if rakefile.nil?
      @rakefile = rakefile
      print_load_file File.expand_path(@rakefile) if location != @original_dir
      Dir.chdir(location)
      load(File.expand_path(@rakefile)) if @rakefile && @rakefile != ''
    end

    # def top_level
    #   puts 'hi'
    #   if @argv.empty?
    #     if Rake.application.tasks.has_key?('default')
    #       @tasks['default'].invoke
    #     else
    #       fail "Don't know how to build task 'default'"
    #     end
    #   else
    #     # TODO: iterate and run the args like real RAKE.
    #     @tasks[@argv.first].invoke
    #   end
    # end

    # Run the top level tasks of a Rake application.
    def top_level
      # MRUBY: support for threading?
      # run_with_threads do
        if true # options.show_tasks
        #   display_tasks_and_comments
        # elsif options.show_prereqs
        #   display_prerequisites
        # else
          top_level_tasks.each { |task_name| invoke_task(task_name) }
          top_level_tasks.each do |task_name|
            puts 'task_name: #{task_name}'
            invoke_task(task_name)
          end
        end
      # end
    end

    # Collect the list of tasks on the command line.  If no tasks are
    # given, return a list containing only the default task.
    # Environmental assignments are processed at this time as well.
    #
    # `args` is the list of arguments to peruse to get the list of tasks.
    # It should be the command line that was given to rake, less any
    # recognised command-line options, which OptionParser.parse will
    # have taken care of already.
    def collect_command_line_tasks(args)
      @top_level_tasks = []
      args.each do |arg|
        if arg =~ /^(\w+)=(.*)$/m
          ENV[$1] = $2  # MRUBY: support for ENV?
        else
          @top_level_tasks << arg unless arg =~ /^-/
        end
      end
      @top_level_tasks.push(default_task_name) if @top_level_tasks.empty?
    end

    # Default task name ("default").
    # (May be overridden by subclasses)
    def default_task_name
      "default"
    end

    def find_rakefile
      here = Dir.pwd
      until (fn = have_rakefile)
        Dir.chdir("..")
        return nil if Dir.pwd == here
        here = Dir.pwd
      end
      [fn, here]
    ensure
      Dir.chdir(@original_dir)
    end

    def have_rakefile
      @rakefiles.each do |fn|
        if File.exist?(fn)
          return fn
        end
      end
      nil
    end

    def print_load_file(filename)
      puts "(in : #{filename})"
    end
  end
end
