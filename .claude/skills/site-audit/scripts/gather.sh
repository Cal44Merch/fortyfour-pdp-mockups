#!/usr/bin/env bash
# gather.sh <url> <outdir> — fetch HTML, headers, robots, sitemap, redirect chain.
# Pure curl; degrades gracefully (every step is best-effort).
set -u
URL="${1:?usage: gather.sh <url> <outdir>}"
OUT="${2:?usage: gather.sh <url> <outdir>}"
RAW="$OUT/raw"
mkdir -p "$RAW"

ORIGIN="$(echo "$URL" | sed -E 's#^(https?://[^/]+).*#\1#')"
UA="Mozilla/5.0 (compatible; SiteAuditBot/1.0)"

echo "== Redirect chain & timing =="
curl -sSL -A "$UA" -o "$RAW/index.html" -D "$RAW/response-headers.txt" \
  -w 'final_url=%{url_effective}\nhttp_code=%{response_code}\nredirects=%{num_redirects}\nip=%{remote_ip}\ntls=%{ssl_verify_result}\nttfb_s=%{time_starttransfer}\ntotal_s=%{time_total}\nsize_bytes=%{size_download}\n' \
  "$URL" > "$RAW/curl-timing.txt" 2>"$RAW/curl-errors.txt" || echo "WARN: main fetch failed"

echo "== robots.txt / sitemap / common endpoints =="
curl -sS -A "$UA" -m 15 "$ORIGIN/robots.txt"   -o "$RAW/robots.txt"   || true
SITEMAP_URL="$(grep -i '^sitemap:' "$RAW/robots.txt" 2>/dev/null | head -1 | sed 's/^[Ss]itemap:[[:space:]]*//' | tr -d '\r')"
curl -sS -A "$UA" -m 20 "${SITEMAP_URL:-$ORIGIN/sitemap.xml}" -o "$RAW/sitemap.xml" || true
curl -sS -A "$UA" -m 10 -o /dev/null -w '%{http_code}' "$ORIGIN/favicon.ico" > "$RAW/favicon-status.txt" || true

echo "== Security headers (homepage) =="
# response-headers.txt already has them; extract the security-relevant set for quick reading.
grep -iE '^(strict-transport-security|content-security-policy|x-frame-options|x-content-type-options|referrer-policy|permissions-policy|cross-origin|set-cookie|server|x-powered-by|cache-control|access-control)' \
  "$RAW/response-headers.txt" > "$RAW/security-headers.txt" 2>/dev/null || true

echo "== Tech fingerprint (passive, from HTML only) =="
{
  grep -oiE '(wp-content|wp-includes|shopify|cdn\.shopify|squarespace|wix\.com|webflow|next/static|_next|nuxt|gatsby|svelte|astro|react|vue|angular|jquery[^"]*\.js|bootstrap|tailwind|gtag|googletagmanager|google-analytics|fbevents|hotjar|klaviyo|stripe|cloudflare)' \
    "$RAW/index.html" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn
} > "$RAW/tech-fingerprint.txt" || true

echo "== Meta/SEO extract =="
{
  grep -oiE '<title>[^<]*</title>' "$RAW/index.html" | head -3
  grep -oiE '<meta[^>]*(name|property)="(description|robots|viewport|og:[a-z:]+|twitter:[a-z:]+)"[^>]*>' "$RAW/index.html"
  grep -oiE '<link[^>]*rel="canonical"[^>]*>' "$RAW/index.html"
  grep -oiE '<h1[^>]*>.{0,120}' "$RAW/index.html" | head -5
  grep -ciE '<img ' "$RAW/index.html" | sed 's/^/img_count=/'
  grep -oiE '<script[^>]*type="application/ld\+json"' "$RAW/index.html" | wc -l | sed 's/^/jsonld_blocks=/'
} > "$RAW/seo-extract.txt" 2>/dev/null || true

# Manifest entry
python3 - "$RAW" <<'EOF' 2>/dev/null || true
import json, os, sys
raw = sys.argv[1]
m_path = os.path.join(raw, "manifest.json")
m = json.load(open(m_path)) if os.path.exists(m_path) else {}
m["gather"] = {f: os.path.getsize(os.path.join(raw, f))
               for f in os.listdir(raw) if os.path.isfile(os.path.join(raw, f))}
json.dump(m, open(m_path, "w"), indent=1)
EOF

echo "gather.sh done -> $RAW"
