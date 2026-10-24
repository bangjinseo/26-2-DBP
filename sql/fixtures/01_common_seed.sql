-- 독립 실습 스키마용 정상 가상 데이터. 날짜는 2026년 10월, 금액 단위 원.
-- 공통 데이터는 팀 통합 시 중복 INSERT하지 않는다.
INSERT INTO user_account VALUES(1,'master_demo','MASTER','Y');
INSERT INTO user_account VALUES(2,'admin_demo','ADMIN','Y');
BEGIN
 FOR n IN 1..10 LOOP
  INSERT INTO user_account VALUES(100+n,'student_demo_'||n,'STUDENT','Y');
  INSERT INTO student VALUES(n,100+n,'DEMO2026'||LPAD(n,3,'0'),'가상학생'||n);
 END LOOP;
END;
/
INSERT INTO program VALUES(1,'CONTEST','가상 해커톤',DATE '2026-10-01','가상 사업단');
INSERT INTO program VALUES(2,'EDUCATION','가상 SQL 특강',DATE '2026-10-05','가상 사업단');
INSERT INTO program VALUES(3,'PROJECT','가상 PBL 발표회',DATE '2026-10-10','가상 사업단');
INSERT INTO professor VALUES(1,'가상교수A','가상 컴퓨터학과','Y');
INSERT INTO professor VALUES(2,'가상교수B','가상 소프트웨어학과','Y');
INSERT INTO professor VALUES(3,'가상교수C','가상 융합학과','Y');
