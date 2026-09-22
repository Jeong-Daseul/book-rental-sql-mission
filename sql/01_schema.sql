-- ============================================================
-- 도서 대여 관리 데이터베이스 - 스키마 생성 스크립트
-- DB: SQLite 3
-- 실행 순서: 반드시 이 파일을 가장 먼저 실행한다.
-- ============================================================

-- SQLite는 기본적으로 FK 제약을 강제하지 않으므로 세션마다 켜줘야 한다. [SQLite 전용 PRAGMA]
PRAGMA foreign_keys = ON;

-- 기존 테이블이 있다면 깨끗하게 재생성 (재실행 가능하도록)
DROP TABLE IF EXISTS rental;
DROP TABLE IF EXISTS book;
DROP TABLE IF EXISTS member;
DROP TABLE IF EXISTS category;

-- ------------------------------------------------------------
-- 1. category : 도서 분류
-- ------------------------------------------------------------
CREATE TABLE category (
    category_id   INTEGER PRIMARY KEY AUTOINCREMENT,  -- AUTOINCREMENT는 SQLite 전용 문법 [SQLite 전용]
    name          TEXT NOT NULL UNIQUE,                -- 분류명 중복 방지
    description   TEXT
);

-- ------------------------------------------------------------
-- 2. book : 도서 (category 1 : book N)
-- ------------------------------------------------------------
CREATE TABLE book (
    book_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id     INTEGER NOT NULL,
    title           TEXT NOT NULL,
    author          TEXT NOT NULL,
    isbn            TEXT NOT NULL UNIQUE,               -- 도서 고유 식별 번호, 중복 등록 방지
    price           INTEGER NOT NULL CHECK (price > 0),
    stock_quantity  INTEGER NOT NULL DEFAULT 1 CHECK (stock_quantity >= 0),
    published_year  INTEGER,
    FOREIGN KEY (category_id) REFERENCES category(category_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 3. member : 회원
-- ------------------------------------------------------------
CREATE TABLE member (
    member_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT NOT NULL,
    phone         TEXT NOT NULL UNIQUE,                -- 전화번호로 회원 식별, 중복 가입 방지
    email         TEXT UNIQUE,
    joined_at     TEXT NOT NULL DEFAULT (date('now'))
);

-- ------------------------------------------------------------
-- 4. rental : 대여 기록 (member 1:N, book 1:N 을 동시에 받는 대여 상세 테이블)
-- ------------------------------------------------------------
CREATE TABLE rental (
    rental_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    member_id     INTEGER NOT NULL,
    book_id       INTEGER NOT NULL,
    rental_date   TEXT NOT NULL,                       -- 'YYYY-MM-DD'
    due_date      TEXT NOT NULL,                       -- 반납 예정일 (rental_date + 14일)
    return_date   TEXT,                                 -- 실제 반납일, 미반납이면 NULL
    status        TEXT NOT NULL DEFAULT 'RENTED'
                  CHECK (status IN ('RENTED', 'RETURNED', 'OVERDUE')),
    FOREIGN KEY (member_id) REFERENCES member(member_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT                              -- 대여 이력이 있는 회원은 삭제 금지
    ,
    FOREIGN KEY (book_id) REFERENCES book(book_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT                              -- 대여 이력이 있는 도서는 삭제 금지
);

-- 조회 성능을 위한 인덱스는 03_queries.sql 실습 파트에서 생성한다.
