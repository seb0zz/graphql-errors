# frozen_string_literal: true

require "graphql"
require "graphql/errors/version"

module GraphQL
  class Errors
    def self.configure(schema, &block)
      instance = new(&block)
      schema.instrument(:field, instance)
    end

    def initialize(&block)
      @handler_by_class = {}
      self.instance_eval(&block)
    end

    def use(schema_definition)
      schema_definition.instrument(:field, self)
    end

    def instrument(type, field)
      old_resolve_proc = field.resolve_proc
      new_resolve_proc = ->(object, arguments, context) do
        begin
          old_resolve_proc.call(object, arguments, context)
        rescue => exception
          if handler = find_handler(exception)
            handler.call(exception)
          else
            raise exception
          end
        end
      end

      field.redefine { resolve(new_resolve_proc) }
    end

    # TODO: validate args
    def rescue_from(*classes, &block)
      classes.each do |klass|
        @handler_by_class[klass] ||= block
      end
    end

    private

    def find_handler(exception)
      @handler_by_class.each do |klass, handler|
        return handler if exception.is_a?(klass)
      end
    end
  end
end