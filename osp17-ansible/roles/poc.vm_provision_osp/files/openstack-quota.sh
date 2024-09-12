#!/bin/bash

export OS_USERNAME=admin
export OS_PROJECT_NAME=admin
export OS_AUTH_TYPE=password
export OS_PASSWORD='P@sswor0d'
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_AUTH_URL=http://211.55.50.23:5000
export OS_REGION_NAME=regionOne

openstack quota list -f json --compute --project admin