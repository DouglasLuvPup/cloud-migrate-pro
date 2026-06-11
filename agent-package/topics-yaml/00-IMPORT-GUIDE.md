# Topic import guide — Copilot Studio code editor

These `.yaml` files are ready-to-paste **Copilot Studio topic definitions**. Each
fenced `yaml` block is one complete topic. Importing takes about a minute per topic.

## How to import one topic

1. Open the agent in Copilot Studio → **Topics** → **+ Add a topic** → **From blank**.
2. On the new topic, top-right **⋯ (More)** → **Open code editor** (or the `{}` icon).
3. **Select all** existing YAML in the editor and delete it.
4. Paste one topic block from the matching file below.
5. Click **Save**. Switch back to the canvas view to confirm the nodes rendered.
6. Repeat for each topic block.

> Tip: paste the **Conversation Start** / system-topic blocks into the *existing*
> system topic of the same name (edit it) rather than creating a new topic.

## Order of files

| File | Agent | Notes |
|---|---|---|
| `01-Concierge.topics.yaml` | Cloud Migrate Pro Concierge | Welcome card + About + Help Me Decide + Positioning + Fallback |
| `02-OnPrem.topics.yaml` | On-Prem → SPO | Conversation Start + OD2OD/SP2SPO overviews + sub-topics + Fallback |
| `03-HDrive.topics.yaml` | H: Drive → OneDrive | Conversation Start + scenario topics + Fallback |
| `04-CommonDrive.topics.yaml` | Common Drive → Teams/SPO | Conversation Start + Flow A/B + deep topics + Fallback |

## Notes on fidelity

- **Redirects to connected agents** (e.g. Concierge → On-Prem specialist) use a
  `SendActivity` hand-off message plus a note, because connected-agent routing in
  this suite is handled by **generative orchestration** — you usually do **not**
  need an explicit redirect topic. Keep these only if you want deterministic routing.
- **Data-table topics** (status values, column schemas, COTS comparison) are kept
  lightweight: the agents already have this detail in their uploaded **Knowledge**,
  so these topics nudge the model to answer from Knowledge rather than duplicating
  large tables in topic YAML (which is brittle to maintain).
- Every topic's trigger phrases come straight from the package build sheets.
