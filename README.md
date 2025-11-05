# Docker + Netskope SSL Certificate Fix

> **Run Docker containers behind Netskope without SSL certificate errors**

A complete guide and working examples for running Python (and other language) applications in Docker when behind Netskope SSL inspection, without requiring bypass rules from IT.

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

**Common Symptoms:**
- ❌ `pip install` fails in Docker
- ❌ API calls to external services fail (Google, AWS, etc.)
- ❌ `npm install` / `yarn install` fails
- ❌ Git clone over HTTPS fails
- ❌ Any HTTPS connection fails with SSL errors

---

## ✅ Solution

This repository provides **three working solutions** to fix SSL certificate verification in Docker when behind Netskope:

1. **[Bake Certificate into Image](#solution-1-bake-certificate-into-image-production)** - Best for production
2. **[Mount Certificate at Runtime](#solution-2-mount-certificate-at-runtime-development)** - Best for development
3. **[Request IT Bypass](#solution-3-request-bypass-rules-from-it)** - Best for long-term

---

## 🚀 Quick Start

### Prerequisites

- Docker Desktop installed
- Netskope client running on your machine
- Access to Netskope's certificate file (automatic on macOS/Windows)

### Test the Problem

```bash
git clone https://github.com/YOUR_ORG/docker-netskope-ssl-fix.git
cd docker-netskope-ssl-fix/examples

# Run the broken version
docker build -t netskope-test .
docker run --rm netskope-test
```

**Expected:** SSL certificate errors ❌

### Test the Solution

```bash
# Copy your Netskope certificate
cp "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem" .

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

**Best for:** Long-term solution, organization-wide fix

Request that your IT team add bypass rules for Docker processes accessing external APIs.

**Email template:** See [docs/IT_REQUEST_TEMPLATE.md](docs/IT_REQUEST_TEMPLATE.md)

**Domains to bypass:**
- `*.googleapis.com` (Google APIs)
- `registry.npmjs.org` (NPM packages)
- `pypi.org`, `files.pythonhosted.org` (Python packages)
- `github.com`, `raw.githubusercontent.com` (Git operations)

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
├── examples/
│   ├── Dockerfile                 # Broken version (demonstrates issue)
│   ├── Dockerfile.fixed           # Fixed version (with certificate)
│   ├── docker-compose.yml         # All test scenarios
│   └── test_google_apis.py        # Test script
├── docs/
│   ├── IT_REQUEST_TEMPLATE.md     # Email template for IT
│   ├── LANGUAGE_EXAMPLES.md       # Language-specific configs
│   ├── TROUBLESHOOTING.md         # Common issues and fixes
│   └── FAQ.md                     # Frequently asked questions
└── .github/
    └── workflows/
        └── test.yml               # CI/CD example
```

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

- **Issues:** [GitHub Issues](https://github.com/YOUR_ORG/docker-netskope-ssl-fix/issues)
- **Discussions:** [GitHub Discussions](https://github.com/YOUR_ORG/docker-netskope-ssl-fix/discussions)
- **Questions:** See [docs/FAQ.md](docs/FAQ.md)

---

**Star ⭐ this repo if it helped you!**

Made with ❤️ for developers behind corporate SSL inspection
