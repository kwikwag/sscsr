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

def sym_encrypt_data(data, key=nil, return_key: false)
	cipher = OpenSSL::Cipher::AES.new(128, :CFB).encrypt
	iv = cipher.random_iv
	if key.nil?
		key = cipher.random_key
	end
	cipher.key = key
	cipher.iv = iv
	encrypted_data = cipher.update(data) + cipher.final

	# TODO : maybe encrypt iv with key using iv-less cipher
	encrypted_obj = { :iv => Base64.encode64(iv), :data => Base64.encode64(encrypted_data) }
	
	if return_key
		return key, encrypted_obj
	else
		return encrypted_obj
	end
end

def asym_encrypt_data(data, key)
	public_key = OpenSSL::PKey::RSA.new(key)

	# I decided against reusing sym_encrypt_data here
	data_key, encrypted_obj = sym_encrypt_data(data, return_key: true)
	encrypted_key = public_key.public_encrypt(data_key)
	encrypted_obj[:key] = Base64.encode64(encrypted_key)

	return encrypted_obj
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
		data = get_data()
		if symmetric
			encrypted_obj = sym_encrypt_data(data, key)
		else
			encrypted_obj = asym_encrypt_data(data, key)
		end
		sock.send(JSON.generate(encrypted_obj), 0)
		sock.close
		print data
	end
end
