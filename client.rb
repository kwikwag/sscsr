require "socket"
s = TCPSocket.open("localhost", 2626)
while line = s.gets
	puts "received : #{line.chop}"
end
s.close

