# API

```text
SHA1~new(data)~digest
SHA1~update(data)
AuthHMAC~sha1(keyBytes, message)
AuthHMAC~sha256(keyBytes, message)
AuthHMAC~sha512(keyBytes, message)
```

This is a narrow companion extension intended to merge into the main Crypto authority; it is not a new general cryptography stack.
