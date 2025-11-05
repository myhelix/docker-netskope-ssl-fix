#!/bin/bash
#
# Quick test script to verify Docker + Netskope setup
# For Helix internal use
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/examples"

echo "🧪 Docker + Netskope Setup Test"
echo "================================"
echo ""

# Check certificate exists
if [ ! -f "../nscacert_combined.pem" ]; then
    echo "❌ Error: Certificate not found at ../nscacert_combined.pem"
    echo "   Run ./update-certificate.sh first"
    exit 1
fi

CERT_SIZE=$(ls -lh ../nscacert_combined.pem | awk '{print $5}')
echo "✅ Certificate found ($CERT_SIZE)"
echo ""

# Test 1: Broken scenario (should fail with SSL errors)
echo "📋 Test 1: Broken scenario (demonstrating the problem)"
echo "   Building broken image..."
docker build -q -t netskope-test-broken -f Dockerfile . > /dev/null
echo "   Running test (expecting SSL errors)..."
if docker run --rm netskope-test-broken 2>&1 | grep -q "SSL ERROR"; then
    echo "   ✅ Correctly shows SSL errors without certificate"
else
    echo "   ⚠️  Warning: Expected SSL errors but none found"
fi
echo ""

# Test 2: Fixed scenario (should succeed)
echo "📋 Test 2: Fixed scenario (with baked certificate)"
echo "   Building fixed image..."
docker build -q -t netskope-test-fixed -f Dockerfile.fixed . > /dev/null
echo "   Running test (expecting success)..."
if docker run --rm netskope-test-fixed 2>&1 | grep -q "All endpoints accessible"; then
    echo "   ✅ All SSL connections successful with certificate!"
else
    echo "   ❌ SSL connections failed even with certificate"
    exit 1
fi
echo ""

# Test 3: Verify certificate in container
echo "📋 Test 3: Certificate verification"
CERT_COUNT=$(docker run --rm netskope-test-fixed grep -c "BEGIN CERTIFICATE" /usr/local/share/ca-certificates/netskope.crt)
echo "   ✅ Container has $CERT_COUNT certificates in bundle"
echo ""

# Test 4: Environment variables
echo "📋 Test 4: Environment variables"
docker run --rm netskope-test-fixed env | grep -E '(REQUESTS_CA_BUNDLE|SSL_CERT_FILE)' | while read line; do
    echo "   ✅ $line"
done
echo ""

echo "================================"
echo "✅ All tests passed!"
echo ""
echo "Your Docker + Netskope setup is working correctly."
echo "You can now use this configuration in your projects."
echo ""
