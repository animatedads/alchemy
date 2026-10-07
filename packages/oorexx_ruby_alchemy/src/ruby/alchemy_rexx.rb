# frozen_string_literal: true

module Alchemy
  module Rexx
    class DispatchError < StandardError; end
    class ReleasedHandle < DispatchError; end

    # Runtime-neutral contract. The native bridge implements these operations
    # against a retained ooRexx object. Tests use a local endpoint without
    # changing the projection semantics.
    class Endpoint
      def invoke(_handle, _name, _args, _kwargs, &_block)
        raise NotImplementedError
      end

      def handles?(_handle, _name, _include_private = false)
        false
      end

      def retain(_handle); end
      def release(_handle); end
    end

    # One live Ruby projection of one retained ooRexx identity.
    class Object
      attr_reader :__alchemy_rexx_handle

      def initialize(endpoint, handle)
        @__alchemy_rexx_endpoint = endpoint
        @__alchemy_rexx_handle = handle
        @__alchemy_rexx_released = false
        endpoint.retain(handle)
      end

      # Deterministic, idempotent release of the retained Rexx identity.
      def __alchemy_rexx_release
        return false if @__alchemy_rexx_released
        @__alchemy_rexx_released = true
        @__alchemy_rexx_endpoint.release(@__alchemy_rexx_handle)
        true
      end

      def __alchemy_rexx_released?
        @__alchemy_rexx_released
      end

      # Forward unresolved Ruby messages without capability preflight.
      def method_missing(name, *args, **kwargs, &block)
        raise ReleasedHandle, "ooRexx handle has been released" if @__alchemy_rexx_released
        @__alchemy_rexx_endpoint.invoke(@__alchemy_rexx_handle, name, args, kwargs, &block)
      end

      # Introspection is advisory. Invocation never preflights through this.
      def respond_to_missing?(name, include_private = false)
        return false if @__alchemy_rexx_released
        @__alchemy_rexx_endpoint.handles?(@__alchemy_rexx_handle, name, include_private) ||
          super
      end
    end

    # Interns projections so a retained ooRexx handle reverses to the same
    # Ruby projection while it is live.
    class IdentityRegistry
      def initialize
        @objects = {}
      end

      # Intern one live projection per endpoint/handle identity pair.
      def project(endpoint, handle)
        key = [endpoint.object_id, handle]
        obj = @objects[key]
        return obj if obj && !obj.__alchemy_rexx_released?
        @objects[key] = Object.new(endpoint, handle)
      end

      def release(endpoint, handle)
        key = [endpoint.object_id, handle]
        obj = @objects.delete(key)
        obj&.__alchemy_rexx_release
      end
    end
  end
end
