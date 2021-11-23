require "digest/sha256"

def hash_sha256(value : String)
  Digest::SHA256.digest(value).hexstring
end
