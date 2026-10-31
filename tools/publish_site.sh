#!/usr/bin/env bash
# Build, then publish site/straplog/ (docs + privacy pages) to https://personalscience.com/docs/straplog/.
# The bucket sits behind the personalscience.com CloudFront distribution, which serves index.html for */.
set -euo pipefail
# Auth via IAM Identity Center (AdministratorAccess on personalscience). If expired: aws sso login --sso-session ps
export AWS_PROFILE=admin
aws sts get-caller-identity --query Arn --output text >/dev/null 2>&1 || aws sso login --sso-session ps
cd "$(dirname "$0")/.."
tools/build_site.py
aws s3 sync site/straplog/ s3://personalscience-docs/docs/straplog/ --delete --exclude ".DS_Store" --exclude "*/.DS_Store" \
  --cache-control "max-age=300"
# Invalidations show within a minute or two.
aws cloudfront create-invalidation --distribution-id E1S5ZFV4OGW38Q --paths "/docs/straplog/*" \
  --query Invalidation.Id --output text
for url in https://personalscience.com/docs/straplog/ https://personalscience.com/docs/straplog/privacy/; do
  printf '%s %s\n' "$(curl -s -o /dev/null -w '%{http_code}' "$url")" "$url"
done
