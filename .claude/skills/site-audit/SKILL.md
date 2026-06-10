---
name: site-audit
description: Run a complete 360° audit of a website (front end + back end) from a single URL — screenshots, Lighthouse, security headers, then parallel specialist agents (UX, CRO, SEO, performance, accessibility, security, content, tech stack, market research) and a single prioritised report. Use when the user gives a URL and asks to audit, analyse, review, or "tell me everything about" a website.
argument-hint: <url> [--quick] [--pages N]
---

# 360° Website Audit

You are the **audit director**. You run a three-phase pipeline: gather evidence
with scripts (no AI tokens), fan specialist agents out in parallel (right-sized
models), then synthesise one prioritised report yourself (you are the top model —
synthesis is your job; delegate everything else).

**Arguments:** `$ARGUMENTS` — first token is the URL (required; ask if missing).
`--quick` skips the market researcher and audits only the homepage.
`--pages N` caps how many pages are captured (default 6).

## Phase 0 — Evidence gathering (scripts only, no agents)

1. Derive `DOMAIN` from the URL and set `OUT=audits/$(date +%Y-%m-%d)-$DOMAIN`.
   Create `$OUT/`, `$OUT/screenshots/`, `$OUT/raw/`, `$OUT/findings/`.
2. Ensure tooling once per session (skip if already installed):
   ```bash
   cd .claude/skills/site-audit/scripts && npm install --no-fund --no-audit
   ls "${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}" 2>/dev/null || npx playwright install chromium
   ```
   (Cloud containers pre-bake Chromium at `$PLAYWRIGHT_BROWSERS_PATH`; only
   install if missing, and avoid `--with-deps` — apt is unreliable there.)
3. Run the three collectors (the first two can run in parallel; Lighthouse after
   capture to avoid contending for the network):
   ```bash
   bash .claude/skills/site-audit/scripts/gather.sh "$URL" "$OUT"        # HTML, headers, robots, sitemap, redirects
   node .claude/skills/site-audit/scripts/capture.mjs "$URL" "$OUT" 6    # screenshots, console errors, failed requests, discovered pages
   bash .claude/skills/site-audit/scripts/lighthouse.sh "$URL" "$OUT"    # perf/SEO/a11y/best-practices, mobile + desktop
   ```
4. If a collector fails (network policy, missing browser), note it in the report
   and continue — agents work from whatever evidence exists. Never fabricate
   evidence that wasn't collected. In cloud sessions, an HTTP 403 with a tiny
   body from every collector means the sandbox network policy is blocking the
   target domain — tell the user to add the domain to the environment's network
   allowlist and stop rather than auditing the proxy's error page.
5. Read `$OUT/raw/manifest.json` (written by the collectors) to see what was
   captured before briefing agents.

## Phase 1 — Specialist fan-out (parallel, one message, multiple Agent calls)

Launch ALL applicable agents **in a single message** so they run concurrently.
Every agent gets the same brief template:

> Audit the website `$URL`. Evidence is in `$OUT` (screenshots in
> `$OUT/screenshots/`, raw data in `$OUT/raw/`). Read only the files relevant to
> your discipline. Write your full findings to `$OUT/findings/<your-name>.md`
> using the findings format from
> `.claude/skills/site-audit/references/report-template.md`, then reply with ONLY:
> your 0–10 score, your top 3 issues (one line each), and the path to your file.

| Agent (subagent_type) | Evidence it needs | Model |
|---|---|---|
| `site-ux-auditor` | screenshots (desktop + mobile) | sonnet |
| `site-cro-auditor` | screenshots + HTML | sonnet |
| `site-seo-auditor` | HTML, robots, sitemap, Lighthouse SEO | haiku |
| `site-performance-auditor` | Lighthouse JSON, failed requests | haiku |
| `site-accessibility-auditor` | Lighthouse a11y, HTML, screenshots | sonnet |
| `site-security-auditor` | headers, HTML, tech fingerprint | sonnet |
| `site-content-auditor` | HTML text, screenshots | sonnet |
| `site-tech-auditor` | HTML source, headers, console errors, this repo's code if it powers the site | sonnet |
| `site-market-researcher` (skip on `--quick`) | the URL + brand name; uses web search | sonnet |

Pass `model` explicitly per the table — never let an agent silently inherit the
top model (see the model-sizing rule in CLAUDE.md).

## Phase 2 — Synthesis (you, directly)

1. Read every file in `$OUT/findings/`.
2. Write `$OUT/REPORT.md` following
   `.claude/skills/site-audit/references/report-template.md`, scoring with
   `.claude/skills/site-audit/references/scoring-rubric.md`. The heart of the
   report is the **prioritised roadmap**: every recommendation ranked by
   impact × effort, deduplicated across disciplines (five agents reporting the
   same slow hero image = one roadmap item, high confidence).
3. Send the user `$OUT/REPORT.md` plus the two or three screenshots that best
   illustrate the top issues (SendUserFile).
4. In chat, give a five-line executive summary: overall score, the one thing to
   fix first, and where the full report lives.

## Rules

- Audit only sites the user owns or is authorised to assess. Passive analysis
  only — never probe for vulnerabilities, fuzz inputs, or send abnormal traffic.
- Evidence-first: every claim in the report must trace to a screenshot, a file
  in `$OUT/raw/`, or a cited search result.
- Token discipline: agents read evidence files, not each other's findings; only
  you read everything, once, at synthesis time.
