#!/usr/bin/env bash
# Publish site/straplog/ (support + privacy pages) to https://personalscience.com/docs/straplog/.
# The bucket sits behind the personalscience.com CloudFront distribution, which serves index.html for */.
set -euo pipefail
cd "$(dirname "$0")/.."
aws s3 sync site/straplog/ s3://personalscience-docs/docs/straplog/ --delete --exclude ".DS_Store" \
  --cache-control "max-age=300"
# The IAM user may create invalidations but not watch them; changes show within a minute or two.
aws cloudfront create-invalidation --distribution-id E1S5ZFV4OGW38Q --paths "/docs/straplog/*" \
  --query Invalidation.Id --output text
for url in https://personalscience.com/docs/straplog/ https://personalscience.com/docs/straplog/privacy/; do
  printf '%s %s\n' "$(curl -s -o /dev/null -w '%{http_code}' "$url")" "$url"
done
