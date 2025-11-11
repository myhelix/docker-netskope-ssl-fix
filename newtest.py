#!/usr/bin/env python3
"""
Test script to replicate Netskope SSL interception issues in Docker
This mimics the issue from the logs where Docker can't reach Google APIs
"""

import requests
import socket
import sys
import ssl
from urllib.parse import urlparse

def test_endpoint(name, url):
    """Test connection to an endpoint using requests (HTTP/1.1)."""
    print(f"\n{'='*70}")
    print(f"Testing: {name}")
    print(f"URL: {url}")
    print('='*70)

    try:
        response = requests.get(url, timeout=5)
        print(f"✓ SUCCESS: Status {response.status_code}")
        print(f"  Response length: {len(response.content)} bytes")
        return True
    except requests.exceptions.SSLError as e:
        print(f"✗ SSL ERROR: {e}")
        print(f"\n  This is the Netskope interception issue!")
        print(f"  The container doesn't trust Netskope's certificate.")
        return False
    except requests.exceptions.ConnectionError as e:
        print(f"✗ CONNECTION ERROR: {e}")
        return False


def test_http2_alpn(name, url):
    """Verify that HTTP/2 ALPN (h2) negotiates successfully."""
    parsed = urlparse(url)
    host = parsed.hostname
    if not host:
        print("✗ ERROR: Unable to parse host from URL")
        return False

    print(f"\n{'-'*70}")
    print(f"Checking HTTP/2 ALPN for: {name}")
    print(f"Host: {host}:443")
    print('-'*70)

    context = ssl.create_default_context()
    # Explicitly request HTTP/2 so we can detect when the proxy strips ALPN.
    context.set_alpn_protocols(["h2", "http/1.1"])

    try:
        with socket.create_connection((host, 443), timeout=5) as raw_sock:
            with context.wrap_socket(raw_sock, server_hostname=host) as tls_sock:
                negotiated = tls_sock.selected_alpn_protocol()
                print(f"  Selected ALPN protocol: {negotiated}")
                if negotiated == "h2":
                    print("  ✓ SUCCESS: HTTP/2 negotiated")
                    return True
                print("  ✗ WARN: HTTP/2 not negotiated (gRPC will fail here)")
                return False
    except ssl.SSLError as e:
        print(f"✗ SSL ERROR during ALPN check: {e}")
        return False
    except (socket.timeout, OSError) as e:
        print(f"✗ CONNECTION ERROR during ALPN check: {e}")
        return False
    except Exception as e:
        print(f"✗ ERROR: {type(e).__name__}: {e}")
        return False

def main():
    print("\n" + "="*70)
    print("DOCKER + NETSKOPE SSL INTERCEPTION TEST")
    print("="*70)
    print("\nThis replicates the issue from the Netskope logs where")
    print("com.docker.backend couldn't reach Google AI endpoints.")

    # Test the endpoints that were in the logs
    endpoints = [
        ("Google Custom Search API", "https://customsearch.googleapis.com"),
        ("Google Gemini API", "https://generativelanguage.googleapis.com"),
        ("Google Fonts", "https://fonts.googleapis.com"),
    ]

    results = []
    for name, url in endpoints:
        https_ok = test_endpoint(name, url)
        results.append((f"{name} (HTTPS)", https_ok))

        alpn_ok = test_http2_alpn(name, url)
        results.append((f"{name} (HTTP/2 ALPN)", alpn_ok))

    # Summary
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)

    all_pass = all(success for _, success in results)

    for name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} - {name}")

    print("\n" + "="*70)
    if all_pass:
        print("✅ All HTTPS and HTTP/2 checks passed!")
        print("\nEither:")
        print("  1. Bypass rules are working, OR")
        print("  2. Netskope certificate is trusted and ALPN is intact")
    else:
        print("❌ One or more checks failed")
        print("\nIf HTTPS failed:")
        print("  • Import the Netskope certificate into the container trust store")
        print("\nIf HTTP/2 ALPN failed:")
        print("  • Netskope is stripping HTTP/2; gRPC will break")
        print("  • Request an exclusion or fall back to a REST transport")
        print("\nSee the fix in Dockerfile.fixed for the certificate work.")
    print("="*70)

    return 0 if all_pass else 1

if __name__ == '__main__':
    sys.exit(main())
