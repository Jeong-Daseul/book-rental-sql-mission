-- ============================================================
-- 도서 대여 관리 데이터베이스 - 핵심 쿼리 모음
-- 실행 순서: 01_schema.sql, 02_seed.sql 실행 후 이 파일을 실행한다.
-- 각 쿼리 위에 "무엇을 확인하는 쿼리인지" 한 줄 설명을 붙였다.
-- 실행 결과 캡처는 results/ 폴더 참고.
-- 참고: return_date IS NULL 이면 아직 반납 전(대여중), 그중 due_date < 오늘이면 연체 상태다.
--       status 컬럼은 배치 작업(Q14)이 실행되기 전까지는 부정확할 수 있다는 점을 의도적으로 재현했다.
-- ============================================================

PRAGMA foreign_keys = ON;

-- ============================================================
-- [1] 기본 조회 (WHERE / ORDER BY / LIMIT)
-- ============================================================

-- Q1. 정가 15000원 이상인 도서를 가격 높은 순으로 상위 5개 조회
SELECT title, author, price
FROM book
WHERE price >= 15000
ORDER BY price DESC
LIMIT 5;

-- Q2. 현재 대여 중인(아직 반납하지 않은) 책 목록 조회
SELECT rental_id, member_id, book_id, rental_date, due_date
FROM rental
WHERE return_date IS NULL
ORDER BY due_date;

-- Q3. 제목에 '사람'이 들어간 도서를 가격 낮은 순으로 검색
SELECT title, author, price
FROM book
WHERE title LIKE '%사람%'
ORDER BY price ASC;

-- Q4. 최근 30일 이내 대여 기록을 최신순으로 조회
SELECT rental_id, member_id, book_id, rental_date, status
FROM rental
WHERE rental_date >= date('now', '-30 day')
ORDER BY rental_date DESC;

-- ============================================================
-- [2] 조인 (INNER JOIN 2개 이상 / LEFT JOIN 1개 이상)
-- ============================================================

-- Q5. 대여 기록에 대여한 회원 이름을 함께 조회 (INNER JOIN)
SELECT r.rental_id, m.name AS member_name, r.rental_date, r.status
FROM rental r
INNER JOIN member m ON m.member_id = r.member_id
ORDER BY r.rental_date DESC
LIMIT 10;

-- Q6. 대여기록 + 도서 + 카테고리를 조인해 "누가 어떤 분류의 책을 빌렸는지" 조회 (INNER JOIN x2)
SELECT r.rental_id, b.title, cat.name AS category_name,
       r.rental_date, r.due_date, r.status
FROM rental r
INNER JOIN book b ON b.book_id = r.book_id
INNER JOIN category cat ON cat.category_id = b.category_id
ORDER BY r.rental_id
LIMIT 15;

-- Q7. 카테고리별 도서 목록 조회 (INNER JOIN)
SELECT cat.name AS category_name, b.title, b.price
FROM book b
INNER JOIN category cat ON cat.category_id = b.category_id
ORDER BY cat.name, b.price;

-- Q8. 전체 회원의 대여 건수 조회 - 대여 이력이 없는 회원도 0건으로 포함 (LEFT JOIN)
SELECT m.member_id, m.name, COUNT(r.rental_id) AS rental_count
FROM member m
LEFT JOIN rental r ON r.member_id = m.member_id
GROUP BY m.member_id, m.name
ORDER BY rental_count ASC;

-- ============================================================
-- [3] 집계 (COUNT / SUM / AVG + GROUP BY)
-- ============================================================

-- Q9. 회원별 대여 횟수 집계
SELECT m.name, COUNT(r.rental_id) AS rental_count
FROM member m
INNER JOIN rental r ON r.member_id = m.member_id
GROUP BY m.member_id, m.name
ORDER BY rental_count DESC;

-- Q10. 도서별 총 대여 횟수와 연체 발생 횟수를 집계하고 대여 많은 순으로 정렬
-- (연체 여부는 status 컬럼이 아니라 실제 데이터인 return_date/due_date로 직접 판정한다)
SELECT b.title,
       COUNT(r.rental_id) AS total_rentals,
       SUM(CASE WHEN r.return_date IS NULL AND r.due_date < date('now') THEN 1 ELSE 0 END) AS overdue_count
FROM rental r
INNER JOIN book b ON b.book_id = r.book_id
GROUP BY b.book_id, b.title
ORDER BY total_rentals DESC
LIMIT 10;

-- Q11. 카테고리별 평균 도서 정가 조회
SELECT cat.name AS category_name,
       ROUND(AVG(b.price), 0) AS avg_price,
       COUNT(b.book_id) AS book_count
FROM book b
INNER JOIN category cat ON cat.category_id = b.category_id
GROUP BY cat.category_id, cat.name
ORDER BY avg_price DESC;

-- ============================================================
-- [4] 서브쿼리
-- ============================================================

-- Q12. 전체 도서 평균 정가보다 비싼 도서 조회 (WHERE 절 서브쿼리)
SELECT title, price
FROM book
WHERE price > (SELECT AVG(price) FROM book)
ORDER BY price DESC;

