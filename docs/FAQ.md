# Frequently Asked Questions (FAQ)

Common questions about Docker + Netskope SSL certificate issues and this solution.

---

## General Questions

### Q: What is Netskope?

**A:** Netskope is a cloud-native security platform that provides SSL/TLS inspection for corporate networks. It intercepts HTTPS traffic to scan for threats, which can cause certificate verification issues in containers.

### Q: Why do I need this solution?

**A:** Docker containers don't automatically trust your organization's SSL inspection certificate. Without this fix, any HTTPS connection from a container will fail with certificate verification errors.

### Q: Will this solution work with other SSL inspection tools?

**A:** Yes! While this repo focuses on Netskope, the same approach works for:
- Zscaler
- Palo Alto Networks
- Cisco Umbrella
- BlueCoat/Symantec
- Any SSL/TLS inspection proxy

Just replace the Netskope certificate with your organization's certificate.

---

## Security Questions

### Q: Is it safe to trust my organization's SSL certificate?

**A:** Yes. You're already trusting it on your host machine. This solution simply extends that trust to Docker containers. Your organization's IT team manages and secures this certificate.

### Q: Should I commit the certificate to Git?

**A:** **Generally NO!** However, this repository is specific to Helix and includes our Netskope certificate for internal use.

**For this Helix repository:**
- ✅ Certificate is included (`nscacert_combined.pem`)
- ✅ Ready to use immediately
- ✅ Repository is internal to Helix

**General best practices (other projects):**
- ✅ Mount certificate at runtime (development)
- ✅ Copy certificate during build from secure location (production)
- ❌ Never commit certificate files to public repositories
- ❌ Never push images with certificates to public registries

### Q: What about certificate rotation?

**A:** When your organization rotates the certificate:

**For baked certificate approach:**
- Rebuild your images with the new certificate
- Use automated CI/CD to detect certificate changes

**For mounted certificate approach:**
- No action needed! Container uses host's certificate automatically

---

## Technical Questions

### Q: Which solution should I use: baked certificate or volume mount?

**A:**

| Use Case | Recommendation |
|----------|----------------|
| Local development | Volume mount |
| CI/CD pipelines | Baked certificate |
| Production deployment | Baked certificate |
| Quick testing | Volume mount |
| Distributing images | Baked certificate |

### Q: My Dockerfile uses a different base image. Will this work?

**A:** Yes! The solution works with any Linux-based Docker image. You may need to adjust package manager commands:

**Debian/Ubuntu:**
```dockerfile
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates
```

**Alpine:**
```dockerfile
RUN apk --no-cache add ca-certificates && update-ca-certificates
```

**Red Hat/CentOS:**
```dockerfile
RUN yum install -y ca-certificates && update-ca-trust
```

### Q: Does this work on Windows containers?

**A:** Yes, but with different paths. For Windows containers:

```dockerfile
COPY nscacert_combined.pem C:\certificates\netskope.crt
RUN certutil -addstore -f "ROOT" C:\certificates\netskope.crt
```

### Q: What about multi-stage builds?

**A:** Add the certificate to BOTH stages:

```dockerfile
# Build stage
FROM node:18 AS builder
COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN update-ca-certificates
...

# Runtime stage
FROM node:18-slim
COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
RUN update-ca-certificates
...
```

---

## Troubleshooting Questions

### Q: I added the certificate but still get SSL errors. What's wrong?

**A:** Check these common issues:

1. **Certificate path is wrong:**
   ```bash
   docker run --rm your-image ls -la /etc/ssl/certs/netskope.pem
   ```

2. **Environment variables not set:**
   ```bash
   docker run --rm your-image env | grep CERT
   ```

3. **Certificate not updated:**
   ```bash
   docker run --rm your-image update-ca-certificates --verbose
   ```

4. **Application not using system certificates:**
   - Some apps bundle their own certificate store
   - Check application-specific SSL configuration

### Q: The certificate file is empty or corrupted?

**A:** Verify on your host machine:

```bash
# Check file exists and size
ls -lh "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
# Should be ~250KB

# Verify it's a valid certificate
openssl x509 -in "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem" -text -noout
```

### Q: Works on my Mac, fails in Docker?

**A:** This is expected! macOS applications use the system keychain, which includes Netskope's certificate. Docker containers have their own certificate store and don't have access to the macOS keychain.

---

## Implementation Questions

### Q: Do I need to modify all my Dockerfiles?

**A:** Yes, each Dockerfile that makes HTTPS connections needs the certificate. But you can:

1. Create a base image with the certificate:
   ```dockerfile
   FROM python:3.11-slim
   COPY nscacert_combined.pem /usr/local/share/ca-certificates/netskope.crt
   RUN update-ca-certificates
   ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
   ```

