require 'socket'
require 'logger'
require 'openssl'
require 'json'
require 'base64'
require 'pp'

$logger = Logger.new(STDOUT)
$logger.level = Logger::WARN if ENV['DEBUG'].nil?

BUFFER_SIZE = 65536

class NoData < StandardError
end

class InvalidEncryptionTag < StandardError
end

def handle_client_session(client, key, password, symmetric)
	$logger.debug('Session start.')

	# don't expect a too-long message
	buffer = client.read(65536)
	raise NoData.new if buffer.nil?
	$logger.debug("Read #{buffer.length} bytes.")

	# read message body and let JSON module
	# handle any errors
	encrypted_obj = JSON.parse(buffer)

	# decrypt and display the message
	$logger.debug("JSON read: #{JSON.generate(encrypted_obj)}. Decrypting.")
	if symmetric
		if not password.nil?
			$logger.warn('Password not nil for symmetric encryption. Ignoring.')
		end
		print sym_decrypt_data(encrypted_obj, key)
	else
		print asym_decrypt_data(encrypted_obj, key, password)
	end
end

def asym_decrypt_data(obj, key, password)
	# see https://stackoverflow.com/questions/12662902/ruby-openssl-asymmetric-encryption-using-two-key-pairs
	private_key = OpenSSL::PKey::RSA.new(key, password)
	data_key = private_key.private_decrypt(Base64.decode64(obj['key']))
	data = sym_decrypt_data(obj, data_key)
end

def sym_decrypt_data(obj, key)
	# see http://ruby-doc.org/stdlib-2.4.1/libdoc/openssl/rdoc/OpenSSL/Cipher.html
	decipher = OpenSSL::Cipher::AES.new(128, :CFB).decrypt
	decipher.key = key
	decipher.iv = Base64.decode64(obj['iv'])
	return decipher.update(Base64.decode64(obj['data'])) + decipher.final
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

def fail_usage()
	STDERR.puts <<~USAGE
		Usage: env SSCSR_KEY=key [SSCSR_PRIVATE_KEY_PASSWORD=pwd] ruby #{__FILE__} PORT {symmetric,assymetric}

		Note: SSCSR_PRIVATE_KEY_PASSWORD is required if using asymmetric encryption.

		Examples:
			1. SSCSR_KEY=$(seq 1 10 | tr '\\n' 'x') ruby #{__FILE__} 2626 symmetric
			2. SSCSR_KEY=$(cat private_key.pem) SSCSR_PRIVATE_KEY_PASSWORD=helloworld ruby #{__FILE__} 2626 asymmetric
	USAGE
	exit(1)
end


if __FILE__ == $0
	key = ENV['SSCSR_KEY']

	if (ARGV.length != 2 or key.nil?)
		fail_usage
	end

	port = ARGV[0].to_i
	symmetric = ARGV[1] == 'symmetric' # really, i should check this argument

	if not symmetric
		password = ENV['SSCSR_PRIVATE_KEY_PASSWORD']
		if password.nil?
			fail_usage
		end
	end

	threaded_server(port) do |client|
		handle_client_session(client, key, password, symmetric)
	end
end
