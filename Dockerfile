FROM python:3.10-slim

WORKDIR /app

# Set environment variables for production
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FLASK_ENV=production \
    PORT=4000

# Install dependencies
COPY python_backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy frontend and application source code
COPY frontend /app/frontend
COPY python_backend /app/python_backend

WORKDIR /app/python_backend

EXPOSE 4000

# Production WSGI server binding to Render's dynamic $PORT (fallback to 4000 locally)
CMD ["sh", "-c", "gunicorn app:app --bind 0.0.0.0:${PORT:-4000} --workers 2 --threads 4 --timeout 120"]
