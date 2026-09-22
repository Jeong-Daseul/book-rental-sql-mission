"""03_queries.sql의 각 쿼리를 순서대로 실행하고 결과를 results/ 폴더에
쿼리 1개당 텍스트 파일 1개로 저장한다 (스크린샷을 대신하는 실행 결과 텍스트).

사용법: python scripts/run_queries.py
주의: DB 상태를 바꾸는 쿼리(UPDATE/DELETE)가 포함되어 있으므로,
      재실행하려면 먼저 `python scripts/build_db.py` 로 DB를 초기화한다.
"""
import sqlite3
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "db" / "library.db"
RESULTS_DIR = ROOT / "results"

# (파일명, 한 줄 설명, 실행할 SQL 문 리스트 - 여러 문이면 순서대로 함께 기록)
QUERIES = [
    ("01_basic_top5_expensive_book",
     "[기본조회] 정가 15000원 이상 도서, 가격 높은 순 상위 5개 (WHERE+ORDER BY+LIMIT)",
     ["SELECT title, author, price FROM book WHERE price >= 15000 ORDER BY price DESC LIMIT 5;"]),

    ("02_basic_currently_rented",
     "[기본조회] 현재 대여 중(미반납)인 책 목록 (WHERE)",
     ["SELECT rental_id, member_id, book_id, rental_date, due_date FROM rental WHERE return_date IS NULL ORDER BY due_date;"]),

    ("03_basic_search_title",
     "[기본조회] 제목에 '사람'이 포함된 도서, 가격 낮은 순 검색 (WHERE LIKE + ORDER BY)",
     ["SELECT title, author, price FROM book WHERE title LIKE '%사람%' ORDER BY price ASC;"]),

    ("04_basic_recent_rentals",
     "[기본조회] 최근 30일 이내 대여 기록을 최신순으로 조회 (WHERE 날짜 + ORDER BY)",
     ["SELECT rental_id, member_id, book_id, rental_date, status FROM rental WHERE rental_date >= date('now', '-30 day') ORDER BY rental_date DESC;"]),

    ("05_join_rental_with_member",
     "[조인] 대여기록 + 회원 이름 (INNER JOIN, 최신 10건)",
     ["""SELECT r.rental_id, m.name AS member_name, r.rental_date, r.status
         FROM rental r INNER JOIN member m ON m.member_id = r.member_id
         ORDER BY r.rental_date DESC LIMIT 10;"""]),

    ("06_join_rental_detail_3tables",
     "[조인] 대여기록+도서+카테고리 3테이블 조인 (INNER JOIN x2, 15건)",
     ["""SELECT r.rental_id, b.title, cat.name AS category_name,
                r.rental_date, r.due_date, r.status
         FROM rental r
         INNER JOIN book b ON b.book_id = r.book_id
         INNER JOIN category cat ON cat.category_id = b.category_id
         ORDER BY r.rental_id LIMIT 15;"""]),

    ("07_join_book_by_category",
     "[조인] 카테고리별 도서 목록 (INNER JOIN)",
     ["""SELECT cat.name AS category_name, b.title, b.price
         FROM book b INNER JOIN category cat ON cat.category_id = b.category_id
         ORDER BY cat.name, b.price;"""]),

    ("08_leftjoin_rental_count_per_member",
     "[조인] 전체 회원의 대여 건수 (대여 0건 회원도 포함, LEFT JOIN)",
     ["""SELECT m.member_id, m.name, COUNT(r.rental_id) AS rental_count
         FROM member m LEFT JOIN rental r ON r.member_id = m.member_id
         GROUP BY m.member_id, m.name ORDER BY rental_count ASC;"""]),

    ("09_agg_rental_count_per_member",
     "[집계] 회원별 대여 횟수 집계 (COUNT + GROUP BY)",
     ["""SELECT m.name, COUNT(r.rental_id) AS rental_count
         FROM member m INNER JOIN rental r ON r.member_id = m.member_id
         GROUP BY m.member_id, m.name ORDER BY rental_count DESC;"""]),

    ("10_agg_rentals_and_overdue_per_book",
     "[집계] 도서별 총 대여횟수/연체 발생횟수, 대여 많은 순 (COUNT+SUM + GROUP BY)",
     ["""SELECT b.title, COUNT(r.rental_id) AS total_rentals,
                SUM(CASE WHEN r.return_date IS NULL AND r.due_date < date('now') THEN 1 ELSE 0 END) AS overdue_count
         FROM rental r INNER JOIN book b ON b.book_id = r.book_id
         GROUP BY b.book_id, b.title ORDER BY total_rentals DESC LIMIT 10;"""]),

    ("11_agg_avg_price_per_category",
     "[집계] 카테고리별 평균 도서 정가 (AVG + GROUP BY)",
     ["""SELECT cat.name AS category_name, ROUND(AVG(b.price), 0) AS avg_price,
                COUNT(b.book_id) AS book_count
         FROM book b INNER JOIN category cat ON cat.category_id = b.category_id
         GROUP BY cat.category_id, cat.name ORDER BY avg_price DESC;"""]),

    ("12_subquery_above_average_price",
     "[서브쿼리] 전체 평균가보다 비싼 도서",
     ["SELECT title, price FROM book WHERE price > (SELECT AVG(price) FROM book) ORDER BY price DESC;"]),

    ("13_subquery_members_without_rentals",
     "[서브쿼리] 대여 기록이 없는 회원 (NOT IN)",
     ["SELECT member_id, name, phone FROM member WHERE member_id NOT IN (SELECT DISTINCT member_id FROM rental);"]),

    ("14_update_mark_overdue",
     "[수정] 기한이 지났는데 미반납인 대여 건을 OVERDUE로 일괄 업데이트 후 상태별 건수 확인",
     ["UPDATE rental SET status = 'OVERDUE' WHERE status = 'RENTED' AND return_date IS NULL AND due_date < date('now');",
      "SELECT status, COUNT(*) AS cnt FROM rental GROUP BY status;"]),

    ("15_delete_rental_record",
     "[삭제] 불필요한 대여 기록(rental_id=32) 삭제 후 사라졌는지 확인",
     ["DELETE FROM rental WHERE rental_id = 32;",
      "SELECT * FROM rental WHERE rental_id = 32;"]),

    ("16_index_rental_member_book",
     "[인덱스] rental(member_id), rental(book_id) 인덱스 생성 후 sqlite_master로 확인 - 회원/도서별 조회·조인이 잦아 FK 컬럼에 인덱스 필요",
     ["CREATE INDEX IF NOT EXISTS idx_rental_member_id ON rental(member_id);",
      "CREATE INDEX IF NOT EXISTS idx_rental_book_id ON rental(book_id);",
      "SELECT name, tbl_name, sql FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%';"]),

    ("17_bonus_join_vs_subquery_A_join",
     "[보너스-비교 A] 대여된 적 있는 도서 목록을 JOIN+DISTINCT로 조회",
     ["""SELECT DISTINCT b.book_id, b.title FROM book b
         INNER JOIN rental r ON r.book_id = b.book_id ORDER BY b.book_id;"""]),

    ("18_bonus_join_vs_subquery_B_subquery",
     "[보너스-비교 B] 같은 결과를 서브쿼리(IN)로 조회 - A와 결과 동일함을 비교",
     ["SELECT book_id, title FROM book WHERE book_id IN (SELECT DISTINCT book_id FROM rental) ORDER BY book_id;"]),

    ("19_bonus_fk_violation_demo",
     "[보너스-정합성] 존재하지 않는 category_id=999 참조 INSERT 시도 -> FK 위반으로 실패해야 정상",
     ["INSERT INTO book (category_id, title, author, isbn, price) VALUES (999, '존재하지않는분류 도서', '익명', '979-11-0000-000-0', 10000);"]),

    ("20_bonus_kpi_monthly_rentals",
     "[보너스-미니리포트 KPI1] 월별 대여 건수 추이",
     ["SELECT strftime('%Y-%m', rental_date) AS rental_month, COUNT(*) AS rental_count FROM rental GROUP BY rental_month ORDER BY rental_month;"]),

    ("21_bonus_kpi_top10_book",
     "[보너스-미니리포트 KPI2] 대여 횟수 기준 인기 도서 TOP10",
     ["""SELECT b.title, COUNT(r.rental_id) AS rental_count
         FROM rental r INNER JOIN book b ON b.book_id = r.book_id
         GROUP BY b.book_id, b.title ORDER BY rental_count DESC LIMIT 10;"""]),

    ("22_bonus_kpi_high_overdue_rate_members",
     "[보너스-미니리포트 KPI3] 연체율이 높은 회원 목록",
     ["""SELECT m.name, COUNT(r.rental_id) AS total_rentals,
                SUM(CASE WHEN r.return_date IS NULL AND r.due_date < date('now') THEN 1 ELSE 0 END) AS overdue_rentals,
                ROUND(100.0 * SUM(CASE WHEN r.return_date IS NULL AND r.due_date < date('now') THEN 1 ELSE 0 END)
                      / COUNT(r.rental_id), 1) AS overdue_rate_pct
         FROM member m INNER JOIN rental r ON r.member_id = m.member_id
         GROUP BY m.member_id, m.name HAVING overdue_rentals > 0
         ORDER BY overdue_rate_pct DESC;"""]),
]


