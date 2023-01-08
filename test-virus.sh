#!/bin/bash

aws s3 cp fixtures/test-virus.txt s3://mm-clamav-quarantine
aws s3 cp fixtures/test-file.txt s3://mm-clamav-quarantine

sleep 30

VIRUS_TEST=$(aws s3api get-object-tagging --key test-virus.txt --bucket mm-clamav-quarantine --output text)
CLEAN_TEST=$(aws s3api get-object-tagging --key test-file.txt --bucket mm-clamav-clean --output text)

echo "Dirty tag: ${VIRUS_TEST}"
echo "Clean tag: ${CLEAN_TEST}"