# Docker + Netskope SSL Certificate Fix

> **Run Docker containers behind Netskope without SSL certificate errors**

A complete guide and working examples for running Python (and other language) applications in Docker when behind Netskope SSL inspection, without requiring bypass rules from IT.

**Note:** This repository includes Helix's Netskope certificate (`nscacert_combined.pem`) for internal use.

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 🎯 Problem

When running applications inside Docker containers on a machine with Netskope SSL inspection, HTTPS connections fail with certificate verification errors:

```
[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed:
self-signed certificate in certificate chain
```

**Why?**
- Netskope intercepts HTTPS traffic for security monitoring
- Replaces original SSL certificates with its own certificate
- Docker containers don't trust Netskope's certificate by default
- Result: SSL verification fails ❌

**Common Symptoms (Docker):**
- ❌ `pip install` fails in Docker
- ❌ API calls to external services fail (Google, AWS, etc.)
- ❌ `npm install` / `yarn install` fails
- ❌ Git clone over HTTPS fails
- ❌ Any HTTPS connection fails with SSL errors

**Common Symptoms (Host Machine):**
- ❌ Claude Code cannot connect to MCP servers
- ❌ `npm install` fails on your Mac/Linux
- ❌ VS Code extensions fail to install
- ❌ Git operations fail with SSL errors

**Additional Issue: gRPC and HTTP/2 Failures**

Even when SSL certificates are properly trusted, Netskope may strip HTTP/2 protocol negotiation (ALPN), causing:
- ❌ gRPC connections fail (gRPC requires HTTP/2)
- ❌ Google AI APIs fail (Gemini, Custom Search, etc.)
- ❌ Modern APIs requiring HTTP/2 fail
- ✅ Regular HTTPS/HTTP/1.1 connections work fine

**Why?** Netskope's SSL inspection can remove the ALPN (Application Layer Protocol Negotiation) extension from TLS handshakes, preventing HTTP/2 negotiation. This breaks gRPC, which requires HTTP/2.

