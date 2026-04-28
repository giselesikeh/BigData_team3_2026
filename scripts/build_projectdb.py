import os
import time
import multiprocessing
from pathlib import Path

import psycopg2 as psql


# ── CONFIG ─────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parents[1]

DATA_CSV = REPO_ROOT / "data" / "US_Accidents_March23.csv"
SQL_CREATE_CORE = REPO_ROOT / "sql" / "create_tables.sql"
SQL_IMPORT_LOAD = REPO_ROOT / "sql" / "import_data.sql"
SQL_TEST = REPO_ROOT / "sql" / "test_database.sql"
PASSWORD_FILE = REPO_ROOT / "secrets" / ".psql.pass"

# team3 database connection
PASSWORD = PASSWORD_FILE.read_text(encoding="utf-8").strip()
CONN_STR = (
    "host=hadoop-04.uni.innopolis.ru "
    "port=5432 "
    "user=team3 "
    f"dbname=team3_projectdb password={PASSWORD}"
)

# staging COPY statement
COPY_FROM_STDIN = """
COPY staging_raw
FROM STDIN
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    NULL '',
    QUOTE '"',
    ESCAPE '"',
    ENCODING 'UTF8'
);
"""


# ── HELPERS ────────────────────────────────────────────────────────
def sanitize_sql(sql_text: str) -> str:
    """
    Remove top-level transaction statements so Python controls transactions.
    """
    lines = []
    for line in sql_text.splitlines():
        stripped = line.strip().rstrip(";").upper()
        if stripped in {"BEGIN", "START TRANSACTION", "COMMIT"}:
            continue
        lines.append(line)
    return "\n".join(lines).strip()


def run_sql(cur, path: Path) -> None:
    print(f"\nRunning SQL from: {path.name}")
    start_time = time.time()

    sql_text = path.read_text(encoding="utf-8")
    sql_text = sanitize_sql(sql_text)

    if sql_text:
        cur.execute(sql_text)

    elapsed = time.time() - start_time
    print(f"Completed {path.name} in {elapsed:.2f} seconds")


def run_test_queries(cur, path: Path) -> None:
    print(f"\nRunning test queries from: {path.name}")
    content = path.read_text(encoding="utf-8")
    queries = [q.strip() for q in content.split(";") if q.strip()]

    for i, query in enumerate(queries, start=1):
        print(f"\n--- Test query {i} ---")
        cur.execute(query)
        rows = cur.fetchall()
        for row in rows:
            print(row)


def file_check() -> None:
    required = [DATA_CSV, SQL_CREATE_CORE, SQL_IMPORT_LOAD, SQL_TEST, PASSWORD_FILE]
    for path in required:
        if not path.exists():
            raise FileNotFoundError(f"Required file not found: {path}")


# ── MAIN ───────────────────────────────────────────────────────────
def main():
    file_check()

    cores = multiprocessing.cpu_count()
    print(f"System has {cores} CPU cores")
    print("Starting database build process...")

    start_time = time.time()

    # estimate memory-based tuning values
    try:
        system_memory_mb = int(
            os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES") / (1024.0 ** 2)
        )
    except Exception:
        system_memory_mb = 4096  # fallback

    work_mem = min(max(256, system_memory_mb // 8), 1024)              # 256MB–1GB
    maintenance_work_mem = min(max(512, system_memory_mb // 4), 2048)  # 512MB–2GB

    with psql.connect(CONN_STR) as conn:
        conn.autocommit = False

        with conn.cursor() as cur:
            print("Connected to PostgreSQL.")

            # 1. performance settings
            print("\nSetting PostgreSQL performance parameters...")
            cur.execute("SET synchronous_commit = OFF;")
            cur.execute(f"SET work_mem = '{work_mem}MB';")
            cur.execute(f"SET maintenance_work_mem = '{maintenance_work_mem}MB';")
            cur.execute("SET effective_io_concurrency = 8;")
            cur.execute(f"SET max_parallel_workers_per_gather = {min(4, max(1, cores // 2))};")
            cur.execute("SET random_page_cost = 1.1;")
            cur.execute("SET effective_cache_size = '4GB';")

            # 2. create schema + staging table + dimensions/fact tables
            run_sql(cur, SQL_CREATE_CORE)
            conn.commit()
            print("Schema creation completed.")

            # 3. bulk load CSV into staging_raw
            print(f"\nLoading data from: {DATA_CSV.name}")
            copy_start = time.time()
            buffer_size = 16 * 1024 * 1024  # 16MB buffer

            with DATA_CSV.open("r", encoding="utf-8", errors="replace", buffering=buffer_size) as f:
                cur.copy_expert(COPY_FROM_STDIN, f)

            conn.commit()
            copy_elapsed = time.time() - copy_start
            print(f"CSV copied into staging_raw in {copy_elapsed:.2f} seconds")

            # 4. help planner
            print("\nAnalyzing staging_raw...")
            cur.execute("ANALYZE staging_raw;")
            conn.commit()

            # 5. normalize into dimension/fact tables
            run_sql(cur, SQL_IMPORT_LOAD)
            conn.commit()
            print("Normalization completed.")

            # 6. final analyze
            print("\nRunning final ANALYZE...")
            cur.execute("ANALYZE;")
            conn.commit()

            # 7. run test queries
            run_test_queries(cur, SQL_TEST)

            # 8. show resulting tables
            print("\nTables present after load:")
            cur.execute("""
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = 'public'
                ORDER BY table_name;
            """)
            for (tbl,) in cur.fetchall():
                print(f"  • {tbl}")

            # 9. show table sizes
            print("\nTable sizes:")
            cur.execute("""
                SELECT
                    relname AS table_name,
                    pg_size_pretty(pg_total_relation_size(relid)) AS total_size
                FROM pg_catalog.pg_statio_user_tables
                ORDER BY pg_total_relation_size(relid) DESC;
            """)
            for table_name, size in cur.fetchall():
                print(f"  • {table_name}: {size}")

    total_elapsed = time.time() - start_time
    print(f"\nDatabase build finished successfully in {total_elapsed:.2f} seconds "
          f"(~{total_elapsed/60:.2f} minutes)")


if __name__ == "__main__":
    os.environ["PYTHONUNBUFFERED"] = "1"
    main()