-- Q13. 대여 기록이 한 번도 없는 회원 조회 (NOT IN 서브쿼리)
SELECT member_id, name, phone
FROM member
WHERE member_id NOT IN (SELECT DISTINCT member_id FROM rental);

-- ============================================================
-- [5] 데이터 수정 / 삭제
-- ============================================================

-- Q14. 반납 기한이 지났는데 아직 'RENTED'로 남아 있는 대여 건을 'OVERDUE'로 일괄 업데이트
-- (매일 자정에 도는 배치 작업을 흉내낸 것 - 반납 전인데 기한이 지난 건만 대상으로 한다)
UPDATE rental
SET status = 'OVERDUE'
WHERE status = 'RENTED' AND return_date IS NULL AND due_date < date('now');

-- 결과 확인용 SELECT (상태별 건수)
SELECT status, COUNT(*) AS cnt FROM rental GROUP BY status;

-- Q15. 잘못 등록되었거나 더 이상 필요 없는 대여 기록(rental_id = 32) 삭제
DELETE FROM rental
WHERE rental_id = 32;

-- 결과 확인용 SELECT (rental_id=32 가 사라졌는지 확인)
SELECT * FROM rental WHERE rental_id = 32;

-- ============================================================
-- [6] 인덱스
-- ============================================================

-- Q16. rental.member_id / rental.book_id 에 인덱스 생성
-- 이유: 회원별(Q8, Q9) / 도서별(Q10) 로 rental 을 찾거나 member, book 과 JOIN하는 쿼리가 많은데,
--       FK 컬럼에 인덱스가 없으면 매번 rental 테이블 전체를 스캔하게 되므로 조회 성능을 위해 추가한다.
CREATE INDEX idx_rental_member_id ON rental(member_id);
CREATE INDEX idx_rental_book_id ON rental(book_id);

-- ============================================================
-- [보너스 1] 같은 요구를 JOIN과 서브쿼리 두 방식으로 풀기
-- 요구: "한 번이라도 대여된 적 있는 도서 목록"
-- ============================================================

-- 방식 A: INNER JOIN + DISTINCT
SELECT DISTINCT b.book_id, b.title
FROM book b
INNER JOIN rental r ON r.book_id = b.book_id
ORDER BY b.book_id;

-- 방식 B: 서브쿼리(IN)
SELECT book_id, title
FROM book
WHERE book_id IN (SELECT DISTINCT book_id FROM rental)
ORDER BY book_id;
-- 비교: 두 쿼리는 결과가 동일하다. JOIN은 대여일자처럼 rental의 다른 컬럼도
-- 함께 뽑고 싶을 때 유리하고, 서브쿼리는 "존재 여부"만 확인할 때 더 읽기 쉽다.

-- ============================================================
-- [보너스 2] 데이터 정합성 깨뜨려 보기 (FK 에러 재현)
-- ============================================================
-- 아래 INSERT는 존재하지 않는 category_id = 999 를 참조하므로 FK 제약 위반으로 실패해야 한다.
-- 실행 결과: FOREIGN KEY constraint failed
-- 원인: category 테이블에 category_id=999 인 행이 없는데 book.category_id 가 이를 참조하려고 했기 때문.
-- 해결: 먼저 category 에 999번 행을 추가하거나, 실제 존재하는 category_id 값을 사용해야 한다.
--
-- INSERT INTO book (category_id, title, author, isbn, price) VALUES (999, '존재하지않는분류 도서', '익명', '979-11-0000-000-0', 10000);

-- ============================================================
-- [보너스 3] 미니 리포트 - 핵심 지표 3개
-- ============================================================

-- 지표 1) 월별 대여 건수 추이
SELECT strftime('%Y-%m', rental_date) AS rental_month,
       COUNT(*) AS rental_count
FROM rental
GROUP BY rental_month
ORDER BY rental_month;

-- 지표 2) 가장 인기 있는 도서 TOP 10 (대여 횟수 기준)
SELECT b.title, COUNT(r.rental_id) AS rental_count
FROM rental r
INNER JOIN book b ON b.book_id = r.book_id
GROUP BY b.book_id, b.title
ORDER BY rental_count DESC
LIMIT 10;

-- 지표 3) 연체율이 높은 회원 목록 (연체 건수가 1건 이상인 회원을 연체율 높은 순으로)
SELECT m.name,
       COUNT(r.rental_id) AS total_rentals,
       SUM(CASE WHEN r.return_date IS NULL AND r.due_date < date('now') THEN 1 ELSE 0 END) AS overdue_rentals,
       ROUND(100.0 * SUM(CASE WHEN r.return_date IS NULL AND r.due_date < date('now') THEN 1 ELSE 0 END)
             / COUNT(r.rental_id), 1) AS overdue_rate_pct
FROM member m
INNER JOIN rental r ON r.member_id = m.member_id
GROUP BY m.member_id, m.name
HAVING overdue_rentals > 0
ORDER BY overdue_rate_pct DESC;
