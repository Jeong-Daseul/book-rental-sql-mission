"""schema + seed 스크립트로 db/library.db 를 새로 만든다.
사용법: python scripts/build_db.py
"""
import sqlite3
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "db" / "library.db"
SCHEMA_PATH = ROOT / "sql" / "01_schema.sql"
SEED_PATH = ROOT / "sql" / "02_seed.sql"


def main():
    DB_PATH.parent.mkdir(exist_ok=True)
    if DB_PATH.exists():
        DB_PATH.unlink()

    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA foreign_keys = ON;")

    con.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
    con.executescript(SEED_PATH.read_text(encoding="utf-8"))
    con.commit()

    print("테이블별 행 수:")
    for table in ["category", "book", "member", "rental"]:
        cnt = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"  {table}: {cnt}")

    con.close()
    print(f"\n생성 완료 -> {DB_PATH}")


if __name__ == "__main__":
    main()
