#!/bin/bash
# Build Openpyxl Lambda layer
rm -rf python openpyxl_layer.zip
mkdir -p python
pip install openpyxl -t python
zip -r openpyxl_layer.zip python
echo "Created openpyxl_layer.zip"