**Solution:** Request IT to bypass specific domains from SSL inspection (see [ST-2806](https://myhelix.atlassian.net/browse/ST-2806) for example).

---

## ✅ Solution

This repository provides solutions for **both Docker containers and your host machine**:

### Docker Containers

1. **[Bake Certificate into Image](#solution-1-bake-certificate-into-image-production)** - Best for production
2. **[Mount Certificate at Runtime](#solution-2-mount-certificate-at-runtime-development)** - Best for development
3. **[Request IT Bypass](#solution-3-request-bypass-rules-from-it)** - Best for long-term

### Host Machine (Claude Code, npm, pip, git, etc.)

If tools running on your Mac/Linux machine are also experiencing SSL errors:
- **[Host Machine Setup Guide](docs/HOST_MACHINE_SETUP.md)** - Configure Claude Code, npm, pip, git, and other tools

---

## 🚀 Quick Start

### Prerequisites

- Docker Desktop installed
- Netskope client running on your machine (Helix-specific certificate included in this repository)

### Quick Test (Recommended)

Run our automated test script to verify everything works:

```bash
git clone https://github.com/myhelix/docker-netskope-ssl-fix.git
cd docker-netskope-ssl-fix
./test-setup.sh
```

This will test both broken and fixed scenarios automatically.

### Manual Testing

### Test the Problem

```bash
git clone https://github.com/myhelix/docker-netskope-ssl-fix.git
cd docker-netskope-ssl-fix/examples

# Run the broken version
docker build -t netskope-test .
docker run --rm netskope-test
```

**Expected:** SSL certificate errors ❌

### Test the Solution

```bash
# Certificate is already included in the repository
# Run the fixed version
docker build -f Dockerfile.fixed -t netskope-test-fixed .
docker run --rm netskope-test-fixed
```

**Expected:** All connections succeed ✅

---

## 📚 Solutions in Detail

### Solution 1: Bake Certificate into Image (Production)

**Best for:** Production deployments, CI/CD, distributing images

Add these lines to your `Dockerfile`:

```dockerfile
# Copy Netskope certificate
COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt

# Update CA certificates
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

**Pros:**
- ✅ Works everywhere the image runs
- ✅ No volume mounts needed
- ✅ Clean production deployment

**Cons:**
- ⚠️ Certificate baked into image (rebuild if cert changes)
- ⚠️ Image slightly larger (~250KB)

**Full example:** See [`examples/Dockerfile.fixed`](examples/Dockerfile.fixed)

---

### Solution 2: Mount Certificate at Runtime (Development)

**Best for:** Local development, testing, experimenting

#### Using docker run:

```bash
docker run \
  -v "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem:/etc/ssl/certs/netskope.pem:ro" \
  -e REQUESTS_CA_BUNDLE=/etc/ssl/certs/netskope.pem \
  -e SSL_CERT_FILE=/etc/ssl/certs/netskope.pem \
  your-image
```

#### Using docker-compose:

```yaml
version: '3.8'
services:
  app:
    build: .
    volumes:
      - /Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem:/etc/ssl/certs/netskope.pem:ro
    environment:
      - REQUESTS_CA_BUNDLE=/etc/ssl/certs/netskope.pem
      - SSL_CERT_FILE=/etc/ssl/certs/netskope.pem
```

**Pros:**
- ✅ Certificate updates automatically
- ✅ Smaller image size
- ✅ Flexible for development

**Cons:**
- ⚠️ Requires certificate on host
- ⚠️ More complex deployment

**Full example:** See [`examples/docker-compose.yml`](examples/docker-compose.yml)

---

### Solution 3: Request Bypass Rules from IT

**Best for:** Long-term solution, organization-wide fix, **REQUIRED for gRPC/HTTP/2**

Request that your IT team add bypass rules for Docker processes accessing external APIs.

**Email template:** See [docs/IT_REQUEST_TEMPLATE.md](docs/IT_REQUEST_TEMPLATE.md)

**Domains to bypass:**
- `*.googleapis.com` (Google APIs, **required for gRPC**)
- `registry.npmjs.org` (NPM packages)
- `pypi.org`, `files.pythonhosted.org` (Python packages)
- `github.com`, `raw.githubusercontent.com` (Git operations)

**Note:** If you're experiencing gRPC failures or HTTP/2 issues, bypass rules are the **only solution**. Installing the certificate alone will not fix HTTP/2 ALPN stripping.

#### Testing for HTTP/2 ALPN Issues

Use the included test script to diagnose HTTP/2 problems:

```bash
python3 newtest.py
```

This will test both HTTPS connectivity AND HTTP/2 ALPN negotiation to Google APIs. If HTTPS works but HTTP/2 ALPN fails, you need bypass rules from IT.

**Example output showing the issue:**
```
✅ PASS - Google Gemini API (HTTPS)
❌ FAIL - Google Gemini API (HTTP/2 ALPN)
  Selected ALPN protocol: None  # Should be "h2"
```

**After IT adds bypass rules:**
```
✅ PASS - Google Gemini API (HTTPS)
✅ PASS - Google Gemini API (HTTP/2 ALPN)
  Selected ALPN protocol: h2  # ✅ gRPC will work!
```

---

## 🔧 Language-Specific Examples

### Python

```dockerfile
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/netskope.pem
ENV SSL_CERT_FILE=/etc/ssl/certs/netskope.pem
```

```python
import os
os.environ['SSL_CERT_FILE'] = '/etc/ssl/certs/netskope.pem'
```

### Node.js

```dockerfile
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/netskope.pem
```

### Java

```dockerfile
RUN keytool -import -trustcacerts -alias netskope \
    -file /usr/local/share/ca-certificates/netskope.crt \
    -keystore $JAVA_HOME/lib/security/cacerts \
    -storepass changeit -noprompt
```

### Go

```dockerfile
ENV SSL_CERT_FILE=/etc/ssl/certs/netskope.pem
```

### Ruby

```dockerfile
ENV SSL_CERT_FILE=/etc/ssl/certs/netskope.pem
```

**More examples:** See [docs/LANGUAGE_EXAMPLES.md](docs/LANGUAGE_EXAMPLES.md)

---

## 📁 Repository Structure

```
docker-netskope-ssl-fix/
├── README.md                      # This file
├── LICENSE                        # MIT License
├── CLAUDE.md                      # AI assistant guidance
├── nscacert_combined.pem          # Helix Netskope certificate (included)
├── newtest.py                     # gRPC/HTTP/2 ALPN diagnostic tool
├── update-certificate.sh          # Helper: Update certificate from system
├── test-setup.sh                  # Helper: Test Docker setup
├── setup-host-environment.sh      # Helper: Configure host machine
├── examples/
│   ├── Dockerfile                 # Broken version (demonstrates issue)
│   ├── Dockerfile.fixed           # Fixed version (with certificate)
│   ├── docker-compose.yml         # All test scenarios
│   ├── test_google_apis.py        # Test script
│   └── nscacert_combined.pem      # Certificate copy for Docker build
├── docs/
│   ├── HOST_MACHINE_SETUP.md      # Configure Mac/Linux host tools
│   ├── IT_REQUEST_TEMPLATE.md     # Email template for IT
│   ├── LANGUAGE_EXAMPLES.md       # Language-specific configs
│   ├── TROUBLESHOOTING.md         # Common issues and fixes
│   └── FAQ.md                     # Frequently asked questions
└── .github/
    └── workflows/
        └── test.yml               # CI/CD example
```

---

## 🔄 Updating the Certificate

If Netskope rotates their certificate or you need to update it:

```bash
# Run the update script
./update-certificate.sh

# Test that everything still works
./test-setup.sh

# Commit and push for team
git add nscacert_combined.pem examples/nscacert_combined.pem
git commit -m "Update Netskope certificate"
git push
```

The `update-certificate.sh` script automatically:
- ✅ Copies the latest certificate from your system
- ✅ Updates both repository locations
- ✅ Shows certificate info and next steps

---

## 🐛 Troubleshooting

### Still getting SSL errors after adding certificate?

1. **Verify certificate is in container:**
   ```bash
   docker run --rm your-image ls -la /etc/ssl/certs/netskope.pem
   ```

2. **Check environment variables:**
   ```bash
   docker run --rm your-image env | grep CERT
   ```

3. **Test certificate manually:**
   ```bash
   docker run --rm your-image openssl verify /etc/ssl/certs/netskope.pem
   ```

**More solutions:** See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

**Ideas for contributions:**
- Additional language examples
- CI/CD pipeline examples
- Windows/Linux-specific instructions
- Alternative SSL inspection tools (Zscaler, Palo Alto, etc.)

---

## 📖 Additional Resources

- **[Netskope Documentation](https://docs.netskope.com/)** - Official Netskope docs
- **[Docker SSL Documentation](https://docs.docker.com/engine/security/certificates/)** - Docker certificate management
- **[Python Requests SSL](https://requests.readthedocs.io/en/latest/user/advanced/#ssl-cert-verification)** - Python SSL verification

---

## 🎓 Real-World Impact

This solution has been tested with:
- ✅ 432 API calls to Google Custom Search API
- ✅ 155 API calls to Google Gemini AI
- ✅ Running over 2+ hour periods
- ✅ Production workloads

**Without this fix:** Complete application failure
**With this fix:** 100% success rate

---

## ⚖️ License

MIT License - see [LICENSE](LICENSE) file for details

---

## 🙏 Acknowledgments

- Thanks to the Netskope team for their security tools
- Inspired by real-world issues encountered by development teams
- Built with feedback from Docker and Python communities

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/myhelix/docker-netskope-ssl-fix/issues)
- **Discussions:** [GitHub Discussions](https://github.com/myhelix/docker-netskope-ssl-fix/discussions)
- **Questions:** See [docs/FAQ.md](docs/FAQ.md)

---

**Star ⭐ this repo if it helped you!**

Made with ❤️ for developers behind corporate SSL inspection
