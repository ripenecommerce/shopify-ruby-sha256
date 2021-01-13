# SHA-256 based integrity check for Shopify Scripts
#
# From: https://github.com/in3rsha/sha256-animation/blob/master/sha256lib.rb
# Modified to work within the limits of Shopify Scripts

# -----
# Utils - Handy functions for converting integers and strings to binary
# -----

# Convert integer to binary string (32 bits) - modified from original
def bits(x, n = 32)
  if x >= 0
    return x.to_s(2).rjust(n, '0') # "%0#{n}b" % x does not work in Shopify
  else
    # Note: Ruby NOT function returns a negative number, and .to_s(2) displays this mathematical representation in base 2.
    # Note: So to get the expected unsigned notation you need to get the individual bits instead.
    # Note: When doing so, ignore the first bit because that's the sign bit.
    # https://www.calleerlandsson.com/rubys-bitwise-operators/
    return (n - 1).downto(0).map { |i| x[i] }.join
  end
end

# Convert integer to hexadecimal string (32 bits)
def hex(i)
  return i.to_s(16).rjust(8, "0")
end

# Convert string to binary string
def bitstring(string)
  bytes = string.bytes                  # convert ascii characters to bytes (integers)
  binary = bytes.map { |x| bits(x, 8) } # convert bytes to binary strings (8 bits in a byte)
  return binary.join
end

# Convert input (hex, ascii) to array of bytes
def bytes(input, type)
  case type
    # Removed unused "binary" type from original
    when "hex"
      hex = input[2..-1] # trim 0x prefix
      bytes = [hex].pack("H*").unpack("C*") # convert hex string to bytes
    else
      bytes = input.bytes # convert ASCII string to bytes
  end

  return bytes
end

# ----------
# Operations
# ----------
# Addition modulo 2**32
def add(*x)
  total = x.inject(:+)
  return total % 2 ** 32 # limits result of addition to 32 bits
end

# Rotate right (circular right shift)
def rotr(n, x)
  right = (x >> n)              # right shift
  left = (x << 32 - n)          # left shift
  result = right | left         # combine to create rotation effect
  return result & (2 ** 32 - 1) # use mask to truncate result to 32 bits
end

# Shift right
def shr(n, x)
  result = x >> n
  return result
end

# ---------
# Functions - Combined rotations and shifts using operations above
# ---------
def sigma0(x)
  return rotr(7, x) ^ rotr(18, x) ^ shr(3, x)
end
def sigma1(x)
  return rotr(17, x) ^ rotr(19, x) ^ shr(10, x)
end
def usigma0(x)
  return rotr(2, x) ^ rotr(13, x) ^ rotr(22, x)
end
def usigma1(x)
  return rotr(6, x) ^ rotr(11, x) ^ rotr(25, x)
end

# Choice - Use first bit to choose the (1)second or (0)third bit
def ch(x, y, z)
  return (x & y) ^ (~x & z)
end

# Majority - Result is the majority of the three bits
def maj(x, y, z)
  return (x & y) ^ (x & z) ^ (y & z)
end


# -------------
# Preprocessing
# -------------
# Pad binary string message to multiple of 512 bits
def padding(message)
  l = message.size  # size of message (in bits)
  k = (448 - l - 1) % 512 # pad with zeros up to 448 bits (64 bits short of 512 bits)
  l64 = bits(l, 64) # binary representation of message size (64 bits in length)
  return message + "1" + ("0" * k) + l64 # don't forget "1" bit between message and padding
end

# Cut padded message in to 512-bit message blocks - modified
def split(message, size = 512)
  return (0..(message.length-1)/size).map{|i|message[i*size,size]} # message.scan(/.{#{size}}/)
end

# ----------------
# Message Schedule
# ----------------
# Calculate the 64 words for the message schedule from the message block
def calculate_schedule(block)
  # The message block provides the first 16 words for the message schedule (512 bits / 32 bits = 16 words)
  schedule = split(block,32).map { |w| w.to_i(2) } # convert from binary string to integer for calculations

  # Calculate remaining 48 words
  16.upto(63) do |i|
    schedule << add(sigma1(schedule[i - 2]), schedule[i - 7], sigma0(schedule[i - 15]), schedule[i - 16])
  end

  return schedule
