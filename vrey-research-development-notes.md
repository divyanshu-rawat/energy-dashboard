# VREY Engineering Challenge — Research & AI-Assisted Development Notes

**Purpose:** A concise record of how I approached the challenge, what I researched, how I used AI assistance, and which engineering decisions I accepted, challenged, or changed.

> **About this document:** This is a curated synthesis of my working notes and development discussions, **not an exported AI conversation or a verbatim prompt transcript**. The prompt examples below are paraphrases of questions and topics I explored. Where relevant, I distinguish exploratory proposals from what I actually implemented.

## 1. Starting point and approach

My stronger experience is in frontend/full-stack engineering, particularly JavaScript frameworks. Ruby on Rails and RSpec were relatively new to me. I used AI primarily as an interactive learning and code-review partner while implementing and verifying the solution myself.

I focused on three goals:

1. A Rails-native MVC implementation suitable for a small engineering team, rather than a separate React SPA.
2. Clear boundaries between fetching external data, storing it, calculating consumption, and presenting the results.
3. Database integrity, testability, and predictable behavior when imports are repeated.

I worked incrementally: generate a minimal Rails application, model the data, add tests, implement the API client, implement the importer, implement the calculator, build the dashboard, and document the trade-offs. I used separate Git commits as checkpoints.

## 2. Research sequence and how AI helped

The examples here are **representative prompt themes, paraphrased for readability**. They are not claimed to be exact historical prompt text.

| Area | Questions I investigated with AI | What I verified or decided |
| --- | --- | --- |
| Energy domain | What is a German MaLo versus MeLo? Is a consumer an apartment or a landlord? | Model a house with many consuming units. Each has market and metering locations for this exercise. No separate landlord entity was needed. |
| Consumption formula | Which measurement represents total consumption? What should be subtracted? | I sought clarification from Martin: **MeLo represents total consumption**. The implemented calculation is **MeLo − MaLo**, provisionally treating MaLo as the other/grid-supplied portion. |
| API shape | How should nested daily profiles and 15-minute readings be normalized? | Normalize into records with `starts_at`, `ends_at`, decimal `value`, and `quality`. Preserve time-zone-aware timestamps. |
| Database design | What should be a model, association, foreign key, or unique index? | `House → Consumer → Location → Measurement`; use a single `Location` model with `location_type`. Enforce one of each type per consumer and unique measurement intervals. |
| Import semantics | Should repeat imports use `upsert_all` or `insert_all`? | **Changed my initial thinking** after noticing the mock API returned different values for identical intervals. Chose `insert_all`, preserving the first stored value. |
| Reliability | What happens when one API call fails? What happens if a batch fails? | Fetch both location profiles before writes, and wrap the per-consumer batch persistence in a transaction. |
| Calculations | Why a SQL self-join? What if timestamps don't align? | Join MaLo and MeLo by **both** interval start and end times. Exclude unmatched intervals instead of treating missing readings as zero. |
| Rails UI | What do routes, controllers, `form_with`, ERB, and Turbo do? | Two user actions: read/filter stored data with GET; explicitly import data with POST, followed by a Turbo-compatible redirect. |
| Testing | How can I test services without hitting the actual mock API? | RSpec model/service/request tests; WebMock for HTTP; dependency injection and an `instance_double` for importer tests. |
| Future scaling | Would incremental imports, background jobs, Kafka, or an SPA help? | Keep the take-home synchronous and Rails-native; document incremental imports, background jobs, coverage monitoring, and larger-scale aggregation as future options. Kafka adds unjustified operational complexity here. |

## 3. Investigation that changed the implementation

### From upserts to first-write-wins inserts

**Original option considered:** `upsert_all` could update an interval when the upstream API returned corrected readings.

**Observation:** Repeating the same mock API request returned different values for the same timestamps. The response didn't identify those changes as authoritative corrections.

**Question I raised:** If historical readings change on every refresh, should re-importing replace data and change the dashboard every time?

**Decision:** Use `Measurement.insert_all(..., unique_by: :idx_measurements_unique_interval)` with the unique key `(location_id, starts_at, ends_at)`.

- New intervals are inserted.
- Existing intervals are skipped, even if the newly fetched value differs.
- Repeating an import cannot duplicate a stored interval.
- This stabilizes historical calculations for the mock API.

**Trade-off:** Genuine historical corrections will not be applied automatically. In production, I would require an explicit correction/revision policy, ideally retaining an audit trail. First-write-wins is a challenge-specific assumption, not a universal energy-data rule.

