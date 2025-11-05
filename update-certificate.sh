#!/bin/bash
#
# Helper script to update Netskope certificate
# For Helix internal use
#

set -e

CERT_SOURCE="/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DEST_ROOT="$REPO_ROOT/nscacert_combined.pem"
CERT_DEST_EXAMPLES="$REPO_ROOT/examples/nscacert_combined.pem"

echo "🔐 Netskope Certificate Update Script"
echo "======================================"
echo ""

# Check if source certificate exists
if [ ! -f "$CERT_SOURCE" ]; then
    echo "❌ Error: Netskope certificate not found at:"
    echo "   $CERT_SOURCE"
    echo ""
    echo "Make sure Netskope is installed and running."
    exit 1
fi

# Get certificate info
CERT_SIZE=$(ls -lh "$CERT_SOURCE" | awk '{print $5}')
CERT_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$CERT_SOURCE" 2>/dev/null || stat -c "%y" "$CERT_SOURCE" 2>/dev/null | cut -d' ' -f1,2)

echo "📋 Source certificate info:"
echo "   Location: $CERT_SOURCE"
echo "   Size: $CERT_SIZE"
echo "   Modified: $CERT_DATE"
echo ""

# Check if certificates need updating
if [ -f "$CERT_DEST_ROOT" ]; then
    if cmp -s "$CERT_SOURCE" "$CERT_DEST_ROOT"; then
        echo "✅ Certificates are already up to date!"
        exit 0
    else
        echo "📝 Certificate has changed, updating..."
    fi
else
    echo "📝 Installing certificate for the first time..."
fi

# Copy to repository root
echo "   → Copying to $CERT_DEST_ROOT"
cp "$CERT_SOURCE" "$CERT_DEST_ROOT"

# Copy to examples directory
echo "   → Copying to $CERT_DEST_EXAMPLES"
cp "$CERT_SOURCE" "$CERT_DEST_EXAMPLES"

echo ""
echo "✅ Certificate updated successfully!"
echo ""
echo "📌 Next steps:"
echo "   1. Test with: cd examples && docker build -f Dockerfile.fixed -t test ."
echo "   2. Commit changes: git add nscacert_combined.pem examples/nscacert_combined.pem"
echo "   3. Push to repository for team access"
echo ""
