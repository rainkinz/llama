require 'simple-rss'
require 'open-uri'
require 'rest_client'
require 'stomp'

module Llama
  module Producer
    class Base < Component
      def produce(*args)
        raise "Subclass #{self} and define this method"
      end

      def producer?
        true
      end
    end

    class PollingProducer < Base
      attr_accessor :poll_period
      
      def initialize(opts={})
        @poll_period = opts.delete(:every)
      end

      def polling?
        !@poll_period.nil?
      end
    end

    class DiskFile < Base 
      def initialize(filename)
        @filename = filename
      end

      def produce(message)
        File.open(@filename){|f| message.body = f.read} 
        return message
      end
    end

    class EventedProducer < Base
      def add_hook(&block)
        @hook = block
      end

      def evented?
        true
      end
    end

    class Stomp < EventedProducer 
      class NoCallBackHook < StandardError; end

      def initialize(host, port, queue, headers={})
        @host, @port, @queue, @headers = host, port, queue, headers
      end

      def produce(message)
        client = ::Stomp::Client.open "stomp://#{@host}:#{@port}"
        client.subscribe("/queue/#{@queue}", @headers) do |msg|
          post(msg)
        end
      end

      def post(msg)
        raise NoCallBackHook unless @hook
        msg = Llama::Message::DefaultMessage.new(:headers => msg.headers, :body => msg.body)
        @hook.call(msg)
      end
    end

    class Http < PollingProducer
      def initialize(url, opts={})
        @url = url
        @method = opts.delete(:method) || :get
        super(opts)
      end

      def produce(message)
        resp = RestClient.send(@method, @url, @opts)
        message.headers = resp.headers
        message.body = resp
        return message
      end
    end

    class RSS < PollingProducer 
      def initialize(url, opts={})
        @url = url
        super(opts)
      end

      def produce(message)
        rss = SimpleRSS.parse open(@url)
        
        return Llama::Message::DefaultMessage.new(
                  :headers => {:title => rss.channel.title, :link => rss.channel.link}, 
                  :body => rss.items) #body is splittable
      end
    end
  end
end
