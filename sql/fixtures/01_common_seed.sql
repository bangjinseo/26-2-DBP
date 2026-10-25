-- BEGIN STUDENT_AND_TOPCIT
-- 독립 실습 스키마용 정상 가상 데이터. 실제 개인정보와 평문 비밀번호를 사용하지 않는다.

INSERT INTO role(role_id,role_code,role_name,description) VALUES(1,'STUDENT','학생','본인 정보와 점수 조회, 정보수정 요청');
INSERT INTO role(role_id,role_code,role_name,description) VALUES(2,'ADMIN','일반관리자','학생 및 TOPCIT 업무 처리');
INSERT INTO role(role_id,role_code,role_name,description) VALUES(3,'MASTER','마스터관리자','전체 업무와 권한 관리');

INSERT INTO permission VALUES(1,'본인 학생정보 조회','STUDENT_SELF_READ','SELF');
INSERT INTO permission VALUES(2,'학생정보 수정 요청','STUDENT_CHANGE_REQUEST','SELF');
INSERT INTO permission VALUES(3,'학생정보 관리','STUDENT_MANAGE','APPROVE');
INSERT INTO permission VALUES(4,'본인 TOPCIT 조회','TOPCIT_SELF_READ','SELF');
INSERT INTO permission VALUES(5,'TOPCIT 관리','TOPCIT_MANAGE','WRITE');
INSERT INTO permission VALUES(6,'변경로그 조회','AUDIT_READ','READ');
INSERT INTO permission VALUES(7,'권한 관리','ROLE_MANAGE','MASTER');

INSERT INTO role_permission VALUES(1,1);
INSERT INTO role_permission VALUES(1,2);
INSERT INTO role_permission VALUES(1,4);
INSERT INTO role_permission VALUES(2,1);
INSERT INTO role_permission VALUES(2,3);
INSERT INTO role_permission VALUES(2,4);
INSERT INTO role_permission VALUES(2,5);
INSERT INTO role_permission VALUES(2,6);
INSERT INTO role_permission SELECT 3,permission_id FROM permission;

INSERT INTO user_account(user_id,role_id,login_id,password_info,user_type)
VALUES(1,3,'master_demo','$2b$12$virtual.master.hash','MASTER');
INSERT INTO user_account(user_id,role_id,login_id,password_info,user_type)
VALUES(2,2,'admin_demo','$2b$12$virtual.admin.hash','ADMIN');

INSERT INTO college VALUES(1,'가상 SW융합대학','Y');
INSERT INTO department VALUES(10,1,'가상 컴퓨터학과','ENGINEERING','본교','Y');
INSERT INTO department VALUES(20,1,'가상 소프트웨어학과','ENGINEERING','본교','Y');

INSERT INTO student_status_code VALUES('ENROLLED','재학','Y');
INSERT INTO student_status_code VALUES('LEAVE','휴학','Y');
INSERT INTO admission_type_code VALUES('FRESHMAN','신입학','Y');
INSERT INTO admission_type_code VALUES('TRANSFER','편입학','Y');

BEGIN
 FOR n IN 1..10 LOOP
  INSERT INTO user_account(user_id,role_id,login_id,password_info,user_type)
  VALUES(100+n,1,'student_demo_'||n,'$2b$12$virtual.student.'||LPAD(n,2,'0')||'.hash','STUDENT');
  INSERT INTO student(
   student_id,user_id,department_id,status_code,admission_type_code,
   student_no,student_name,grade,admission_date,mobile_phone,sms_yn,email
  ) VALUES(
   n,100+n,CASE WHEN n<=5 THEN 10 ELSE 20 END,'ENROLLED',
   CASE WHEN n IN (5,10) THEN 'TRANSFER' ELSE 'FRESHMAN' END,
   'DEMO2026'||LPAD(n,3,'0'),'가상학생'||n,
   CASE WHEN MOD(n,2)=1 THEN 1 ELSE 2 END,DATE '2026-03-02',
   '010-0000-'||LPAD(n,4,'0'),'N','student'||n||'@example.invalid'
  );
 END LOOP;
END;
/

-- 마일리지·예산 담당이 함께 사용하는 공통 가상 데이터.
INSERT INTO program VALUES(1,'CONTEST','가상 해커톤',DATE '2026-10-01','가상 사업단');
INSERT INTO program VALUES(2,'EDUCATION','가상 SQL 특강',DATE '2026-10-05','가상 사업단');
INSERT INTO program VALUES(3,'PROJECT','가상 PBL 발표회',DATE '2026-10-10','가상 사업단');
INSERT INTO professor VALUES(1,'가상교수A','가상 컴퓨터학과','Y');
INSERT INTO professor VALUES(2,'가상교수B','가상 소프트웨어학과','Y');
INSERT INTO professor VALUES(3,'가상교수C','가상 융합학과','Y');

-- 학생정보 수정 요청 5건: 승인 2, 반려 2, 대기 1. 요청 당시 기본정보는 별도 상세에 보존한다.
DECLARE
 v_request NUMBER;
BEGIN
 student_topcit_workflow.request_student_change(
  101,1,'010-1111-0001','student1.new@example.invalid',NULL,v_request);
 student_topcit_workflow.process_student_change(2,v_request,'APPROVED','연락처 확인 완료');

 student_topcit_workflow.request_student_change(
  102,2,NULL,'student2.rejected@example.invalid',NULL,v_request);
 student_topcit_workflow.process_student_change(2,v_request,'REJECTED','증빙 정보 불일치');

 student_topcit_workflow.request_student_change(
  103,3,NULL,'student3.pending@example.invalid','Y',v_request);

 student_topcit_workflow.request_student_change(
  104,4,NULL,NULL,'Y',v_request);
 student_topcit_workflow.process_student_change(1,v_request,'APPROVED','SMS 수신 동의 확인');

 student_topcit_workflow.request_student_change(
  105,5,'010-5555-0005',NULL,NULL,v_request);
 student_topcit_workflow.process_student_change(1,v_request,'REJECTED','본인 확인 자료 부족');
END;
/

-- TOPCIT 2개 회차와 점수 15건. 학생1 상승, 학생2 하락, 학생3 동일, 학생9·10은 2회차만 응시한다.
DECLARE
 v_round1 NUMBER;
 v_round2 NUMBER;
 v_score NUMBER;
 PROCEDURE add_score(p_student NUMBER,p_round NUMBER,p_value NUMBER) IS
 BEGIN
  student_topcit_workflow.register_topcit_score(2,p_student,p_round,p_value,'가상 TOPCIT 점수',v_score);
 END;
BEGIN
 student_topcit_workflow.create_topcit_round(2,'2026년 제1회',DATE '2026-05-16',v_round1);
 student_topcit_workflow.create_topcit_round(2,'2026년 제2회',DATE '2026-09-19',v_round2);

 add_score(1,v_round1,600); add_score(2,v_round1,700); add_score(3,v_round1,800);
 add_score(4,v_round1,500); add_score(5,v_round1,900); add_score(6,v_round1,650);
 add_score(7,v_round1,750); add_score(8,v_round1,550);

 add_score(1,v_round2,640);
 student_topcit_workflow.update_topcit_score(2,v_score,650,'채점 정정: 640에서 650으로 변경');
 add_score(2,v_round2,680); add_score(3,v_round2,800); add_score(4,v_round2,520);
 add_score(5,v_round2,850); add_score(9,v_round2,600); add_score(10,v_round2,700);
END;
/
-- END STUDENT_AND_TOPCIT
