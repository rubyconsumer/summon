
module Summon
  class Schema
    def self.inherited(mod)            
      class << mod
        include Summon::Schema::Initializer
        include Summon::Schema::ClassMethods
      end
      mod.module_eval do
        include Summon::Schema::InstanceMethods
      end
      mod.summon!
    end

    module Initializer
      def new(values = {}, locale = Summon::DEFAULT_LOCALE)
        dup = {}
        for k, v in values
          dup[k.to_s] = v
        end
        instance = allocate
        instance.instance_eval do
          @src = values
        end
        for attribute in @attrs
          instance.instance_variable_set("@#{attribute.name}", attribute.get(dup))
        end
        instance.instance_variable_set("@default_locale", Summon::DEFAULT_LOCALE)
        instance.instance_eval do
          raise "Locale '#{locale}' does not exist." unless Summon::Locale.const_defined?(locale.upcase)
          @locale = locale
        end
        
        instance
      end
    end
    
    module ClassMethods
      def attr(name, options = {})
        if name.to_s =~ /^(.*)\?$/
          name = $1
          options[:boolean] = true
        end
        symbol = name.to_sym
        @attrs << ::Summon::Schema::Attr.new(symbol, options)
        define_method(name) do |*args|
          self.instance_variable_get("@#{name}")  
        end
        if options[:boolean]
          define_method("#{name}?") do
            send(name)
          end
        end
      end
      
      def attrs
        @attrs
      end
      
      def summon!
        @attrs = []
        attr_reader :src
        attr_accessor :default_locale
      end
    end
    
    module InstanceMethods
      def to_json(*a)
        self.class.attrs.inject({}) do |json, attr|
          json.merge attr.name => self.send(attr.name)
        end.to_json(*a)        
      end
      
      def locale=(value)
        @locale = value
        if Summon::Locale.const_defined?(value.upcase)
          @translator = Summon::Locale.const_get(value.upcase)
        else
          raise "Locale '#{value}' does not exist."
        end
      end
      def locale
        @locale ||= @default_locale
      end
      
      def translate(value)
        @translator ||= Summon::Locale.const_get(locale.upcase)
        @translator::TRANSLATIONS[value] ? @translator::TRANSLATIONS[value] : Summon::Locale.const_get(@default_locale.upcase)::TRANSLATIONS[value] 
      end
    end
    
    class Attr
      attr_reader :name
      def initialize(name, options)
        @name = name
        @boolean = options[:boolean]
        @camel_name = camelize(name.to_s)
        @pascal_name = @camel_name.gsub(/^\w/) {|first| first.upcase}
        @transform = options[:transform]
        @json_name = options[:json_name].to_s if options[:json_name]
        @json_name = "is#{@pascal_name}" if @boolean unless @json_name
        @single = options[:single].nil? ? !(name.to_s.downcase =~ /s$/) : options[:single]
      end
      
      def get(json)
        raw = json[@json_name || @camel_name]
        raw = json[@pascal_name] if raw.nil?
        if raw.nil?
          @single ? nil : []
        else
          raw = @single && raw.kind_of?(Array) ? raw.first : raw
          transform(raw) || raw
        end
      end
      
      def camelize(str)
        str.gsub /(\w)_(\w)/ do 
          "#{$1}#{$2.upcase}"
        end
      end
      
      def transform(raw)
        if @transform
          ctor = proc do |h| 
            ::Summon.const_get(@transform).new(h)
          end
          raw.kind_of?(Array) ? raw.map(&ctor) : ctor.call(raw)
        end
      end
    end
  end
 end