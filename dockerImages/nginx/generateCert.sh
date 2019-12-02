#!/bin/bash
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

subject="/C=US/ST=MI/L=AnnArbor/O=weathervane/OU=auction/CN=www.weathervane"

# Generate a key for signing the certificate
openssl genrsa -out /etc/pki/tls/private/weathervane.key 2048 

# Create a CSR
openssl req -new -key /etc/pki/tls/private/weathervane.key -out /etc/pki/tls/certs/weathervane.csr -subj $subject

# Create the certificate
openssl x509 -req -days 730 -in /etc/pki/tls/certs/weathervane.csr -signkey /etc/pki/tls/private/weathervane.key -out /etc/pki/tls/certs/weathervane.crt