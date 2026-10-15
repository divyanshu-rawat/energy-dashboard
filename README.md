# VREY — Solar Energy Consumption Dashboard

A Ruby on Rails application for importing, storing, and displaying solar energy consumption for residential houses and their consuming units.

Built with **Ruby on Rails 8, PostgreSQL, Hotwire/Turbo, and RSpec**.

## Features

- Import measurement data from the provided external API using a selectable beginning date.
- Store market location (MaLo) and metering location (MeLo) measurements.
- Calculate solar consumption for individual consumers and entire houses.
- Display total consumption and average daily consumption for a selected date range.
- Prevent duplicate measurements through database constraints and idempotent imports.
- Handle invalid date ranges, missing measurements, and external API errors.
- Provide a lightweight server-rendered dashboard with Rails and Turbo.

## Getting started

### Requirements

- Ruby 3.4.x
- Rails 8.1.x
- PostgreSQL
- Bundler

### Installation

Clone the repository and install dependencies:

```bash
bundle install
```

Configure your local PostgreSQL connection by setting `POSTGRES_PASSWORD`.

For local development, create a `.env` file in the project root:

```dotenv
POSTGRES_PASSWORD=your_postgres_password
```

The `.env` file is Git-ignored and should not be committed.

Prepare the database and load the demonstration data:

```bash
bin/rails db:prepare
bin/rails db:seed
```

Start the application:

```bash
bin/rails server
```

Visit http://localhost:3000.

### Running tests

```bash
bundle exec rspec
```

To check Rails autoloading:

```bash
bin/rails zeitwerk:check
```

## Using the application

1. Open the application and select a house.
2. Choose a beginning date under **Import measurements**.
3. Trigger the import to fetch and persist data for the house's consumers.
4. View the calculated solar consumption totals and daily averages.
5. Use the date-range filter to inspect a particular period.

Imports are explicitly triggered by the user. Viewing or filtering the dashboard reads existing database records without making new API requests.

The seed data includes a demonstration house with one consumer and both required location identifiers.

## Architecture

The application follows Rails MVC with separate services for external API integration, persistence, and calculation.

```text
House
  └── Consumer
       ├── Market Location (MaLo)
       │    └── Measurements
       └── Metering Location (MeLo)
            └── Measurements
```

### Domain models

| Model | Responsibility |
|---|---|
| House | Represents a residential building containing consuming units |
| Consumer | Represents a consuming unit associated with a house |
| Location | Represents a market or metering location and its external identifier |
| Measurement | Stores an interval, measurement value, and quality information |

Database constraints enforce referential integrity, valid intervals, and uniqueness where applicable.

### Services

**`Measurements::ApiClient`**

Handles external HTTP communication, response parsing, error handling, and normalization. It has no knowledge of ActiveRecord or database persistence.

**`Measurements::Importer`**

Coordinates fetching both location profiles, validates normalized records, and persists measurements in batches using PostgreSQL. It is independently testable through an injected API client.

**`SolarConsumption::Calculator`**

Matches readings by their start and end timestamps, calculates solar consumption, and aggregates results by day, consumer, and house.

### Controllers and views

- `HousesController` — house listing, date filtering, and consumption summaries.
- `HouseImportsController` — explicitly triggered measurement imports.
- ERB views with Rails forms and Turbo-compatible redirects.

Controllers remain lightweight; business calculations and import persistence are handled by dedicated services.

## Calculation assumptions

Based on the clarification that metering location (MeLo) readings represent total consumption, the application uses:

```text
Solar consumption = MeLo − MaLo
```

MaLo is assumed to represent the non-solar/grid-consumption component for this calculation.

Measurements are matched using both `starts_at` and `ends_at`. Intervals missing a corresponding reading are excluded rather than treated as zero.

**Daily average** is defined as:

```text
Total calculated solar consumption
÷
Number of calendar days with matched readings
```

