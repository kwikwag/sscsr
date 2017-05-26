require "socket"
server = TCPServer.open(2626)
loop do
	Thread.fork(server.accept) do |client| 
		client.puts("Hello, I'm Ruby TCP server", "I'm disconnecting, bye :*")
		client.close
	end
end
