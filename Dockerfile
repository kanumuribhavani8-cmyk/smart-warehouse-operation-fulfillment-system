FROM python:3.10-slim

WORKDIR /app

# Install dependencies
COPY python_backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy application and frontend
COPY python_backend /app/python_backend
COPY frontend /app/frontend

WORKDIR /app/python_backend
ENV FLASK_ENV=production
EXPOSE 4000

CMD ["python", "app.py"]
