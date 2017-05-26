require 'socket'
require 'logger'

$logger = Logger.new(STDOUT)
$logger.level = Logger::DEBUG

BUFFER_SIZE = 65536

class NoData < StandardError
end

def handle_client_session(client)
	$logger.debug('Session start.')
	buffer = client.read(65536)
	$logger.debug("Read #{buffer.length} bytes.")
=begin
	disconnected = false
	while not disconnected do
		begin
			$logger.debug('Before non-block read')
			data = client.recv_nonblock(BUFFER_SIZE)
			disconnected = data.length == 0
			$logger.debug('After non-block read')
		rescue IO::WaitReadable, NoData
			$logger.debug('Before select')
			result = IO.select([client], nil, nil, 1)
			disconnected = result.nil?
			$logger.debug("After select... Disconnected? #{disconnected}")
			retry unless disconnected
		end
	
		disconnected = true if c > 5
		$logger.debug("Received #{data.length} bytes")
	end
=end
	$logger.debug('Client session ended.')
end

def threaded_server(port)
	server = TCPServer.open(port)
	loop do
		Thread.fork(server.accept) do |client|
			begin
				$logger.debug('Connected to client. Handling session.')
				yield client
				$logger.debug('Client session ended. Closing socket.')
			rescue => exception
				$logger.error(exception.message + "\n" + exception.backtrace.join("\n"))
				$logger.debug('Client session erred. Closing socket.')
			end
			client.close
		end
	end
end

if __FILE__ == $0
	threaded_server(2626) do |client|
		handle_client_session(client)
	end
end
