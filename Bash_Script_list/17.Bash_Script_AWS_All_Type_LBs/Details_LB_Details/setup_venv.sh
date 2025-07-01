#!/bin/bash

# Script to create a virtual environment and install pandas

VENV_DIR="venv"

echo "Creating virtual environment in: $VENV_DIR"
python3 -m venv $VENV_DIR

if [ $? -ne 0 ]; then
  echo "❌ Failed to create virtual environment. Make sure python3 and python3-venv are installed."
  exit 1
fi

echo "✅ Virtual environment created."

echo "Activating virtual environment..."
source $VENV_DIR/bin/activate

echo "Installing pandas..."
pip install pandas

if [ $? -eq 0 ]; then
  echo "✅ pandas installed successfully."
  echo ""
  echo "🎉 Setup complete!"
  echo "👉 To activate the environment later, run: source $VENV_DIR/bin/activate"
  echo "👉 To run your script: python3 aws_lb_export_20250625_153748/convert_to_excel.py"
  echo "👉 To deactivate the environment: deactivate"
else
  echo "❌ Failed to install pandas."
fi
