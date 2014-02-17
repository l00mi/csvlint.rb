require 'set'

module Csvlint
  
  class Field
    include Csvlint::ErrorCollector

    attr_reader :name, :constraints

    TYPE_VALIDATIONS = {
        'http://www.w3.org/2001/XMLSchema#int'     => lambda { |value| Integer value },
        'http://www.w3.org/2001/XMLSchema#float'   => lambda { |value| Float value },
        'http://www.w3.org/2001/XMLSchema#double'   => lambda { |value| Float value },
        'http://www.w3.org/2001/XMLSchema#anyURI'  => lambda do |value|
          u = URI.parse value
          raise ArgumentError unless u.kind_of?(URI::HTTP) || u.kind_of?(URI::HTTPS)
          u
        end,
        'http://www.w3.org/2001/XMLSchema#boolean' => lambda do |value|
          return true if ['true', '1'].include? value
          return false if ['false', '0'].include? value
          raise ArgumentError
        end,
        'http://www.w3.org/2001/XMLSchema#nonPositiveInteger' => lambda do |value|
          i = Integer value
          raise ArgumentError unless i <= 0
          i
        end,
        'http://www.w3.org/2001/XMLSchema#negativeInteger' => lambda do |value|
          i = Integer value
          raise ArgumentError unless i < 0
          i
        end,
        'http://www.w3.org/2001/XMLSchema#nonNegativeInteger' => lambda do |value|
          i = Integer value
          raise ArgumentError unless i >= 0
          i
        end,
        'http://www.w3.org/2001/XMLSchema#positiveInteger' => lambda do |value|
          i = Integer value
          raise ArgumentError unless i > 0
          i
        end
    }

    MINIMUM = lambda { |field, value, min, row, column, | }
      
    def initialize(name, constraints={})
      @name = name
      @constraints = constraints || {}
      @uniques = Set.new
      reset
    end
    
    def validate_column(value, row=nil, column=nil)
      reset
      validate_length(value, row, column)
      validate_values(value, row, column)
      parsed = validate_type(value, row, column)
      validate_range(parsed, row, column) if parsed != nil
      return valid?
    end

    private
      def validate_length(value, row, column)
        if constraints["required"] == true
          build_errors(:missing_value, :schema, row, column) if value.nil? || value.length == 0
        end
        if constraints["minLength"]
          build_errors(:min_length, :schema, row, column) if value.nil? || value.length < constraints["minLength"]
        end
        if constraints["maxLength"]
            build_errors(:max_length, :schema, row, column) if !value.nil? && value.length > constraints["maxLength"]
        end
      end
      
      def validate_values(value, row, column)
        if constraints["pattern"]
          build_errors(:pattern, :schema, row, column) if !value.nil? && !value.match( constraints["pattern"] )
        end
        if constraints["unique"] == true
          if @uniques.include? value
            build_errors(:unique, :schema, row, column)
          else
            @uniques << value
          end
        end
      end
      
      def validate_type(value, row, column)
        if constraints["type"]
          parsed = convert_to_type(value)
          if parsed == nil
            build_errors(:invalid_type, :schema, row, column)
            return nil
          end
          return parsed
        end
        return nil
      end
      
      def validate_range(value, row, column)
        if constraints["minimum"]
          minimumValue = convert_to_type( constraints["minimum"] )
          #TODO what if we have no value, e.g. schema is invalid?
          build_errors(:invalid_range, :schema, row, column) unless value >= minimumValue            
        end
        if constraints["maximum"]
          maximumValue = convert_to_type( constraints["maximum"] )
          #TODO what if we have no value, e.g. schema is invalid?
          build_errors(:invalid_range, :schema, row, column) unless value <= maximumValue            
        end
      end

      def convert_to_type(value)
        parsed = nil
        tv = TYPE_VALIDATIONS[constraints["type"]]
        if tv
          begin
            parsed = tv.call value
          rescue ArgumentError
          end
        end
        return parsed
      end            
  end
end