2. Use this as your base:
   ```dockerfile
   FROM your-org/python-netskope:3.11
   COPY . .
   RUN pip install -r requirements.txt
   ```

### Q: Can I automate certificate distribution?

**A:** Yes! Options:

1. **Docker secrets:**
   ```bash
   docker secret create netskope_cert nscacert_combined.pem
   ```

2. **Kubernetes secrets:**
   ```yaml
   kubectl create secret generic netskope-cert \
     --from-file=netskope.pem=/path/to/cert
   ```

3. **CI/CD environment variables:**
   ```yaml
   # GitHub Actions
   - name: Setup certificate
     run: echo "${{ secrets.NETSKOPE_CERT }}" > nscacert_combined.pem
   ```

### Q: How do I get the Netskope certificate?

**A:**

**For Helix employees:** The certificate is already included in this repository as `nscacert_combined.pem`. No need to copy it manually!

**To update the certificate (if needed):**

**macOS:**
```bash
cp "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem" .
```

**Windows:**
```powershell
Copy-Item "C:\Program Files (x86)\Netskope\STAgent\data\nscacert_combined.pem" .
```

**Linux:**
```bash
cp "/opt/netskope/stAgent/data/nscacert_combined.pem" .
```

---

## Performance Questions

### Q: Does this slow down my containers?

**A:** **No.** The certificate verification happens at the SSL/TLS handshake level and has negligible performance impact (<1ms per connection).

### Q: Does this make my images larger?

**A:** Minimally. The certificate adds ~250KB to your image size. For comparison:
- Python base image: ~150MB
- Node.js base image: ~180MB
- Certificate: ~0.25MB (0.15% increase)

---

## Alternative Solutions Questions

### Q: Why not just disable SSL verification?

**A:** **DON'T DO THIS!** Disabling SSL verification (`verify=False`, `NODE_TLS_REJECT_UNAUTHORIZED=0`) opens you to man-in-the-middle attacks and is a major security vulnerability.

Always use proper certificates instead of disabling verification.

### Q: Why not just request bypass rules from IT?

**A:** Bypass rules are great but:
- Take time to approve (days/weeks)
- May be denied for security policies
- Require IT involvement for every new domain
- This solution works immediately

Use bypass rules for long-term, and this solution for immediate needs.

### Q: Can I use a different certificate format?

**A:** The certificate must be in PEM format. If you have a different format:

**DER to PEM:**
```bash
openssl x509 -inform der -in certificate.cer -out certificate.pem
```

**PKCS#12 to PEM:**
```bash
openssl pkcs12 -in certificate.p12 -out certificate.pem -nodes
```

---

## Organizational Questions

### Q: Can I use this solution in production?

**A:** Yes! Many organizations do. Considerations:

✅ **Pros:**
- Reliable and proven approach
- No dependency on IT bypass rules
- Works with third-party images

⚠️ **Cons:**
- Must rebuild images when certificate rotates
- Certificate embedded in image
- Need secure certificate distribution

**Best practice:** Use this solution + request bypass rules for long-term.

### Q: How do I convince my security team this is safe?

**A:** Share these points:

1. **No security reduction:** You're already trusting this certificate on your host
2. **Industry standard:** Recommended by Netskope documentation
3. **Better than alternatives:** Disabling SSL verification is dangerous
4. **Visibility maintained:** Netskope still sees traffic, just doesn't intercept
5. **Compliance:** Meets security requirements better than workarounds

### Q: What about compliance (SOC 2, ISO 27001, etc.)?

**A:** This solution maintains compliance:
- ✅ SSL/TLS encryption maintained
- ✅ Certificate validation enabled
- ✅ No security features disabled
- ✅ Audit trails preserved (in Netskope logs)

---

## Contributing Questions

### Q: How can I contribute to this project?

**A:** We welcome contributions!

- Add language-specific examples
- Improve documentation
- Report issues
- Share success stories
- Submit PRs for fixes

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

### Q: I found a bug. Where do I report it?

**A:** [Open an issue on GitHub](https://github.com/myhelix/docker-netskope-ssl-fix/issues) with:
- Description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Docker version, etc.)

---

## Additional Resources

- [Main README](../README.md) - Getting started guide
- [Language Examples](LANGUAGE_EXAMPLES.md) - Language-specific configurations
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [IT Request Template](IT_REQUEST_TEMPLATE.md) - Request bypass rules from IT

---

**Still have questions?**

- 💬 [GitHub Discussions](https://github.com/myhelix/docker-netskope-ssl-fix/discussions)
- 🐛 [Report an Issue](https://github.com/myhelix/docker-netskope-ssl-fix/issues)
- 📧 Check with your organization's IT team

---

*Last updated: November 2025*
