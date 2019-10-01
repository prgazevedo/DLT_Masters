



# This is the repository for PKI configuration and certificates
Note: passwords to test the PKI are
 -  CA: ifap
 -  Intermediate CA: mirandesa
 -  producer CA: agrogranjo
## Introduction to commands


## Configuration files
-  [CA openssl.cnf](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/openssl.cnf)
-  [x509v3.cnf](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/intermediate/x509v3.cnf)
-  [Producer.cnf](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/intermediate/producer/Producer.cnf)

## Certificate files
-  [ca.cert.pem](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/certs/ca.cert.pem)
-  [ca-chain.cert.pem](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/intermediate/certs/ca-chain.cert.pem)
-  [intermediate.cert.pem](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/intermediate/certs/intermediate.cert.pem)
-  [newProduct.cert.pem](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/intermediate/products/productCerts/newProduct.cert.pem)
## CSR files
-  [intermediate.csr.pem](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/intermediate/csr/intermediate.csr.pem)
-  [newProduct.csr.pem](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/intermediate/products/newProduct.csr.pem)
## Key files
-  [ca.key.pem](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/private/ca.key.pem)
-  [intermediate.key.pem](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/intermediate/private/intermediate.key.pem)
-  [Supplier.key.pem](https://github.com/prgazevedo/DLT_Masters/blob/master/Certificates/OpenSSL/root/ca/intermediate/producer/private/Supplier.key.pem)
---
## References
-  [PKI certificate chain](https://jamielinux.com/docs/openssl-certificate-authority/create-the-root-pair.html)
-  [Verify certificate chain](https://stackoverflow.com/questions/25482199/verify-a-certificate-chain-using-openssl-verify)
-  [Copy X509 extensions](https://stackoverflow.com/questions/33989190/subject-alternative-name-is-not-copied-to-signed-certificate)
-  [Get subjectaltName into certificate -1 ](https://www.linuxquestions.org/questions/linux-software-2/get-subjectaltname-into-certificate-my-own-ca-4175479553/)
-  [Get subjectaltName into certificate -2 ](https://lists.debian.org/debian-user-german/2012/02/msg00788.html)
-  [Openssl ca versus x509](https://stackoverflow.com/questions/48672935/openssl-ca-vs-openssl-x509-the-openssl-ca-command-doesnt-register-the-same-on)
-  [Create a Microsoft OID](https://gallery.technet.microsoft.com/scriptcenter/56b78004-40d0-41cf-b95e-6e795b2e8a06#content)
-  [Obtain a "sub" OID](https://ldapwiki.com/wiki/How%20To%20Get%20Your%20Own%20OID)
-  [Search OID](http://oid-info.com/basic-search.htm)
-  [Reading an “otherName” value from a “subjectAltName” certificate extension](https://stackoverflow.com/questions/22966461/reading-an-othername-value-from-a-subjectaltname-certificate-extension)
-  [Internet X.509 Public Key Infrastructure - Permanent IdentifierRFC4043](https://tools.ietf.org/html/rfc4043)
-  [otherName unsupported](https://archive.is/KZYqh)
-  [OpenSSL man pages](https://www.openssl.org/docs/man1.1.1/man1/req.html)
