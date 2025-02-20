# Use Python image
FROM python:3.9

# Copy script to container
COPY helloworld.py /app/helloworld.py

# Set working directory
WORKDIR /app

# Run the script
CMD ["python", "helloworld.py"]
