# media-broadcasting-data-pro

An **OLTP data model for a multi-country OTT streaming service** (SVOD + AVOD + TVOD). It is documented at three levels (conceptual, logical, physical) and implemented as **PostgreSQL** DDL, **SQLAlchemy 2.0** models and **Alembic** migrations, with a **pytest** suite.

## Documentation

| Level | Document | Contents |
|---|---|---|
| Conceptual | [docs/01_conceptual_model.md](docs/01_conceptual_model.md) | Business context, subject areas, core concepts, high-level ER diagram, business rules, scope |
| Logical | [docs/02_logical_model.md](docs/02_logical_model.md) | 63 entities with attributes and logical types, identifiers and alternate keys, ER diagrams per domain, enumerations, business-rule matrix, normalization notes |
| Physical | [docs/03_physical_model.md](docs/03_physical_model.md) | PostgreSQL schemas, ENUM types, naming standard, soft-delete strategy, integrity techniques, indexing, partitioning, security, physical ER diagrams, full table catalog |
| Simulation | [docs/04_simulation.md](docs/04_simulation.md) | Realistic fake data calibrated on public historical data: presets, sources, validity guarantees, calibration check |

All diagrams are [Mermaid](https://mermaid.js.org/). They render natively on GitHub, GitLab and in VS Code's Markdown preview (with a Mermaid extension).

## Scope at a glance

```mermaid
flowchart LR
    REF[(ref)] --- CONTENT[content] & SUBSCRIBER[subscriber] & BILLING[billing] & RIGHTS[rights]
    PARTNER[partner] --> RIGHTS --> CONTENT
    PARTNER --> TALENT[talent] --> CONTENT
    SUBSCRIBER --> BILLING --> CONTENT
    SUBSCRIBER --> PLAYBACK[playback] --> CONTENT
    ADSALES[adsales] --> PLAYBACK
```

| Domain (schema) | Tables | Highlights |
|---|---|---|
| `ref` | 5 | Countries, territories, languages, currencies |
| `partner` | 2 | Studios, distributors, production companies, agencies |
| `content` | 15 | Movies / series / seasons / episodes / live events / extras, localization, per-country maturity ratings, media assets with audio & subtitle tracks, live channels + EPG |
| `talent` | 6 | People, credits, contracts, compensation, residuals |
| `rights` | 6 | License agreements, territory × monetization windows, royalty terms & statements |
| `subscriber` | 4 | Accounts, addresses, multiple profiles (incl. kids), devices |
| `billing` | 14 | Plans with stream/device/quality limits, per-country prices, trials, promotions, tokenized payment methods, subscriptions, TVOD rent/buy, invoices with country tax, payments, refunds |
| `playback` | 4 | Viewing sessions, resume points, watchlist, ratings |
| `adsales` | 7 | Advertisers, campaigns, insertion orders, creatives, targeting, ad breaks, impressions |

## Design decisions

All of these were confirmed in the requirements interview:

| Topic | Decision |
|---|---|
| Business | OTT streaming, multi-country |
| Monetization | SVOD + AVOD (ad tier) + TVOD (rent & buy) |
| Database | PostgreSQL 13+ |
| Keys | UUID surrogate keys (`gen_random_uuid()`) |
| Organization | One schema per domain |
| Code lists | PostgreSQL `ENUM` types |
| Common columns | Soft delete only: `is_deleted`, `deleted_at` |
| Payments | Gateway token + display data only (PCI-DSS) |
| Playback detail | Session + resume point (no heartbeat events) |
| Pricing / tax | Price per plan × country × currency × period; tax rate per country |

## Quick start

Requirements: [uv](https://docs.astral.sh/uv/) (it installs Python 3.12 itself), PostgreSQL 13+, and Docker for the tests.

```bash
uv sync                                   # create .venv from uv.lock (runtime + dev tools)
export DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/ott

uv run alembic upgrade head               # create the schema (Alembic revision 0001)
uv run ott-seed                           # optional: load the demo dataset (124 rows, all 63 tables)
```

To build the database without Python, use the single SQL file:

```bash
createdb ott
psql -v ON_ERROR_STOP=1 -d ott -f database.sql
```

`database.sql` is generated from `ddl/` (`uv run ott-build-sql`); do not edit it by hand.

## Python project

| Path | What it is |
|---|---|
| `pyproject.toml`, `uv.lock` | Project metadata and the locked dependency set (SQLAlchemy 2, psycopg 3, Alembic; dev: pytest, Testcontainers, ruff, pre-commit) |
| `src/media_broadcasting/models/` | SQLAlchemy 2.0 ORM models: one module per schema, `enums.py` for the 34 ENUM types, and `base.py` for `Base` + `SoftDeleteMixin` |
| `src/media_broadcasting/db.py` | Engine / session factory from `DATABASE_URL` |
| `src/media_broadcasting/database_sql.py` | `ott-build-sql`: builds `database.sql` from `ddl/` (`--check` for CI) |
| `src/media_broadcasting/seed.py` | `ott-seed`: fictional demo data covering every table |
| `alembic.ini`, `migrations/` | Alembic environment. `0001_initial_schema` applies a frozen copy of `database.sql` |
| `tests/` | pytest suite against PostgreSQL 16 in Testcontainers |
| `.pre-commit-config.yaml`, `.github/workflows/ci.yml` | ruff lint/format, `database.sql` sync check, tests on every push / PR |

```bash
uv run pytest                 # 130 tests, needs Docker running
uv run ruff check . && uv run ruff format --check .
uv run pre-commit install     # run the same checks on every commit
```

**Changing the schema:** edit the model and run `uv run alembic revision --autogenerate -m "..."`. Review the revision and add any CHECKs or expression indexes by hand. Mirror the change in `ddl/`, then run `uv run ott-build-sql` and `uv run ott-systems build`. The tests fail if the DDL, `database.sql`, the migrations, the models and the system artifacts drift apart (see [physical model §8a](docs/03_physical_model.md#8a-implementation-artifacts-and-how-they-stay-in-sync)).

## System databases and mapping

The central model is also split into **eight operational system databases**. Each has its own conceptual, logical and physical docs, `ddl.sql` and consistent `seed.sql`:

| System | Owns |
|---|---|
| [`media_ops_db`](systems/media_ops_db) | Catalog, media assets, tracks, live channels, EPG (15 tables) |
| [`rights_mgmt_db`](systems/rights_mgmt_db) | Licensing, windows, royalties, talent credits/contracts/residuals (12) |
| [`crm_db`](systems/crm_db) | Partners and partner contacts (2) |
| [`streaming_platform_db`](systems/streaming_platform_db) | Accounts, profiles, devices, plans, subscriptions, promotions, TVOD, playback (17) |
| [`erp_db`](systems/erp_db) | Invoices, payments, refunds, tax rates (5) + **master of reference data** |
| [`ad_server_db`](systems/ad_server_db) | Advertisers, campaigns, IOs, creatives, targeting, breaks, impressions (7) |
| [`cdp_db`](systems/cdp_db) | *New:* customer profiles, identity links, consent, events, segments (6) |
| [`work_mgmt_db`](systems/work_mgmt_db) | *New:* users, projects, tasks, dependencies, status history, comments (6) |

- **[systems/](systems/README.md)**: the landscape, plus one folder per database.
- **[mapping/](mapping/README.md)**: table allocation and the 34 cross-system *soft references* (foreign keys that cannot span databases), as Markdown, YAML and CSV, with Mermaid lineage diagrams.
- **[etl/](etl)**: executable `postgres_fdw` SQL for *migration* (central → each system) and *consolidation* (systems → central). Both are re-runnable upserts.

```bash
uv run ott-systems build                         # regenerate systems/, mapping/, etl/ (no DB needed)
uv run ott-systems migrate     --server-url URL  # central_db -> the eight systems
uv run ott-systems consolidate --server-url URL  # the eight systems -> central_db
uv run ott-systems seeds       --server-url URL  # regenerate systems/*/seed.sql
```

## Simulated data

`ott-simulate` generates realistic fake data for the central database and all 8 system databases. It is calibrated on the IMDb open-dataset aggregates and on cited industry statistics (Antenna churn, Netflix regional prices and member mix, Ad Age CPMs). It has four presets: `tiny`, `small`, `medium` and `large`. See [docs/04_simulation.md](docs/04_simulation.md) and [data/calibration/SOURCES.md](data/calibration/SOURCES.md).

```bash
uv run ott-simulate --preset small --server-url postgresql+psycopg://postgres:pw@localhost:5432/postgres
```

## Verification performed

- **130 tests pass** on PostgreSQL 16 (Testcontainers):
  - `database.sql` is in sync with `ddl/` and builds 9 schemas, 34 ENUM types and 63 tables.
  - `alembic upgrade head` produces exactly the same catalog as `database.sql` (columns, constraints, indexes, enums).
  - Alembic autogenerate finds **no difference** between the ORM models and the migrated database.
  - Downgrade → upgrade round trip.
  - Every table has a UUID PK, soft-delete columns and its soft-delete CHECK. The Python enums match the PostgreSQL enum labels.
  - The seed fills all 63 tables and refuses to run twice.
  - 25 invalid changes are each rejected by the intended constraint.
  - **System databases:**
    - every central table has exactly one system of record;
    - each system's DDL keeps the central structure (columns, CHECKs, indexes), minus only the cross-system FKs;
    - the migration copies every row;
    - the seed files reproduce exactly and load on their own;
    - all soft references resolve across databases;
    - ETL re-runs change nothing;
    - consolidation rebuilds a central database identical, row for row, to the original;
    - the cdp/work tables enforce their rules.
- End to end: `alembic upgrade head`, `ott-seed` and `alembic check` ("No new upgrade operations detected") against a fresh container.
- All 66 Mermaid diagrams were checked with the Mermaid 11 parser.

## Repository layout

```
.
├── README.md
├── pyproject.toml / uv.lock / .python-version
├── database.sql                 # generated: consolidated DDL
├── alembic.ini
├── ddl/                         # source DDL, one file per schema
├── docs/                        # conceptual / logical / physical models
├── migrations/
│   ├── env.py
│   └── versions/0001_initial_schema.py (+ .sql)
├── systems/                     # generated: one folder per system database
│   ├── README.md                #   landscape
│   └── <db>/ddl.sql, seed.sql, docs/01..03_*.md
├── mapping/                     # generated: README, table_mapping.md, mapping.yaml,
│                                #   column_mapping.csv, cross_system_references.csv
├── etl/                         # generated: migrate/<db>.sql, consolidate/central_db.sql
├── src/media_broadcasting/
│   ├── models/                  # base, enums, ref, partner, content, talent, rights,
│   │                            # subscriber, billing, playback, adsales
│   ├── systems/                 # registry, cdp/work_mgmt tables, generators, ETL pipeline
│   ├── db.py
│   ├── database_sql.py
│   ├── ids.py                   # deterministic seed ids
│   └── seed.py
├── tests/                       # conftest + 6 test modules
└── .github/workflows/ci.yml
```

## Reference

Domain vocabulary was cross-checked against the Databricks [lakehouse-industry-data-models › media_broadcasting › v2 › mvm](https://github.com/databricks-industry-solutions/lakehouse-industry-data-models/tree/main/data-models/media_broadcasting/v2/mvm) model. This project is an independent OLTP design for OTT and does not copy that model; the differences are listed in [the conceptual model, §7](docs/01_conceptual_model.md#7-reference-model-and-how-this-model-differs).
