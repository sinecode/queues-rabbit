# frozen_string_literal: true

module Queues
  module Rabbit
    class Queue
      class << self
        attr_accessor :arguments, :auto_delete, :durable, :name, :no_ack, :prefetch, :schema

        def bind(exchange, binding_key, arguments: {})
          exchange = exchange < Queues::Rabbit::Exchange ? exchange.name : exchange
          queue_instance.bind(exchange, binding_key, arguments: arguments)
          true
        rescue Exception => e
          logger.error_with_report "Unable to bind '#{name}' to '#{exchange}' with key '#{binding_key}' and arguments: '#{arguments}': #{e.message}."
          false
        end

        def delete
          queue_instance.delete
          true
        rescue Exception => e
          logger.error_with_report "Unable to delete #{name}: #{e.message}."
          false
        end

        def logger
          @@logger ||= Queues::Rabbit::Logger.new(name, Queues::Rabbit.log_level)
        end

        def queue(name, arguments: {}, auto_ack: true, auto_delete: false, durable: true, prefetch: 1)
          self.arguments = arguments
          self.auto_delete = auto_delete
          self.durable = durable
          self.name = name
          self.no_ack = auto_ack
          self.prefetch = prefetch
          self
        end

        def queue_instance
          @@queue_instance ||= schema.client_instance.queue(name, arguments: arguments, auto_delete: auto_delete, durable: durable)
        end

        #
        # <Description>
        #
        # @param [String] body                                The message body, can be a string or either a byte array
        # @param [Hash] properties Request properties
        # @option properties [String] :app_id                  Used to identify the app that generated the message
        # @option properties [String] :content_encoding        Content encoding of the body
        # @option properties [String] :content_type            Content type of the body
        # @option properties [Integer] :correlation_id         The correlation id, mostly used used for RPC communication
        # @option properties [Integer] :delivery_mode          2 for persistent messages, all other values are for transient messages
        # @option properties [Integer, String] :expiration     Number of seconds the message will stay in the queue
        # @option properties [Hash<String, Object>] :headers   Custom headers
        # @option properties [Boolean] :mandatory              The message will be returned if the message can't be routed to a queue
        # @option properties [String] :message_id              Can be used to uniquely identify the message, e.g. for deduplication
        # @option properties [Boolean] :persistent             Same as delivery_mode: 2
        # @option properties [Integer] :priority               The message priority (between 0 and 255)
        # @option properties [String] :reply_to                Queue to reply RPC responses to
        # @option properties [Date] :timestamp                 Often used for the time the message was originally generated
        # @option properties [String] :type                    Can indicate what kind of message this is
        # @option properties [String] :user_id                 Used to identify the user that published the message
        #
        # @return [Boolean] true if published, false otherwise
        #
        def publish(body, **properties)
          queue_instance.publish(body, **properties)
          true
        rescue Exception => e
          logger.error_with_report "Unable to publish to #{name}: #{e.message}."
          false
        end

        def purge
          queue_instance.purge
          true
        rescue Exception => e
          logger.error_with_report "Unable to purge #{name}: #{e.message}."
          false
        end

        def subscribe
          logger.info { "Subscribing to queue #{name}" }
          consumer = new
          queue_instance.subscribe(no_ack: no_ack, prefetch: prefetch) do |message|
            consumer.consume(Queues::Rabbit::Message.new(message))
          rescue Exception => e
            logger.error { e.message }
            logger.stdout e.message, :error
          end

          loop do
            logger.stdout "Connection to #{name} alive."
            sleep 10
          end
        rescue Exception => e
          logger.error_with_report "Unable to connect to #{name}: #{e.message}."
          false
        end

        def unbind(exchange, binding_key, arguments: {})
          exchange = exchange < Queues::Rabbit::Exchange ? exchange.name : exchange
          queue_instance.unbind(exhange, binding_key, arguments: arguments)
          true
        rescue Exception => e
          logger.error_with_report "Unable to unbind '#{name}' to '#{exchange}' with key '#{binding_key}' and arguments: '#{arguments}': #{e.message}."
          false
        end
      end

      def consume(_message)
        raise NoMethodError.new("Method #{__method__} must be defined to subscribe a queue!")
      end
    end
  end
end