Daily totals are grouped using the configured Berlin timezone.

The average includes days with partial coverage. It therefore represents the average across days with matched readings, not necessarily an average across complete 24-hour days.

The source API does not explicitly document a measurement unit, so the interface uses neutral measurement-unit labels rather than asserting kWh.

## Import strategy and idempotency

The external mock API was observed returning different values for identical measurement intervals across repeated requests.

To provide stable, reproducible dashboard values, the importer uses a **first-write-wins** policy:

- Records are uniquely identified by location, start timestamp, and end timestamp.
- Bulk insertion uses `insert_all`.
- Existing intervals are skipped rather than overwritten.
- New intervals are inserted.
- The database unique index protects against duplicates.
- Both location profiles are fetched before persistence begins.
- Database writes for a consumer's import run inside a transaction.

Imports are processed in batches to avoid individual INSERT operations for every reading.

This policy is a pragmatic choice for the challenge. A production energy-data platform would need an explicit strategy for corrected measurements, revisions, and reconciliation.

The API exposes a `beginDate` parameter. The application uses it to request readings from the selected beginning date; it does not currently implement automatic incremental synchronization.

## Testing

RSpec covers the main layers of the application:

- Model validations and domain relationships.
- Location identifier formats and uniqueness.
- Measurement time-interval validation.
- API response normalization and HTTP error handling.
- Import deduplication, first-write-wins behavior, and failure handling.
- Interval matching, solar calculations, date filtering, and house aggregation.
- Dashboard rendering and import request handling.

External HTTP requests are mocked in automated tests to keep the suite deterministic.

## Engineering decisions

### Rails MVC with Turbo

Rails provides the relational persistence, request handling, templates, and standard application conventions needed for this exercise without maintaining a separate frontend and backend.

Turbo enables conventional Rails forms and redirects without introducing a larger client-side state-management layer.

### PostgreSQL and data integrity

Foreign keys, unique indexes, and interval check constraints protect important invariants at the database layer.

### Separate API, import, and calculation services

The API client, importer, and calculator have distinct responsibilities. This makes their behavior easier to test independently and avoids coupling HTTP requests or domain calculations to controllers.

### Bulk insertion

Bulk inserts reduce database round trips for the large number of 15-minute measurements returned by the mock API.

### Synchronous imports

Imports currently run during a user request. This is sufficient for a small demonstration but can result in long response times for larger datasets or slow upstream API calls.

## Limitations and future improvements

Given more time, I would prioritize:

1. **Import jobs and observability:** Move imports to background jobs, track import status, and add structured logs, metrics, retries, and error reporting.
2. **Data completeness:** Identify missing intervals, incomplete days, and measurement quality issues rather than reporting only the matched portion.
3. **Measurement corrections:** Introduce an explicit revision or reconciliation policy instead of assuming the first reading is authoritative.
4. **Daily consumer view:** Display per-day consumption and potentially a chart for each consuming unit.
5. **Incremental synchronization:** Track imported coverage and request only necessary periods, with overlap to handle partial imports safely.
6. **Performance:** Consider database-level aggregation and pagination or streaming for larger datasets.
7. **Deployment:** Deploy the application with managed PostgreSQL, centralized monitoring, secure environment configuration, and automated checks.

These are potential improvements, not features included in the current implementation.

## Retrospective

The main focus was delivering the required functionality while keeping the implementation understandable and maintainable.

Separating the HTTP client, persistence workflow, and consumption calculator helped keep responsibilities clear and allowed each component to be tested independently.

An interesting challenge was the external API returning changing values for previously requested intervals. That influenced the decision to preserve the first imported measurement rather than overwrite historical results unpredictably.

Matching measurements by timestamps, rather than array positions, was another important decision because missing readings should not accidentally be paired with the wrong intervals.

With additional time, I would focus first on import observability and data completeness rather than expanding the frontend. Those improvements would have a greater impact on the reliability of an actual energy-data application.