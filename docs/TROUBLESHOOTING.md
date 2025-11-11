# Troubleshooting Guide

Common issues and solutions when working with Docker and Netskope SSL inspection.

---

## Table of Contents

- [SSL Certificate Errors](#ssl-certificate-errors)
- [gRPC and HTTP/2 Failures](#grpc-and-http2-failures)
- [Certificate Installation Issues](#certificate-installation-issues)
- [Environment Variable Issues](#environment-variable-issues)
- [Host Machine Issues](#host-machine-issues)

---

## SSL Certificate Errors

### Problem: SSL CERTIFICATE_VERIFY_FAILED

```
[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed:
self-signed certificate in certificate chain
```

**Diagnosis:**
- Container doesn't trust Netskope's certificate
- Certificate not properly installed in container

**Solutions:**

1. **Verify certificate is in container:**
   ```bash
   docker run --rm your-image ls -la /usr/local/share/ca-certificates/netskope.crt
   ```

2. **Check if ca-certificates was updated:**
   ```bash
   docker run --rm your-image grep -i netskope /etc/ssl/certs/ca-certificates.crt
   ```

3. **Verify environment variables:**
   ```bash
   docker run --rm your-image env | grep -E "(SSL_CERT|REQUESTS_CA|NODE_EXTRA)"
   ```

4. **Test certificate manually:**
   ```bash
   docker run --rm your-image openssl verify /usr/local/share/ca-certificates/netskope.crt
   ```

**Fix:**
- Follow the [baked certificate solution](../README.md#solution-1-bake-certificate-into-image-production) in the README
- Ensure `update-ca-certificates` was run in the Dockerfile
- Set appropriate environment variables for your language

---

## gRPC and HTTP/2 Failures

### Problem: gRPC Connections Fail Despite Valid SSL Certificate

```
grpc._channel._InactiveRpcError: UNAVAILABLE: failed to connect to all addresses
```

OR

```
HTTP/2 ALPN negotiation failed
Selected ALPN protocol: None (expected: h2)
```

**Diagnosis:**
Netskope is stripping the ALPN (Application Layer Protocol Negotiation) extension from TLS handshakes. This prevents HTTP/2 negotiation, which breaks gRPC.

**Key Insight:**
- ✅ Regular HTTPS (HTTP/1.1) works fine
- ✅ SSL certificate is trusted
- ❌ HTTP/2 protocol negotiation fails
- ❌ gRPC fails (requires HTTP/2)

### Testing for HTTP/2 ALPN Issues

Run the diagnostic script:

```bash
python3 newtest.py
```

**Example output showing the problem:**

```
✅ PASS - Google Gemini API (HTTPS)
❌ FAIL - Google Gemini API (HTTP/2 ALPN)
  Selected ALPN protocol: None  # Should be "h2"
```

This confirms:
1. SSL certificate trust is working (HTTPS passes)
2. HTTP/2 ALPN negotiation is being blocked (ALPN fails)
3. gRPC will not work

### Solution: Request IT Bypass

**Installing the certificate CANNOT fix this issue.** The only solution is to bypass SSL inspection for the affected domains.

**Affected Services:**
- Google AI APIs (`*.googleapis.com`)
- Any service using gRPC
- Any API requiring HTTP/2

**Steps:**

1. **Identify the domains** that need bypass:
   ```bash
   # Run the test script to see which domains fail
   python3 newtest.py
   ```

2. **Request IT to add bypass rules** for:
   - `*.googleapis.com` (Google APIs)
   - `generativelanguage.googleapis.com` (Gemini AI)
   - `customsearch.googleapis.com` (Google Custom Search)
   - Any other domains showing HTTP/2 ALPN failures

3. **Verify the bypass is working:**
   ```bash
   python3 newtest.py
   ```

   Expected after bypass:
   ```
   ✅ PASS - Google Gemini API (HTTPS)
   ✅ PASS - Google Gemini API (HTTP/2 ALPN)
     Selected ALPN protocol: h2  # ✅ Success!
   ```

**Reference:** See [ST-2806](https://myhelix.atlassian.net/browse/ST-2806) for a real-world example where this was successfully resolved.

### Why Certificate Installation Doesn't Fix This

```
Certificate Fix:         Fixes SSL trust issues
                        ✅ Container trusts Netskope's certificate
                        ✅ HTTPS connections work
                        ❌ Does NOT fix ALPN stripping

Bypass Rules:           Prevents SSL inspection entirely
                        ✅ Direct connection to service
                        ✅ No certificate trust issues
                        ✅ HTTP/2 ALPN works
                        ✅ gRPC works
```

---

## Certificate Installation Issues

### Problem: Certificate Not Found After Build

**Symptoms:**
```bash
docker run --rm your-image ls /usr/local/share/ca-certificates/netskope.crt
# ls: cannot access '/usr/local/share/ca-certificates/netskope.crt': No such file or directory
```

**Causes:**
1. Certificate file not in build context
2. COPY command failed silently
3. Wrong file path in Dockerfile

**Solutions:**

1. **Verify certificate exists locally:**
   ```bash
   ls -la nscacert_combined.pem
   ```

2. **Check Dockerfile COPY statement:**
   ```dockerfile
   # Ensure this matches your file name
   COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
   ```

3. **Rebuild with build output:**
   ```bash
   docker build --progress=plain -t your-image .
   ```

---

## Environment Variable Issues

### Problem: Environment Variables Not Set

**Test:**
```bash
docker run --rm your-image env | grep CERT
# (no output)
```

**Solution:**

Add to your Dockerfile:
```dockerfile
# For Python
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# For Node.js
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# For Go
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

OR set at runtime:
```bash
docker run -e SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt your-image
```

---

## Host Machine Issues

### Problem: Claude Code, npm, pip, git Fail with SSL Errors

**Symptoms:**
- Claude Code cannot connect to MCP servers
- `npm install` fails
- `pip install` fails
- Git operations fail

**Solution:**

See the [Host Machine Setup Guide](HOST_MACHINE_SETUP.md) for detailed instructions.

**Quick fix:**
```bash
# Run the setup script
./setup-host-environment.sh

# Or manually set environment variables
export NODE_EXTRA_CA_CERTS="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
export SSL_CERT_FILE="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

---

## Alpine Linux Issues

### Problem: update-ca-certificates Doesn't Work on Alpine

**Symptoms:**
```
/bin/sh: update-ca-certificates: not found
```

**Solution:**

Alpine uses different commands:
```dockerfile
# Install ca-certificates package
RUN apk add --no-cache ca-certificates

# Copy certificate
COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt

# Update certificates
RUN update-ca-certificates
```

---

## Docker Compose Volume Mount Issues

### Problem: Volume Mount Fails

**Symptoms:**
```
Error response from daemon: invalid mount config for type "bind":
bind source path does not exist
```

**Solution:**

1. **Verify certificate exists on host:**
   ```bash
   ls -la "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
   ```

2. **Use absolute paths in docker-compose.yml:**
   ```yaml
   volumes:
     - /Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem:/etc/ssl/certs/netskope.pem:ro
   ```

3. **Or use the bundled certificate:**
   ```yaml
   volumes:
     - ./nscacert_combined.pem:/etc/ssl/certs/netskope.pem:ro
   ```

---

## Still Having Issues?

1. **Run the test script:**
   ```bash
   ./test-setup.sh        # For Docker
   python3 newtest.py     # For gRPC/HTTP/2
   ```

2. **Check the logs:**
   ```bash
   docker logs your-container
   ```

3. **Open an issue:** [GitHub Issues](https://github.com/myhelix/docker-netskope-ssl-fix/issues)

4. **Review related docs:**
   - [Host Machine Setup](HOST_MACHINE_SETUP.md)
   - [Language Examples](LANGUAGE_EXAMPLES.md)
   - [IT Request Template](IT_REQUEST_TEMPLATE.md)

---

## Common Patterns That Work

### Pattern 1: Baked Certificate (Production)

```dockerfile
FROM python:3.11-slim

# Install certificates package
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy and install Netskope certificate
COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN update-ca-certificates

# Set environment variables
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# Your app code
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
```

### Pattern 2: Runtime Mount (Development)

```yaml
version: '3.8'
services:
  app:
    build: .
    volumes:
      - /Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem:/etc/ssl/certs/netskope.pem:ro
    environment:
      - SSL_CERT_FILE=/etc/ssl/certs/netskope.pem
      - REQUESTS_CA_BUNDLE=/etc/ssl/certs/netskope.pem
```

---

**Remember:** If you're experiencing gRPC or HTTP/2 failures, certificate installation alone won't help. You need bypass rules from IT.
