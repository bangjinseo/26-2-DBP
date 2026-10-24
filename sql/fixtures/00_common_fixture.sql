-- 독립 실습 전용. 팀 통합 시 실행하지 말고 공통 테이블의 실제 구조에 맞춘다.
-- Oracle 26ai. 빈 실습 스키마에서 실행한다.
CREATE TABLE user_account (
 user_id NUMBER(19) PRIMARY KEY,
 login_id VARCHAR2(50 CHAR) NOT NULL UNIQUE,
 user_type VARCHAR2(20 CHAR) NOT NULL CHECK(user_type IN ('STUDENT','ADMIN','MASTER')),
 is_active CHAR(1) DEFAULT 'Y' NOT NULL CHECK(is_active IN ('Y','N'))
);
CREATE TABLE student (
 student_id NUMBER(19) PRIMARY KEY,
 user_id NUMBER(19) NOT NULL UNIQUE REFERENCES user_account(user_id),
 student_no VARCHAR2(20 CHAR) NOT NULL UNIQUE,
 student_name VARCHAR2(50 CHAR) NOT NULL
);
CREATE TABLE program (
 program_id NUMBER(19) PRIMARY KEY,
 program_type VARCHAR2(30 CHAR) NOT NULL,
 detail_program_name VARCHAR2(100 CHAR) NOT NULL,
 program_date DATE NOT NULL,
 host_org VARCHAR2(100 CHAR)
);
CREATE TABLE professor (
 professor_id NUMBER(19) PRIMARY KEY,
 name VARCHAR2(50 CHAR) NOT NULL,
 affiliation VARCHAR2(100 CHAR),
 is_active CHAR(1) DEFAULT 'Y' NOT NULL CHECK(is_active IN ('Y','N'))
);
CREATE TABLE change_log (
 log_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 actor_user_id NUMBER(19) NOT NULL REFERENCES user_account(user_id),
 target_type VARCHAR2(50 CHAR) NOT NULL,
 target_id NUMBER(19) NOT NULL,
 action_type VARCHAR2(30 CHAR) NOT NULL,
 old_value CLOB,
 new_value CLOB,
 processed_at TIMESTAMP DEFAULT LOCALTIMESTAMP NOT NULL,
 reason VARCHAR2(500 CHAR)
);