def format_rows(cursor, rows):
    if cursor.description is None:
        return f"(영향받은 행 수: {cursor.rowcount})\n"
    cols = [d[0] for d in cursor.description]
    if not rows:
        return "(결과 없음 - 0 rows)\n"
    widths = [max(len(str(c)), max((len(str(r[i])) for r in rows), default=0)) for i, c in enumerate(cols)]
    lines = []
    header = " | ".join(str(c).ljust(widths[i]) for i, c in enumerate(cols))
    lines.append(header)
    lines.append("-+-".join("-" * w for w in widths))
    for r in rows:
        lines.append(" | ".join(str(v).ljust(widths[i]) for i, v in enumerate(r)))
    lines.append(f"\n({len(rows)} rows)")
    return "\n".join(lines) + "\n"


def main():
    RESULTS_DIR.mkdir(exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA foreign_keys = ON;")

    index_lines = ["# 쿼리 실행 결과 목록\n"]

    for fname, desc, stmts in QUERIES:
        out_path = RESULTS_DIR / f"{fname}.txt"
        out = [f"-- {desc}", ""]
        for i, stmt in enumerate(stmts):
            out.append(f"$ sqlite> {' '.join(stmt.split())}")
            try:
                cur = con.execute(stmt)
                rows = cur.fetchall() if cur.description is not None else []
                out.append(format_rows(cur, rows))
                con.commit()
            except sqlite3.Error as e:
                out.append(f"[ERROR] {type(e).__name__}: {e}\n")
                con.rollback()
            out.append("")
        out_path.write_text("\n".join(out), encoding="utf-8")
        index_lines.append(f"- `{fname}.txt` : {desc}")
        print(f"saved {out_path.name}")

    (RESULTS_DIR / "README.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")
    con.close()
    print("\n모든 쿼리 실행 완료 -> results/ 폴더 확인")


if __name__ == "__main__":
    main()
