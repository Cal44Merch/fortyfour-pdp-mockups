# Forty Four — PDP Mockups & Website Tooling

Static HTML/CSS mockups for the Forty Four product detail page (PDP) redesign,
plus AI tooling for analysing the live website.

## Repo layout

- `index.html` — landing page linking to all mockups
- `pdp-1-old.html`, `pdp-2-cluster.html`, `pdp-3-rows.html`, `pdp-old-vs-new.html`, `basket.html` — mockups
- `_pdp-shared.css` — shared mockup styles
- `.claude/skills/site-audit/` — the 360° website audit pipeline (run with `/site-audit <url>`)
- `.claude/agents/site-*.md` — the specialist auditor agents the pipeline uses
- `audits/` — generated audit reports and evidence (screenshots, Lighthouse data)

## Website audit system

To analyse any website front-to-back, run:

```
/site-audit https://example.com
```

The skill gathers evidence with scripts first (screenshots, Lighthouse, headers —
no AI tokens), then fans out to specialist agents in parallel, then synthesises a
single prioritised report. See `.claude/skills/site-audit/SKILL.md`.

## RULE: Right-size the model for every task

Always use the cheapest model that can do the job well. Never use the top model
for trivial work, and never use a small model for judgment-heavy work.

- **Scripts before tokens.** If a deterministic script can gather the data
  (screenshots, headers, Lighthouse, crawling, parsing), run the script and have
  the model interpret the output. Don't make a model do a computer's job.
- **haiku** — mechanical/extractive work: parsing structured output (Lighthouse
  JSON, meta tags, headers), checklist verification, formatting, summarising
  raw data.
- **sonnet** — standard specialist analysis: design critique, code review,
  security/accessibility/content assessment, web research.
- **opus / top model** — only for synthesis, prioritisation, and high-judgment
  strategy: combining many specialist reports into one, trade-off decisions,
  final recommendations.
- When launching subagents, set the `model` parameter explicitly rather than
  inheriting the (expensive) parent model by default.
- Subagents must write detailed findings to files and return only a short
  summary, so the orchestrator's context stays small.
