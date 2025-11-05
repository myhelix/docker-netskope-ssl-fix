#!/usr/bin/env python3
"""
Test script to replicate Netskope SSL interception issues in Docker
This mimics the issue from the logs where Docker can't reach Google APIs
"""

import requests
import sys
import ssl

def test_endpoint(name, url):
    """Test connection to an endpoint"""
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
        success = test_endpoint(name, url)
        results.append((name, success))

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
        print("✅ All endpoints accessible!")
        print("\nEither:")
        print("  1. Bypass rules are working, OR")
        print("  2. Netskope certificate is trusted in container")
    else:
        print("❌ SSL ERRORS - Netskope is intercepting traffic")
        print("\nTo fix this, you need to:")
        print("  1. Add Netskope certificate to the Docker container, OR")
        print("  2. Request bypass rules from IT for Docker process")
        print("\nSee the fix in Dockerfile.fixed for solution.")
    print("="*70)

    return 0 if all_pass else 1

if __name__ == '__main__':
    sys.exit(main())
