require 'socket'
require 'openssl'
require 'json'
require 'securerandom'
require 'base64'
require 'optparse'

def gen_random_bytes(len, insist_on_urandom=true)
	if insist_on_urandom
		File.open( '/dev/urandom', 'r') do |file|
			return file.read(len)
		end
	else
		return SecureRandom.random_bytes(len)
	end
end
		
def get_data()
	buffer = gen_random_bytes(1024, insist_on_urandom=((ENV['SSCSR_INSIST_ON_URANDOM'] || '1') == '1'))
	return buffer.encode('UTF-8', :invalid => :replace, :undef => :replace, :replace => ' ')
end

def sym_encrypt_data(data, key)
	cipher = OpenSSL::Cipher::AES.new(128, :CFB).encrypt
	iv = cipher.random_iv
	cipher.key = key
	cipher.iv = iv
	# TODO : encrypt iv with key using iv-less cipher
	return { :iv => Base64.encode64(iv), :data => Base64.encode64(cipher.update(data) + cipher.final) }
end

def asym_encrypt_data(data, key)
	public_key = OpenSSL::PKey::RSA.new(key)
	return { :data => Base64.encode64(public_key.public_encrypt(data)) }
end

def fail_usage()
	STDERR.puts <<~USAGE
		Usage: SSCSR_KEY=key [SSCSR_INSIST_ON_URANDOM={0,1}] ruby #{__FILE__} HOST PORT {symmetric,asymmetric}"
	USAGE
	exit(1)
end

if __FILE__ == $0
	key = ENV['SSCSR_KEY'] || 'using a hard-coded default key is not very secure, but it will do.'

	if ARGV.length != 3
		fail_usage
	end
	host = ARGV[0]
	port = ARGV[1].to_i
	symmetric = ARGV[2] == 'symmetric' # really, i should check this argument

	TCPSocket.open(host, port) do |sock|
		if symmetric
			encrypted_obj = sym_encrypt_data(get_data(), key)
		else
			encrypted_obj = asym_encrypt_data(get_data(), key)
		end
		sock.send(JSON.generate(encrypted_obj), 0)
		sock.close
	end
end
