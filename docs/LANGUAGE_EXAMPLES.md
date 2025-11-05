# Language-Specific Examples

Complete examples for configuring SSL certificates across different programming languages and frameworks.

---

## Table of Contents

- [Python](#python)
- [Node.js](#nodejs)
- [Java](#java)
- [Go](#go)
- [Ruby](#ruby)
- [PHP](#php)
- [.NET/C#](#netc)
- [Rust](#rust)

---

## Python

### Using Environment Variables (Recommended)

```dockerfile
FROM python:3.11-slim

# Copy certificate
COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN update-ca-certificates

# Set environment variables
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Install packages
RUN pip install requests google-generativeai boto3
```

### In Code (requests library)

```python
import requests
import os

# Set certificate path
os.environ['REQUESTS_CA_BUNDLE'] = '/etc/ssl/certs/netskope.pem'

# Or per-request
response = requests.get(
    'https://api.example.com',
    verify='/etc/ssl/certs/netskope.pem'
)
```

### In Code (urllib)

```python
import ssl
import urllib.request

context = ssl.create_default_context(
    cafile='/etc/ssl/certs/netskope.pem'
)

request = urllib.request.Request('https://api.example.com')
response = urllib.request.urlopen(request, context=context)
```

### Google Cloud SDK

```python
import os
os.environ['SSL_CERT_FILE'] = '/etc/ssl/certs/netskope.pem'

from google.cloud import storage
client = storage.Client()
```

### AWS Boto3

```python
import boto3
import os

os.environ['AWS_CA_BUNDLE'] = '/etc/ssl/certs/netskope.pem'

s3 = boto3.client('s3')
```

---

## Node.js

### Using Environment Variable

```dockerfile
FROM node:18-slim

COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    update-ca-certificates

ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Install packages
COPY package.json .
RUN npm install
```

### In Code (axios)

```javascript
const axios = require('axios');
const https = require('https');
const fs = require('fs');

const httpsAgent = new https.Agent({
  ca: fs.readFileSync('/etc/ssl/certs/netskope.pem')
});

axios.get('https://api.example.com', { httpsAgent });
```

### In Code (node-fetch)

```javascript
const fetch = require('node-fetch');
const https = require('https');
const fs = require('fs');

const agent = new https.Agent({
  ca: fs.readFileSync('/etc/ssl/certs/netskope.pem')
});

fetch('https://api.example.com', { agent });
```

---

## Java

### Dockerfile

```dockerfile
FROM openjdk:17-slim

COPY nscacert_combined.pem /tmp/netskope.crt

# Import certificate into Java keystore
RUN keytool -import \
    -trustcacerts \
    -alias netskope \
    -file /tmp/netskope.crt \
    -keystore $JAVA_HOME/lib/security/cacerts \
    -storepass changeit \
    -noprompt && \
    rm /tmp/netskope.crt

COPY target/app.jar app.jar
CMD ["java", "-jar", "app.jar"]
```

### Using System Property

```java
System.setProperty("javax.net.ssl.trustStore",
    "/path/to/truststore.jks");
System.setProperty("javax.net.ssl.trustStorePassword",
    "changeit");
```

### Maven (pom.xml)

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-surefire-plugin</artifactId>
  <configuration>
    <systemPropertyVariables>
      <javax.net.ssl.trustStore>
        /etc/ssl/certs/cacerts
      </javax.net.ssl.trustStore>
    </systemPropertyVariables>
  </configuration>
</plugin>
```

---

## Go

### Using Environment Variable

```dockerfile
FROM golang:1.21-alpine

COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN update-ca-certificates

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_DIR=/etc/ssl/certs

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o app
CMD ["./app"]
```

### In Code

```go
package main

import (
    "crypto/tls"
    "crypto/x509"
    "io/ioutil"
    "net/http"
)

func main() {
    cert, _ := ioutil.ReadFile("/etc/ssl/certs/netskope.pem")
    certPool := x509.NewCertPool()
    certPool.AppendCertsFromPEM(cert)

    client := &http.Client{
        Transport: &http.Transport{
            TLSClientConfig: &tls.Config{
                RootCAs: certPool,
            },
        },
    }

    resp, _ := client.Get("https://api.example.com")
}
```

---

## Ruby

### Using Environment Variable

```dockerfile
FROM ruby:3.2-slim

COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    update-ca-certificates

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
CMD ["ruby", "app.rb"]
```

### In Code

```ruby
require 'net/http'
require 'openssl'

uri = URI('https://api.example.com')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.ca_file = '/etc/ssl/certs/netskope.pem'
http.verify_mode = OpenSSL::SSL::VERIFY_PEER

response = http.get('/')
```

---

## PHP

### Dockerfile

```dockerfile
FROM php:8.2-apache

COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    update-ca-certificates

# Update php.ini
RUN echo "curl.cainfo=/etc/ssl/certs/ca-certificates.crt" >> /usr/local/etc/php/php.ini && \
    echo "openssl.cafile=/etc/ssl/certs/ca-certificates.crt" >> /usr/local/etc/php/php.ini

COPY . /var/www/html/
```

### In Code (cURL)

```php
<?php
$ch = curl_init('https://api.example.com');
curl_setopt($ch, CURLOPT_CAINFO, '/etc/ssl/certs/netskope.pem');
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
$response = curl_exec($ch);
curl_close($ch);
?>
```

### In Code (Guzzle)

```php
<?php
use GuzzleHttp\Client;

$client = new Client([
    'verify' => '/etc/ssl/certs/netskope.pem'
]);

$response = $client->request('GET', 'https://api.example.com');
?>
```

---

## .NET/C#

### Dockerfile

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:7.0

COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    update-ca-certificates

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

COPY bin/Release/net7.0/publish/ app/
WORKDIR /app
ENTRYPOINT ["dotnet", "YourApp.dll"]
```

### In Code (HttpClient)

```csharp
using System.Net.Http;
using System.Security.Cryptography.X509Certificates;

var handler = new HttpClientHandler();
handler.ServerCertificateCustomValidationCallback =
    HttpClientHandler.DangerousAcceptAnyServerCertificateValidator;

// Or load certificate
var cert = new X509Certificate2("/etc/ssl/certs/netskope.pem");
handler.ClientCertificates.Add(cert);

var client = new HttpClient(handler);
var response = await client.GetAsync("https://api.example.com");
```

---

## Rust

### Dockerfile

```dockerfile
FROM rust:1.70-slim

COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    update-ca-certificates

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

COPY Cargo.toml Cargo.lock ./
RUN cargo build --release

COPY . .
CMD ["./target/release/app"]
```

### In Code (reqwest)

```rust
use reqwest;
use std::fs;

#[tokio::main]
async fn main() {
    let cert = fs::read("/etc/ssl/certs/netskope.pem").unwrap();
    let cert = reqwest::Certificate::from_pem(&cert).unwrap();

    let client = reqwest::Client::builder()
        .add_root_certificate(cert)
        .build()
        .unwrap();

    let response = client.get("https://api.example.com")
        .send()
        .await
        .unwrap();
}
```

---

## Common Patterns

### Multi-stage Build

```dockerfile
# Build stage
FROM node:18 AS builder
COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN update-ca-certificates
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
RUN npm install

# Runtime stage
FROM node:18-slim
COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN update-ca-certificates
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/index.js"]
```

### Alpine Linux

```dockerfile
FROM python:3.11-alpine

# Alpine uses different path
COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN apk --no-cache add ca-certificates && \
    update-ca-certificates

ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
```

---

## Testing Your Configuration

### Generic Test Script

```bash
# Test with curl
docker run --rm your-image curl -v https://api.example.com

# Test with openssl
docker run --rm your-image openssl s_client -connect api.example.com:443 -showcerts

# Test certificate verification
docker run --rm your-image openssl verify /etc/ssl/certs/netskope.pem
```

### Language-Specific Tests

```bash
# Python
docker run --rm your-image python -c "import requests; print(requests.get('https://api.example.com').status_code)"

# Node.js
docker run --rm your-image node -e "require('https').get('https://api.example.com', r => console.log(r.statusCode))"

# Go
docker run --rm your-image go run -exec "curl https://api.example.com"
```

---

## Related Documentation

- [Main README](../README.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [FAQ](FAQ.md)

---

**Don't see your language?** [Open an issue](https://github.com/myhelix/docker-netskope-ssl-fix/issues) or submit a PR!
