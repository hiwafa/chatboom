FROM python:3.10-slim

# working directory in container
WORKDIR /app

# Copy the requirements from host to container
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy actual server code
COPY server.py .

EXPOSE 8080

# Start the server
CMD ["python", "server.py"]