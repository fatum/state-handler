module StateHandler
  module Mixin
    def self.included(base)
      base.extend ClassMethods
      %w{mapping patterns groups attr}.each do |attr|
        base.class_attribute attr.to_sym
        base.send "#{attr}=", {}
      end
    end

    attr_reader :response

    def initialize(response, &block)
      @response, @blocks, @excludes = response, {}, {}

      raise ArgumentError unless response.respond_to?(attribute)
      exec(&block) if block_given?
    end

    def exec(&block)
      # map blocks
      yield(self)

      if state && @blocks[state]
        @blocks[state].call
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
      patterns = self.class.patterns
      mapping = self.class.mapping

      mapping.keys.each.find { |state| find_mapped(state) } ||
        patterns.key(
          patterns.values.each.find do |regex|
            get_attribute_value.to_s =~ regex
          end
        )
    end

    def find_mapped(state)
      if self.class.mapping[state].kind_of?(Array)
        self.class.mapping[state].include?(get_attribute_value)
      else
        self.class.mapping[state] == get_attribute_value
      end
    end

    def attribute
      self.class.attr
    end

    def get_attribute_value
      @response.send attribute
    end

    def method_missing(name, &block)
      state = name.to_s.gsub(/\?/, '').to_sym

      if name.to_s.end_with?('?')
        unless self.class.mapping[state] || self.class.patterns[state]
          raise StateHandler::UnexpectedState, "Got: #{state.inspect}"
        end
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

      def attribute(attr)
        self.attr = attr.to_sym
      end

      def match(regexp)
        state = regexp.values.first
        self.patterns[state] = regexp.keys.first
        add_to_group(state)
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
        add_to_group(state)
      end

      def add_to_group(state)
        if @current_group
          self.groups[@current_group] ||= []
          self.groups[@current_group] << state
        end
      end
    end
  end
end

