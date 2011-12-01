module Llama
  class Component
    def respond(message)
      message = case self
        when Llama::Producer::Base
          produce(message)
        when Llama::Consumer::Base   
          consume(message)
        else 
          process(message)
      end
      return message
    end

    def producer?
      false
    end

    def consumer?
      false
    end

    def polling?
      false
    end

    def evented?
      false
    end
  end
end
