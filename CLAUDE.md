# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a documentation and example repository demonstrating how to fix SSL certificate verification issues in Docker containers when behind Netskope SSL inspection. It's not a runtime application or library - it's educational content with working examples.

## Core Architecture

The repository demonstrates two main solution patterns:

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

## Important File Locations

- **Helix Netskope certificate (included):** `nscacert_combined.pem` (in repository root)
- **Certificate source on macOS:** `/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem`
- **Container certificate destination:** `/usr/local/share/ca-certificates/netskope.crt`
- **System CA bundle (after update):** `/etc/ssl/certs/ca-certificates.crt`

## Testing Commands

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
- Root README.md - Main user-facing documentation with quick start

## When Contributing

Per CONTRIBUTING.md, focus on:
- Additional language examples (Python, Node, Java, Go, Ruby, PHP, .NET, Rust are covered)
- CI/CD pipeline examples for different platforms
- Platform-specific variations (Windows, Linux)
- Alternative SSL inspection tools (Zscaler, Palo Alto Networks)

**Security note:** Never commit actual certificate files, API keys, or credentials to the repository.