### From naive incremental imports to explicit import dates

I investigated whether the next request could begin at the latest stored timestamp. The API provides `beginDate`, so a date-based overlap is possible, but that alone doesn't guarantee completeness.

Example: MaLo may have readings through October 18 while MeLo is only complete through October 17. Starting strictly after the latest overall timestamp could leave missing pairs. Likewise, a missing interval from October 11 would not be repaired by fetching only from October 18.

**Current implementation:** Users explicitly choose an import beginning date. The application requests that range and skips duplicates. Viewing or changing a dashboard date filter does **not** call the remote API.

**Possible next iteration:** Track completeness per location, refetch from the earliest incomplete date (including overlap), and perform periodic historical backfills. Keep reconciliation separate from fetching.

### From positional matching to an interval-based self-join

**Risk:** If either series omits one quarter-hour reading, subtracting arrays by their indexes pairs unrelated intervals.

**Decision:** Use an SQL self-join on the `measurements` table, filtering one side to MeLo and the other side to MaLo, with equality on `starts_at` **and** `ends_at`. An inner join returns only matched pairs.

**Trade-off:** A day with missing intervals can still produce a partial total. The implementation doesn't currently report a completeness percentage; that would be a high-value follow-up.

## 4. Application structure and request flows

### Data model

```text
House
└── Consumer (consuming unit, e.g. apartment)
    ├── Location (market / MaLo)
    │   └── Measurements (value + starts_at + ends_at + quality)
    └── Location (metering / MeLo)
        └── Measurements (value + starts_at + ends_at + quality)
```

A market/metering "location" is an energy-market concept, not another street address. The one-MaLo/one-MeLo rule belongs to this exercise; real-world mapping may be more complex.

### A. Filtering the dashboard: read path

```text
GET /houses/:id?from_date=...&to_date=...
→ HousesController#show
→ SolarConsumption::Calculator
→ PostgreSQL (matched stored measurements)
→ ERB dashboard
```

No external API request is performed on filter changes. This keeps the dashboard available when the upstream API isn't responding.

### B. Importing measurements: write path

```text
POST /houses/:id/import
→ HouseImportsController#create
→ for each Consumer: Measurements::Importer
→ Measurements::ApiClient fetches MaLo and MeLo
→ normalize + validate readings
→ transaction + batched insert_all
→ 303 redirect to the house page
```

One consumer's import is transactional. The entire multi-consumer house import is **not** one atomic unit; earlier consumers may succeed before a later consumer fails. The importer reports **processed** readings, not necessarily newly inserted rows.

### Separation of responsibilities

| Component | Responsibility | Explicitly not its responsibility |
| --- | --- | --- |
| `Measurements::ApiClient` | HTTP, timeouts, response errors, JSON parsing and normalization | Database persistence or solar math |
| `Measurements::Importer` | Find location pair, fetch both profiles, validate, batch insert, deduplicate | HTML or reporting calculations |
| `SolarConsumption::Calculator` | Match intervals; calculate daily, consumer, and house summaries | HTTP imports or controller redirects |
| Controllers | Parse request inputs, coordinate services, handle redirects/errors | Business arithmetic or raw import loops |
| ERB/Turbo | Render results and submit forms with conventional Rails navigation | Maintaining a duplicate frontend data model |

## 5. Core calculation — what I learned and verified

Martin clarified that MeLo readings represent total consumption. Under the working interpretation:

```text
Solar consumption for a matched interval = MeLo value − MaLo value
```

For example:

| Interval | MeLo | MaLo | Solar |
| --- | ---: | ---: | ---: |
| 10:00–10:15 | 1.2 | 0.4 | 0.8 |
| 10:15–10:30 | 1.5 | 0.6 | 0.9 |
| 10:30–10:45 | 1.1 | Missing | Excluded |

The query joins the same table using two aliases:

```sql
SELECT
  metering.starts_at,
  metering.value AS metering_value,
  market.value AS market_value
FROM measurements AS metering
INNER JOIN measurements AS market
  ON market.location_id = :market_id
 AND market.starts_at = metering.starts_at
 AND market.ends_at = metering.ends_at
WHERE metering.location_id = :metering_id
  AND metering.starts_at >= :start_time
  AND metering.starts_at < :end_time;
```

`SELECT` determines the returned fields, `JOIN ON` pairs the readings, and `WHERE` selects the correct location and requested timeframe. The timestamp is returned because Ruby needs it to group matched readings into calendar days.

