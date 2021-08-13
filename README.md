# Shopify Scripts Editor SHA256

This is an implementation of the SHA256 algorithm which functions within the limitations of Shopify Scripts.
It is useful for MAC validation of data that was added to the cart (such as line item properties) via JavaScript
to ensure that it was not manipulated by the customer.

NOTE: This may be used as the basis of a HMAC implementation which would use the Liquid `hmac_sha256` function to
generate the authenticator; however, the description below is only of a secret-suffix MAC. While significantly
better than trusting completely unauthenticated user-modifiable data and may be sufficient for a given risk profile,
there are [weaknesses](https://crypto.stackexchange.com/questions/5725/why-is-hmk-insecure) to be aware
of with this approach versus the standardized HMAC algorithm.

## Usage

1. Create a random string of characters to use as a shared secret. This shared secret will be used by the Liquid
rendering code and the Shopify Script but must never be output to the browser.

2. Within a Shopify template, use the `sha256` [Liquid string filter](https://shopify.dev/docs/themes/liquid/reference/filters/string-filters#sha256)
to generate a SHA256 hash of the sensitive data with the key concatenated to the end. (The example below assumes
the data to authenticate has been assigned to a Liquid variable `data_to_authenticate` and the shared secret has
been assigned to a variable `SECRET_KEY`.)

```liquid
    {% capture combined_data %}{{ data_to_authenticate }}{{ SECRET_KEY }}{% endcapture %}
    {% assign mac = combined_data | sha256 %}
```

3. Pass the resulting generated hash as a product line item property within the Add to Cart form so that it
can be read by the Shopify Script when checkout is initiated. Note that the data to authenticate must also be
available to the Shopify Script, whether as a line item property or otherwise. This can be passed in clear text,
since the MAC will authenticate it has not been manipulated.

4. Within the Shopify Script, include the contents of the `sha256.rb` file from this repository. Then, after this,
include in your own logic a check that the hash sent in the cart object matches a hash of the data and shared
secret you generate with the provided `sha256()` function. An example snippet is below, assuming that the data
that had been in the Liquid variable `data_to_authenticate` has been passed in the line item property `_data`,
the generated MAC has been passed in the line item property `_hash`, and the shared secret is hard-coded into
the script in a constant `SECRET_KEY`:

```ruby
 Input.cart.line_items.each do |line_item|
   SHA_HASH = sha256(line_item.properties['_data'] + SECRET_KEY)
   if SHA_HASH == line_item.properties['_mac_hash']
     # Integrity verified, do something
   end
 end
```
