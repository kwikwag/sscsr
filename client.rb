require "socket"
def get_data()
	File.open('/dev/urandom', 'r') do |file|
		buffer = file.read(1024)
		yield buffer.encode('UTF-8', :invalid => :replace, :undef => :replace, :replace => ' ')
	end
end

if __FILE__ == $0
	TCPSocket.open("localhost", 2626) do |sock|
		get_data do |data|
			sock.send(data, 0)
		end
		sock.close
	end
end
