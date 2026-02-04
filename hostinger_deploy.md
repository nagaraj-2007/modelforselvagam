# Hostinger Deployment Guide

## Files to Upload to Hostinger

### Required Files:
- `app.py` (main Flask application)
- `requirements.txt` (Python dependencies)
- `.htaccess` (for URL routing)
- `passenger_wsgi.py` (Hostinger WSGI entry point)

## Step-by-Step Deployment

### 1. Create Hostinger WSGI File
Create `passenger_wsgi.py` in your domain's public_html folder

### 2. Upload Files via File Manager
- Upload `app.py` and `requirements.txt` to public_html
- Create `.htaccess` for proper routing

### 3. Install Python Packages
Use Hostinger's Python Package Installer or SSH

### 4. Set Environment Variables
Add Firebase service account JSON in Hostinger control panel

### 5. Test Your API
Access your domain to verify deployment

## Environment Setup Required:
- Python 3.8+
- Firebase service account JSON
- Domain/subdomain configured

## API Endpoints After Deployment:
- GET https://yourdomain.com/ (health check)
- POST https://yourdomain.com/check-location (send notifications)