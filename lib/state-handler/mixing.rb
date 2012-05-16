module StateHandler
  module Mixing
    def self.included(base)
      base.extend ClassMethods
      %w{mapping patterns groups}.each do |attr|
        base.class_attribute attr.to_sym
        base.send "#{attr}=", {}
      end
    end

    attr_reader :response

    def initialize(response, &block)
      raise ArgumentError unless response.respond_to?(:code)
      @response, @blocks, @excludes = response, {}, {}
      exec(&block) if block_given?
    end

    def exec(&block)
      # map blocks
      yield(self)

      if state && @blocks[state]
        @blocks[state].call
      end

      if self.class.patterns
        self.class.patterns.each do |s, regex|
          @blocks[s].call if @response.code.to_s =~ regex
        end
      end

      if self.class.groups
        self.class.groups.each do |group, states|
          @blocks[group].call if states.include?(state) && @blocks[group]
        end
      end

      @excludes.each { |s, callback| callback.call unless s == state }
    end

    def at(*args, &block)
      args.each { |s| @blocks[s.to_sym] = block }
    end

    def ex(*args, &block)
      args.each { |s| @excludes[s.to_sym] = block }
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

  private
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
        # TODO: refactor
        # Create Dsl class
        class_eval(&block)
      end

      def match(regexp)
        self.patterns[regexp.values.first] = regexp.keys.first
      end

      def method_missing
      end

      def code(*codes, &block)
        if codes.first.kind_of?(Hash)
          create(codes.first.values.first, codes.first.keys.first)
        elsif block_given?
          create(yield, codes)
        end
      end

      def group(name, &block)
        @current_group = name.to_sym
        class_eval(&block)
        @current_group = nil
      end

    private
      def create(state, value)
        raise ArgumentError, "State '#{state}' already defined" if self.mapping[state]
        self.mapping[state] = value
        if @current_group
          self.groups[@current_group] ||= []
          self.groups[@current_group] << state
        end
      end
    end
  end
end

