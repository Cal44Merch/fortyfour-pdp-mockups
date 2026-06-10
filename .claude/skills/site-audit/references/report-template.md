# Report formats for /site-audit

## 1. Specialist findings file format (`$OUT/findings/<agent>.md`)

Every specialist agent writes its findings in exactly this shape so synthesis
can merge them mechanically:

```markdown
# <Discipline> findings — <domain> — <date>

**Score: N/10** (use scoring-rubric.md)
**Evidence reviewed:** <list the files/screenshots you actually read>

## Issues
One block per issue, worst first:

### [SEV] Short issue title
- **Severity:** critical | high | medium | low
- **Evidence:** <file/screenshot path, or quoted data — required>
- **Why it matters:** one or two sentences, in business terms
- **Fix:** concrete, specific action (not "improve X")
- **Effort:** S | M | L

## What's working well
3–5 bullets. Genuine strengths only — this calibrates the score.

## Quick wins
Up to 3 fixes that are S-effort and high/medium impact.
```

Rules for specialists:
- Every issue needs evidence. No evidence file → say "not assessable, evidence
  missing" rather than guessing.
- 5–12 issues is the sweet spot. Don't pad; don't truncate real problems.
- Reply to the orchestrator with ONLY: score, top 3 issues (one line each),
  findings file path. The file is the deliverable, not the reply.

## 2. Final report format (`$OUT/REPORT.md`)

```markdown
# Website Audit — <domain>
<date> · <pages audited> · <evidence collected / gaps>

## Executive summary
Overall score N/10. Three to six sentences a founder can act on.

## Scorecard
| Discipline | Score | One-line verdict |
(one row per specialist)

## Prioritised roadmap
| # | Fix | Impact | Effort | Disciplines flagging it |
Ranked by impact ÷ effort. Deduplicate across specialists — an issue flagged by
several agents is one row with higher confidence. 10–15 rows max; this table IS
the deliverable.

## Top issues in detail
The top 5–8 roadmap items expanded: evidence (embed screenshot paths), why it
matters, exactly what to do.

## Per-discipline summaries
Five lines max each + link to the full findings file.

## What's working well
Cross-discipline strengths — what NOT to break.

## Evidence index
What was collected, what failed to collect, where it lives.
```
