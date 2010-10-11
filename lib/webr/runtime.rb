module Webr
  class Runtime
    attr_reader :context, :process
    
    def initialize
      @context = V8::Context.new
      @context["process"]     = Process.new(@context)
      @context["__filename"]  = __FILE__
      @context["__dirname"]   = File.dirname(__FILE__)
      @context["module"]      = @context["Object"].new
      @context["exports"]     = @context["Object"].new

      @context["setTimeout"]    = lambda { |callback, timeout|  timeout_set(callback, timeout) }
      @context["clearTimeout"]  = lambda { |handle| timeout_clear(handle) }
      @context["setInterval"]   = lambda { |callback, interval| interval_set(callback, interval) }
      @context["clearInterval"] = lambda { |handle| interval_clear(handle) }

      return_module      = lambda { |namespace, trail| module_read(namespace, trail) }
      return_module_path = lambda { |namespace, trail| module_path(namespace, trail) }
      define_require = @context.load("#{SCRIPT_PATH}/require.js")
      @context["require"] = define_require.call(@context.scope, @context["Object"].new, return_module, return_module_path)
    end
    
    def load(file_name)
      path = File.expand_path(file_name)
      dir  = File.dirname(path)
      @context.load(file_name)
    end    
    
    def timeout_set(callback, timeout)
      Thread.new do
        sleep(timeout.to_f/1000)
        callback.call
      end
    end
    
    def timeout_clear(handle)
      handle.kill
    end

    def interval_set(callback, interval)
      Thread.new do
        loop do
          sleep(interval.to_f/1000)
          callback.call
        end
      end
    end
    
    def interval_clear(handle)
      handle.kill
    end
    
    def module_read(namespace, trail = [])
      trail = trail.to_a
      paths = []
      paths << "#{MODULE_PATH}/#{namespace}.js"
      paths << "#{namespace}.js"
      paths << "#{namespace}/index.js"
      paths << "#{trail.join('/')}/#{namespace}.js"
      paths << "#{trail.join('/')}/#{namespace}/index.js"

      paths.each do |p|
        return File.new(p).read if File.exists?(p)
      end
    
      raise "Can't resolve namespace: #{namespace}"
    end
    
    def module_path(namespace, trail = [])
      if File.directory?("#{trail.join('/')}/#{namespace}")
        return namespace
      else
        return File.dirname(namespace)
      end
    end
    
  end
    
end