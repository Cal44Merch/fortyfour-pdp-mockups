#!/usr/bin/env bash
# lighthouse.sh <url> <outdir> — Lighthouse JSON for mobile + desktop.
# Falls back to the PageSpeed Insights API if local Lighthouse can't run.
set -u
URL="${1:?usage: lighthouse.sh <url> <outdir>}"
OUT="${2:?usage: lighthouse.sh <url> <outdir>}"
RAW="$OUT/raw"
mkdir -p "$RAW"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
# chrome-launcher reads CHROME_PATH; point it at Playwright's Chromium
BROWSERS="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}"
CHROME_BIN="${CHROME_PATH:-$(find "$BROWSERS" -type f -name chrome -path '*chrome-linux*' 2>/dev/null | head -1)}"

run_lh() { # run_lh <preset-flag> <label>
  (cd "$SCRIPTS_DIR" && CHROME_PATH="$CHROME_BIN" npx --yes lighthouse "$URL" $1 \
    --output=json --output-path="$RAW/lighthouse-$2.json" \
    --chrome-flags="--headless --no-sandbox --ignore-certificate-errors" \
    --quiet --max-wait-for-load=45000) 2>>"$RAW/lighthouse-errors.txt"
}

echo "== Lighthouse mobile =="
run_lh "--form-factor=mobile" "mobile"
echo "== Lighthouse desktop =="
run_lh "--preset=desktop" "desktop"

# Fallback: PageSpeed Insights API (no key needed at low volume)
if [ ! -s "$RAW/lighthouse-mobile.json" ]; then
  echo "Local Lighthouse failed; trying PageSpeed Insights API"
  curl -sS -m 90 "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],''))" "$URL")&strategy=mobile&category=performance&category=accessibility&category=seo&category=best-practices" \
    -o "$RAW/lighthouse-mobile.json" || true
fi

# Tiny summary so agents can read scores without loading the full JSON
python3 - "$RAW" <<'EOF' 2>/dev/null || true
import json, os, sys
raw = sys.argv[1]
summary = {}
for label in ("mobile", "desktop"):
    p = os.path.join(raw, f"lighthouse-{label}.json")
    if not os.path.exists(p) or os.path.getsize(p) == 0:
        continue
    d = json.load(open(p))
    lhr = d.get("lighthouseResult", d)  # PSI wraps the LHR
    cats = {k: round((v.get("score") or 0) * 100) for k, v in lhr.get("categories", {}).items()}
    audits = lhr.get("audits", {})
    metrics = {k: audits[k]["displayValue"] for k in
               ("first-contentful-paint", "largest-contentful-paint", "total-blocking-time",
                "cumulative-layout-shift", "speed-index", "interactive") if k in audits and audits[k].get("displayValue")}
    failing = sorted([(a.get("score"), k, a.get("title", "")) for k, a in audits.items()
                      if a.get("score") is not None and a["score"] < 0.9 and a.get("scoreDisplayMode") in ("numeric", "binary")])[:25]
    summary[label] = {"category_scores": cats, "metrics": metrics,
                      "worst_audits": [{"score": s, "id": k, "title": t} for s, k, t in failing]}
json.dump(summary, open(os.path.join(raw, "lighthouse-summary.json"), "w"), indent=1)
print("lighthouse summary:", {k: v["category_scores"] for k, v in summary.items()})
EOF

echo "lighthouse.sh done -> $RAW"
