require "socket"

def handle_client_session(client)
	client.puts "Hello, world."
end

def threaded_server(port)
	server = TCPServer.open(port)
	loop do
		Thread.fork(server.accept) do |client|
			yield client
			client.close
		end
	end
end

if __FILE__ == $0
	threaded_server(2626) do |client|
		handle_client_session(client)
	end
end
