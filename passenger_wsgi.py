import sys
import os

# Add your project directory to Python path
sys.path.insert(0, os.path.dirname(__file__))

from app import app

# Hostinger WSGI entry point
application = app

if __name__ == "__main__":
    application.run()