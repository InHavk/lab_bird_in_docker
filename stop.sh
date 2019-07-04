#!/bin/bash

docker stop external-bird internal-bird balancer-bird
docker rm external-bird internal-bird balancer-bird
rm -f /var/run/netns/external-bird
rm -f /var/run/netns/internal-bird
rm -f /var/run/netns/balancer-bird