end


# ---------
# Constants
# ---------
# Constants = Cube roots of the first 64 prime numbers (first 32 bits of the fractional part)
K = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311].map { |prime| prime ** (1 / 3.0) }.map { |i| (i - i.floor) }.map { |i| (i * 2 ** 32).floor }

# -----------
# Compression - Run compression function on the message schedule and constants
# -----------
# Initial Hash Values = Square roots of the first 8 prime numbers (first 32 bits of the fractional part)
IV = [2, 3, 5, 7, 11, 13, 17, 19].map { |prime| prime ** (1 / 2.0) }.map { |i| (i - i.floor) }.map { |i| (i * 2 ** 32).floor }
def compression(initial, schedule, constants)
  # state register - set initial values ready for the compression function
  h = initial[7]
  g = initial[6]
  f = initial[5]
  e = initial[4]
  d = initial[3]
  c = initial[2]
  b = initial[1]
  a = initial[0]

  # compression function - update state for every word in the message schedule
  64.times do |i|
    # calculate temporary words
    t1 = add(schedule[i], constants[i], usigma1(e), ch(e, f, g), h)
    t2 = add(usigma0(a), maj(a, b, c))

    # rotate state registers one position and add in temporary words
    h = g
    g = f
    f = e
    e = add(d, t1)
    d = c
    c = b
    b = a
    a = add(t1, t2)
  end

  # Final hash values are previous intermediate hash values added to output of compression function
  hash = []
  hash[7] = add(initial[7], h)
  hash[6] = add(initial[6], g)
  hash[5] = add(initial[5], f)
  hash[4] = add(initial[4], e)
  hash[3] = add(initial[3], d)
  hash[2] = add(initial[2], c)
  hash[1] = add(initial[1], b)
  hash[0] = add(initial[0], a)

  # return final state
  return hash
end

# -------
# SHA-256 - Complete SHA-256 function
# -------
def sha256(string)
  # 0. Convert String to Binary
  # ---------------------------
  message = bitstring(string)

  # 1. Preprocessing
  # ----------------
  # Pad message
  padded = padding(message)

  # Split up in to 512 bit message blocks
  blocks = split(padded, 512)

  # 2. Hash Computation
  # -------------------
  # Set initial hash state using initial hash values
  hash = IV

  # For each message block
  blocks.each do |block|
    # Prepare 64 word message schedule
    schedule = calculate_schedule(block)

    # Remember starting hash values
    initial = hash.clone

    # Apply compression function to update hash values
    hash = compression(initial, schedule, constants = K)
  end

  # 3. Result
  # ---------
  # Convert hash values to hexadecimal and concatenate
  return hash.map { |w| w.to_s(16).rjust(8, '0') }.join
end

# Secret Key can be anything but must be consistent between this script and the frontend
SECRET_KEY="thisisyoursupersecreykeystring"

# Example
#
# Within a Shopify liquid template, use the sha256 string filter
# (https://shopify.dev/docs/themes/liquid/reference/filters/string-filters#sha256)
# to generate the SHA256 hash, being sure to include the SECRET_KEY as part
# of the data.  The SECRET_KEY can be defined in the liquid template using {% assign %}
# to prevent it from being exposed.
#
# Pass the generated hash as a product line item property (such as '_product_integrity')
# so that it can be read by this Shopify script, and validate it using the same format used
# to generate the hash on the frontend, passed to sha256() within this script.
#
# Therefore, if your hash from the frontend contains the variant ID, the secret key, and
# the product price, the Shopify Script should check using something similar to:
#
# Input.cart.line_items.each do |line_item|
#   SHA_HASH = sha256(line_item.variant.id.to_s + SECRET_KEY + line_item.final_price.to_s)
#   if SHA_HASH == line_item.properties['_product_integrity']
#     ...Integrity verified, do something
#   end
# end
#
# Output.cart = Input.cart
