require "openssl"

def hash_sha256(value : String)
  hash = OpenSSL::Digest.new("SHA256")
  hash.update(value)

  hash.hexdigest
end
