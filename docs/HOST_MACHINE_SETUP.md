# Host Machine SSL Configuration for Netskope

This guide covers configuring your Mac/Linux host machine to trust Netskope's SSL certificate for tools that run outside Docker containers.

## Problem

Tools running directly on your host machine (not in Docker) may also encounter SSL certificate verification errors when behind Netskope:

- ❌ Claude Code cannot connect to MCP servers
- ❌ `npm install` fails with certificate errors
- ❌ `pip install` fails outside Docker
- ❌ `git clone` over HTTPS fails
- ❌ `curl` / `wget` commands fail
- ❌ VS Code extensions fail to install

## Solution Overview

Different tools use different methods to verify SSL certificates. You need to configure each tool or its underlying runtime (Node.js, Python, Ruby, etc.) to trust Netskope's certificate.

---

## macOS Certificate Location

Netskope stores its certificate at:
```
/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem
```

You can also export it from Keychain Access as described in the [Alternative: System Keychain](#alternative-system-keychain) section.

---

## Quick Setup (Recommended)

Add these environment variables to your shell configuration file:

### For zsh (macOS default)

Edit `~/.zshrc`:

```bash
# Netskope SSL Certificate Configuration
export NETSKOPE_CERT="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"

# Node.js (Claude Code, npm, yarn, pnpm)
export NODE_EXTRA_CA_CERTS="$NETSKOPE_CERT"

# Python (pip, requests)
export REQUESTS_CA_BUNDLE="$NETSKOPE_CERT"
export SSL_CERT_FILE="$NETSKOPE_CERT"
export CURL_CA_BUNDLE="$NETSKOPE_CERT"

# Ruby (gem, bundler)
export SSL_CERT_FILE="$NETSKOPE_CERT"

# Go
export SSL_CERT_FILE="$NETSKOPE_CERT"

# AWS CLI
export AWS_CA_BUNDLE="$NETSKOPE_CERT"

# Git
export GIT_SSL_CAINFO="$NETSKOPE_CERT"
```

### For bash

Edit `~/.bashrc` or `~/.bash_profile` with the same content as above.

### Apply Changes

```bash
# Reload your shell configuration
source ~/.zshrc  # or source ~/.bashrc

# Verify it's set
echo $NODE_EXTRA_CA_CERTS
```

**Important:** Restart all terminal windows, IDEs (VS Code, Claude Code), and applications after making these changes.

---

## Tool-Specific Configuration

### Claude Code

Claude Code uses Node.js and respects `NODE_EXTRA_CA_CERTS`:

```bash
export NODE_EXTRA_CA_CERTS="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

Then **restart Claude Code completely** (quit and relaunch, don't just close the window).

#### Verification

After restarting Claude Code, MCP server connections should work. You can test by:
1. Configuring an MCP server (like Atlassian)
2. Checking if it connects without SSL errors

### npm / yarn / pnpm

Node.js package managers also use `NODE_EXTRA_CA_CERTS`:

```bash
export NODE_EXTRA_CA_CERTS="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

Alternatively, configure npm directly:

```bash
npm config set cafile "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

#### Verification

```bash
npm install --registry=https://registry.npmjs.org/ express
```

### Python (pip, requests)

```bash
export REQUESTS_CA_BUNDLE="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
export SSL_CERT_FILE="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

Or configure pip directly:

```bash
pip config set global.cert "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

#### Verification

```bash
pip install --upgrade pip
python -c "import requests; print(requests.get('https://pypi.org').status_code)"
```

### Git

```bash
git config --global http.sslCAInfo "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

Or via environment variable:

```bash
export GIT_SSL_CAINFO="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

#### Verification

```bash
git clone https://github.com/octocat/Hello-World.git test-clone
rm -rf test-clone
```

### curl / wget

```bash
# curl
export CURL_CA_BUNDLE="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
curl https://api.github.com

# wget
wget --ca-certificate="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem" https://api.github.com
```

### AWS CLI

```bash
export AWS_CA_BUNDLE="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

Or configure via AWS CLI:

```bash
aws configure set ca_bundle "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

### Ruby (gem, bundler)

```bash
export SSL_CERT_FILE="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
```

#### Verification

```bash
gem install bundler
```

---

## Alternative: System Keychain

Instead of using environment variables, you can add Netskope's certificate to your system's trusted certificate store.

### macOS

1. Open **Keychain Access** (Applications > Utilities > Keychain Access)
2. File > Import Items
3. Navigate to `/Library/Application Support/Netskope/STAgent/data/`
4. Import `nscacert_combined.pem`
5. Double-click the imported certificate
6. Expand "Trust" section
7. Set "When using this certificate" to **Always Trust**
8. Close and enter your password

**Note:** This makes the certificate trusted system-wide, but some tools (like Node.js) may still require environment variables.

### Linux

```bash
# Ubuntu/Debian
sudo cp "/path/to/nscacert_combined.pem" /usr/local/share/ca-certificates/netskope.crt
sudo update-ca-certificates

# CentOS/RHEL/Fedora
sudo cp "/path/to/nscacert_combined.pem" /etc/pki/ca-trust/source/anchors/netskope.crt
sudo update-ca-trust
```

---

## Troubleshooting

### Environment Variables Not Working

1. **Verify the variable is set:**
   ```bash
   echo $NODE_EXTRA_CA_CERTS
   ```

2. **Check certificate file exists:**
   ```bash
   ls -la "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
   ```

3. **Verify certificate is valid:**
   ```bash
   openssl x509 -in "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem" -text -noout
   ```

4. **Restart applications completely** (quit and relaunch)

### Still Getting SSL Errors

Try these commands to debug:

```bash
# Test with curl
curl -v --cacert "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem" https://api.github.com

# Test with Python
python3 -c "import ssl; print(ssl.get_default_verify_paths())"

# Test with Node.js
node -e "console.log(process.env.NODE_EXTRA_CA_CERTS)"
```

### Certificate Has Expired or Changed

Netskope may rotate certificates. If your certificate is outdated:

1. Check for updates from Netskope client
2. Re-export from Keychain Access
3. Update the repository copy if needed

---

## Automated Setup Script

Run this script to automatically configure your shell:

```bash
./setup-host-environment.sh
```

(See `setup-host-environment.sh` in the repository root)

---

## Security Considerations

- These environment variables point to Netskope's certificate, which allows SSL inspection
- Only use this configuration on machines where Netskope is actively running
- Do not commit certificates or environment files to public repositories
- Remove these configurations if you leave your organization or Netskope is uninstalled

---

## Related Documentation

- [Docker Configuration](../README.md) - For containers
- [Language Examples](LANGUAGE_EXAMPLES.md) - Language-specific patterns
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues

---

## Summary: Common Tools

| Tool | Environment Variable | Config File Alternative |
|------|---------------------|------------------------|
| Claude Code | `NODE_EXTRA_CA_CERTS` | N/A |
| npm | `NODE_EXTRA_CA_CERTS` | `npm config set cafile` |
| Python/pip | `SSL_CERT_FILE` | `pip config set global.cert` |
| Git | `GIT_SSL_CAINFO` | `git config --global http.sslCAInfo` |
| curl | `CURL_CA_BUNDLE` | `--cacert` flag |
| AWS CLI | `AWS_CA_BUNDLE` | `aws configure set ca_bundle` |
| Ruby/gem | `SSL_CERT_FILE` | N/A |

---

**Need help?** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) or open an issue on GitHub.
