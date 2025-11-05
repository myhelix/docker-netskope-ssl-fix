FROM python:3.11-slim

WORKDIR /app

# Install requests library
RUN pip install --no-cache-dir requests

# Copy test script
COPY test_google_apis.py .

# Run the test
CMD ["python", "test_google_apis.py"]
