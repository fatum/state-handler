module StateHandler
  module Mixing
    def self.included(base)
      base.extend ClassMethods
      base.class_attribute :mapping, :patterns
      base.mapping, base.patterns = {}, {}
    end

    attr_reader :response

    def initialize(response, &block)
      raise ArgumentError unless response.respond_to?(:code)
      @response, @blocks = response, {}
      exec(&block) if block_given?
    end

    def exec(&block)
      # map blocks
      yield(self)

      if state
        @blocks[state].call
      else
        self.class.patterns.each do |s, regex|
          @blocks[s].call if @response.code.to_s =~ regex
        end
      end
    end

    def at(*args, &block)
      args.each { |s| @blocks[s.to_sym] = block }
    end

    def state
      self.class.mapping.keys.each.find { |state| find_mapped(state) }
    end

    def find_mapped(state)
      if self.class.mapping[state].kind_of?(Array)
        self.class.mapping[state].include?(@response.code.to_i)
      else
        self.class.mapping[state] == @response.code.to_i
      end
    end

    def method_missing(name, &block)
      state = name.to_s.gsub(/\?/, '').to_sym

      if name.to_s.end_with?('?')
        raise StateHandler::UnexpectedState, "Got: #{state.inspect}" unless self.class.mapping[state]
        find_mapped(state)
      elsif block_given?
        @blocks[state] = block
      end
    end

    module ClassMethods
      def class_attribute(*attrs)
        attrs.each do |name|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.#{name}() nil end
            def self.#{name}?() !!#{name} end

            def self.#{name}=(val)
              singleton_class.class_eval do
                define_method(:#{name}) { val }
              end
              val
            end
          RUBY
        end
      end

      def map(&block)
        class_eval(&block)
      end

      def match(regexp)
        self.patterns[regexp.values.first] = regexp.keys.first
      end

      def code(*codes, &block)
        if codes.first.kind_of?(Hash)
          self.mapping[codes.first.values.first] = codes.first.keys.first
        elsif block_given?
          self.mapping[yield] = codes
        end
      end
    end
  end
end

