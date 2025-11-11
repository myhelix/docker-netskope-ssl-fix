# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a documentation and example repository demonstrating how to fix SSL certificate verification issues in **both Docker containers and host machine tools** when behind Netskope SSL inspection. It's not a runtime application or library - it's educational content with working examples.

## Core Architecture

The repository demonstrates solutions for two different environments:

### Docker Container Solutions

Two main solution patterns for containers:

1. **Baked Certificate Approach** (`examples/Dockerfile.fixed`)
   - Certificate copied into image at build time
   - System CA certificates updated with `update-ca-certificates`
   - Environment variables set to point to system certificate store
   - Best for production deployments

2. **Runtime Mount Approach** (`examples/docker-compose.yml`)
   - Certificate mounted as volume at runtime
   - Environment variables point directly to mounted certificate
   - Best for local development

**Key technical insight:** Netskope intercepts HTTPS traffic and replaces SSL certificates. Docker containers don't trust Netskope's certificate by default, causing SSL verification failures. The fix involves installing Netskope's certificate into the container's trusted CA store.

### Host Machine Solutions

For tools running on the host (macOS/Linux):
- **Environment Variable Approach** (`setup-host-environment.sh`)
  - Configure shell to set certificate paths via environment variables
  - Works for Node.js (Claude Code, npm), Python (pip), Git, curl, AWS CLI, etc.
  - Set via `NODE_EXTRA_CA_CERTS`, `SSL_CERT_FILE`, `GIT_SSL_CAINFO`, etc.
  - Best for development machines

- **System Keychain Approach** (macOS)
  - Import certificate into system keychain and mark as trusted
  - System-wide trust but some tools still need environment variables
  - Good for graphical applications

## Important File Locations

- **Helix Netskope certificate (included):** `nscacert_combined.pem` (in repository root)
- **Certificate source on macOS:** `/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem`
- **Container certificate destination:** `/usr/local/share/ca-certificates/netskope.crt`
- **System CA bundle (after update):** `/etc/ssl/certs/ca-certificates.crt`

## Testing Commands

### Docker Testing
```bash
# Quick automated test (recommended)
./test-setup.sh

# Manual testing
cd examples
docker build -t netskope-test -f Dockerfile .
docker run --rm netskope-test

# Test the fixed scenario (baked certificate)
docker build -t netskope-test-fixed -f Dockerfile.fixed .
docker run --rm netskope-test-fixed

# Test with docker-compose (runtime mount)
docker-compose up
```

### gRPC/HTTP/2 ALPN Testing
```bash
# Test for HTTP/2 ALPN stripping (gRPC issue detection)
python3 newtest.py
```

**What it tests:**
- HTTPS connectivity (certificate trust)
- HTTP/2 ALPN negotiation (gRPC compatibility)
- Google APIs: Custom Search, Gemini AI, Fonts

**Key insight:** If HTTPS passes but HTTP/2 ALPN fails, Netskope is stripping ALPN protocol negotiation. This breaks gRPC even when certificates are properly trusted. Solution: IT must add bypass rules.

**Reference:** ST-2806 - Real-world case where `*.googleapis.com` bypass was required for gRPC connectivity.

### Host Machine Setup
```bash
# Automated setup (recommended)
./setup-host-environment.sh

# Manual verification
echo $NODE_EXTRA_CA_CERTS
curl https://api.github.com
```

## Updating Certificate

When Netskope rotates their certificate:

```bash
./update-certificate.sh  # Automatically updates from system location
./test-setup.sh          # Verify everything still works
```

## Critical Environment Variables by Language

- **Python:** `REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`, `CURL_CA_BUNDLE`
- **Node.js:** `NODE_EXTRA_CA_CERTS`
- **Go:** `SSL_CERT_FILE`, `SSL_CERT_DIR`
- **Ruby:** `SSL_CERT_FILE`
- **AWS SDK:** `AWS_CA_BUNDLE`

## Docker Image Patterns

All examples follow this pattern:
1. Copy certificate into image
2. Install `ca-certificates` package (if not present)
3. Run `update-ca-certificates` to merge into system bundle
4. Set language-specific environment variables
5. Install dependencies (will now trust Netskope-intercepted connections)

**Alpine Linux variation:** Uses `apk add ca-certificates` instead of `apt-get`

**Java variation:** Requires `keytool` to import into Java keystore at `$JAVA_HOME/lib/security/cacerts`

## Repository Organization

- `examples/` - Working Dockerfiles and test scripts demonstrating the issue and solution
- `docs/` - Detailed guides for IT requests, language-specific configurations, troubleshooting
  - `HOST_MACHINE_SETUP.md` - Configure host machine tools (Claude Code, npm, pip, git)
  - `LANGUAGE_EXAMPLES.md` - Language-specific Docker examples
  - `IT_REQUEST_TEMPLATE.md` - Template for requesting IT bypass
  - `TROUBLESHOOTING.md` - Common issues and fixes (including gRPC/HTTP/2 ALPN issues)
- Root README.md - Main user-facing documentation with quick start
- `setup-host-environment.sh` - Automated host machine configuration script
- `newtest.py` - **New:** gRPC/HTTP/2 ALPN diagnostic tool - tests both HTTPS and HTTP/2 negotiation to detect ALPN stripping

## Common Issues

### gRPC/HTTP/2 Connection Failures (Even With Certificate Trust)
- **Symptom:** gRPC connections fail despite SSL certificate being trusted; HTTPS works but gRPC doesn't
- **Root Cause:** Netskope strips ALPN (Application Layer Protocol Negotiation) from TLS handshake, preventing HTTP/2 negotiation
- **Diagnostic:** Run `python3 newtest.py` - if HTTPS passes but HTTP/2 ALPN fails (returns `None` instead of `"h2"`), this is the issue
- **Solution:** Request IT to add bypass rules for affected domains (e.g., `*.googleapis.com`)
- **IMPORTANT:** Certificate installation CANNOT fix this; bypass is the only solution
- **Details:** `docs/TROUBLESHOOTING.md` (gRPC and HTTP/2 Failures section)
- **Reference:** ST-2806

### Claude Code MCP Server Connection Failures
- **Symptom:** "SSL certificate verification failed" when connecting to MCP servers
- **Solution:** Run `./setup-host-environment.sh` or manually set `NODE_EXTRA_CA_CERTS`
- **Verify:** Restart Claude Code completely (quit and relaunch)
- **Details:** `docs/HOST_MACHINE_SETUP.md`

### npm/yarn Installation Failures on Host
- **Symptom:** SSL errors during `npm install` outside Docker
- **Solution:** Set `NODE_EXTRA_CA_CERTS` environment variable
- **Alternative:** `npm config set cafile "/path/to/nscacert_combined.pem"`

### pip Installation Failures on Host
- **Symptom:** SSL errors during `pip install` outside Docker
- **Solution:** Set `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` environment variables
- **Alternative:** `pip config set global.cert "/path/to/nscacert_combined.pem"`

## When Contributing

Per CONTRIBUTING.md, focus on:
- Additional language examples (Python, Node, Java, Go, Ruby, PHP, .NET, Rust are covered)
- CI/CD pipeline examples for different platforms
- Platform-specific variations (Windows, Linux)
- Alternative SSL inspection tools (Zscaler, Palo Alto Networks)
- Host machine setup for Windows (currently macOS/Linux only)

**Security note:** Never commit actual certificate files, API keys, or credentials to the repository.
