module RTunnel
  class Command

    def to_s
      CLASSES_TO_CODES[self.class].dup
    end

    class << self
      def parse(data)
        klass = class_from_code(data[0..0])

        new_data = data[1..-1]
        cmd = klass.parse(new_data)

        data.replace(new_data)

        cmd
      end

      def match(data)
        return false  if ! (klass = class_from_code(data[0..0]))

        klass.match(data[1..-1])
      end

      private

      def class_from_code(code)
        CODES_TO_CLASSES[code]
      end
    end
  end

  class ConnectionCommand < Command
    attr_reader :conn_id

    def initialize(conn_id)
      @conn_id = conn_id
    end

    def to_s
      super + "#{conn_id}|"
    end

    class << self
      RE = %r{^([^|]+)\|}

      def parse(data)
        data =~ RE
        conn_id = $1

        cmd = self.new(conn_id)

        data.sub! RE, ''

        cmd
      end

      def match(data)
        !! (data =~ RE)
      end
    end

  end

  class CreateConnectionCommand < ConnectionCommand
  end

  class CloseConnectionCommand < ConnectionCommand
  end

  class SendDataCommand < Command
    attr_reader :conn_id
    attr_reader :data

    def initialize(conn_id, data)
      @conn_id = conn_id
      @data = data
    end

    def to_s
      super + "#{conn_id}|#{data.size}|#{data}"
    end

    class << self
      RE = %r{^([^|]+)\|([^|]+)\|}

      def parse(data)
        data =~ RE

        conn_id = $1
        data_size = $2.to_i

        new_data = data.sub(RE, '')
        cmd_data = new_data[0,data_size]

        cmd = SendDataCommand.new(conn_id, cmd_data)

        data.replace(new_data[data_size..-1])

        cmd
      end

      def match(data)
        return false  if ! (data =~ RE)

        data_size = $2.to_i

        data.sub(RE, '').size >= data_size
      end
    end
  end

  class RemoteListenCommand < Command
    attr_reader :address

    def initialize(address)
      @address = address
    end

    def to_s
      super + "#{address}|"
    end

    class << self
      RE = %r{^([^|]+)\|}

      def parse(data)
        data =~ RE
        address = $1

        cmd = self.new(address)

        data.sub! RE, ''

        cmd
      end

      def match(data)
        !! (data =~ RE)
      end
    end

  end

  class PingCommand < Command
    def self.parse(data)
      PingCommand.new
    end

    def self.match(data)
      true
    end
  end

  class Command
    CODES_TO_CLASSES = {
      "C" => CreateConnectionCommand,
      "X" => CloseConnectionCommand,
      "D" => SendDataCommand,
      "P" => PingCommand,
      "L" => RemoteListenCommand,
    }
    CLASSES_TO_CODES = CODES_TO_CLASSES.invert
  end
end