Date filtering uses a **half-open range**: from midnight on the first selected day **inclusive** to midnight after the last selected day **exclusive** (`start_time...end_time`). This includes the final day's readings without relying on end-of-day fractional-second precision. Dates are interpreted in the configured Rails/Berlin time zone; persisted timestamps are compared as instants.

Daily totals are summed from matched intervals; the daily average is the overall total divided by the number of calendar days **with matched readings**, including partially covered days. Units were not explicitly established by the supplied API; I have not assumed that every value is kWh.

## 6. Verification and use of AI-generated tests

I used AI to help design test scenarios and understand RSpec syntax, then ran and debugged those tests in the actual Rails project. The most useful coverage included:

- Model relationships, identifier formats, uniqueness, and valid measurement intervals.
- API normalization and failed HTTP / malformed JSON scenarios.
- Import idempotency, first-write-wins, missing location pairs, upstream failures, and invalid intervals.
- Exact interval matching, date filtering, daily averages, empty datasets, and multiple consumers.
- Request routes, dashboard output, import redirects, and invalid-date feedback.

I learned the difference between `let` and `let!`, verified doubles (`instance_double`), stubs (`allow(...).to receive`), expectations, and request tests. WebMock isolates external HTTP in tests; the real mock API was also exercised manually during integration checks.

A local integration check showed 12,864 market and 12,864 metering rows (25,728 total) at that point in development. The calculator returned 134 days with data and an overall total of approximately 9,631.24 in unspecified measurement units. These are **observations from one local dataset**, not fixed expected outcomes for a nondeterministic mock API.

Passing tests establish the covered behaviors, not complete proof of production readiness. Bulk insert methods bypass normal model validations, so incoming rows need explicit checks and database constraints.

## 7. My role vs. AI's role

**AI was useful for:** Rails/RSpec onboarding, syntax explanations, comparing designs, generating initial example code and tests, surfacing failure scenarios, and acting as a conversational reviewer.

**My contributions and checks included:** choosing a Rails-native solution; questioning whether `upsert_all` was appropriate; testing changing API responses; selecting first-write-wins; prioritizing data integrity; running migrations, the application and test suite; investigating editor/runtime errors; verifying persisted readings and dashboard totals; and deciding which production improvements were outside scope.

I did **not** treat AI suggestions as authoritative. An early suggestion favored upserts; testing the mock API changed that decision. I also rejected unnecessary infrastructure complexity. I remain responsible for understanding and maintaining the submitted implementation.

## 8. Limitations, trade-offs, and follow-up ideas

| Topic | Current decision | Next step if productionized |
| --- | --- | --- |
| Imports | User-triggered, synchronous requests | Background jobs (e.g. Solid Queue), progress reporting, retries and timeouts |
| Duplicates | Unique interval index + `insert_all` | Revision/correction policy with audit history |
| Completeness | Inner join excludes unmatched intervals | Per-day expected interval coverage and missing-data indicators |
| Synchronization | Explicit API `beginDate` | Coverage-aware incremental sync with overlap and backfill |
| Calculations | PostgreSQL self-join, aggregation in Ruby | SQL-side aggregation if scale warrants it; benchmark before optimizing |
| Data quality | Normalized value, interval and quality fields | More comprehensive validation and quality-based inclusion policies |
| Operations | Local Rails app; deployment not claimed | Secure deployment, monitoring, structured logging and alerts |
| Frontend | ERB forms and Turbo-compatible redirects | Consumer daily view, charts, live import feedback if useful |

**Further interview discussion points:** What defines a complete day across daylight-saving transitions? Should an import be atomic for the entire house? What happens with concurrent imports, partial house imports, historical revisions, or negative MeLo − MaLo differences? Should deleting a house cascade to historical energy records? These are consciously identified design questions, not claims that the application already solves them.

## 9. Retrospective

The most valuable part of the challenge was testing assumptions, rather than simply generating Rails code. Three examples stood out: verifying what MaLo/MeLo mean for the calculation, observing changing mock API values before committing to an import policy, and matching exact intervals rather than relying on array order. AI accelerated unfamiliar Rails details, but actual API behavior, database constraints, and test results drove the final design.

Given more time, I would prioritize completeness tracking and asynchronous import observability before adding UI polish or extra infrastructure.

---

### Disclosure note

This document summarizes an AI-assisted engineering workflow. It is intended as **research notes and an explanation of decisions**, not a literal chronological transcript of prompts and responses.
