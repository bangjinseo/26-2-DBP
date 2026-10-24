-- 빈 전용 실습 스키마에서 SQL Developer F5 또는 SQL*Plus @run_demo.sql.
-- 오류 발생 시 중단, 이미 존재하는 테이블은 삭제하지 않는다.
WHENEVER OSERROR EXIT FAILURE ROLLBACK
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET DEFINE ON
SET SERVEROUTPUT ON
ALTER SESSION SET TIME_ZONE = '+09:00';
@@fixtures/00_common_fixture.sql
@@01_schema.sql
DECLARE v NUMBER;
BEGIN
 SELECT COUNT(*) INTO v FROM user_errors;
 IF v>0 THEN RAISE_APPLICATION_ERROR(-20801,'Compile errors: query USER_ERRORS'); END IF;
END;
/
@@02_seed.sql
@@03_queries.sql
@@04_tests.sql
PROMPT DEMO COMPLETED
