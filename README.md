# Bravida — Analytics Engineer Case Study

A small dbt + DuckDB project. Your job is to model the Olist e-commerce data to
answer a business question. See the case brief you were sent for the full task;
this README is just how to get running.

## What's here

```
data/                 raw Olist CSVs (already included, no download needed)
load_olist.py         loads the CSVs into a local DuckDB file under schema `raw`
dbt_project.yml       dbt project config
profiles.yml          local DuckDB profile (no warehouse / credentials needed)
packages.yml          dbt_utils
models/
  staging/
    _sources.yml      the raw sources, with grain notes and warnings — read these
    stg_orders.sql    WORKED EXAMPLE: the house style for staging. Match it.
    _stg_orders.yml   tests + docs for the worked example
  marts/              empty — your fact and dimension models go here
```

## Setup (about 5 minutes)

You need Python 3.9+ and pip.

```bash
pip install dbt-duckdb
python load_olist.py                 # builds olist.duckdb with a `raw` schema
DBT_PROFILES_DIR=. dbt deps
DBT_PROFILES_DIR=. dbt build         # stg_orders builds, 2 tests pass
```

If that last command succeeds you are ready. The `models.bravida_case.marts`
warning is expected and disappears once you add your first marts model.

> Tip: rather than prefix every command, you can `export DBT_PROFILES_DIR=.` once
> per shell, or copy `profiles.yml` to `~/.dbt/profiles.yml`.

## The task, in one line

Model delivery performance and order value by seller and by region, and surface
where delivery slips against promised dates. Build staging models for what you
need, at least one well-grained fact plus its dimensions, tests and docs on the
key models, and a short note on the decisions you made and the ones you deferred.

## Ground rules

- Max 4 hours. A focused, correct core beats a sprawling project.
- AI tools encouraged. Be ready to say where they helped and where you overrode them.
- Not production-grade. Rough edges are fine if you can talk to them.

## Inspecting the warehouse directly (optional)

```bash
python -c "import duckdb; c=duckdb.connect('olist.duckdb'); print(c.sql('show all tables'))"
```
