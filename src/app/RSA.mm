#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#include <openssl/rsa.h>
#include <openssl/bn.h>

#import "app/RSA.h"
#import "app/Base64.h"

NSData *RSAEncrypt(NSData *text, NSString *publicKey, NSString *publicKeyExponent) {
  RSA *rsa;
  rsa = RSA_new();
  NSData *modules = publicKey.decodeBase64;
  NSData *exponent = publicKeyExponent.decodeBase64;
  rsa->n = BN_bin2bn((uint8_t *)modules.bytes, modules.length, NULL);
  rsa->e = BN_bin2bn((uint8_t *)exponent.bytes, exponent.length, NULL);
  size_t outLen = RSA_size(rsa);
  uint8_t *out = (uint8_t *)malloc(outLen);
  RSA_public_encrypt(text.length, (uint8_t *)text.bytes, out, rsa, RSA_PKCS1_OAEP_PADDING);
  RSA_free(rsa);
  return [NSData dataWithBytesNoCopy:out length:outLen];
}
