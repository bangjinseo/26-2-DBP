-- 프로그램 만족도용 권한과 가상 시연 데이터. 공통 계정/학생/프로그램 시드 뒤 실행.
DECLARE
 v_next_id NUMBER;
BEGIN
 SELECT NVL(MAX(permission_id),0)+1 INTO v_next_id FROM permission;
 FOR p IN (
  SELECT '만족도 응답' permission_name,'SATISFACTION_RESPOND' function_code,'SELF' access_level FROM dual
  UNION ALL SELECT '만족도 결과 조회','SATISFACTION_RESULT_READ','READ' FROM dual
  UNION ALL SELECT '만족도 조사 관리','SATISFACTION_MANAGE','WRITE' FROM dual
 ) LOOP
  INSERT INTO permission(permission_id,permission_name,function_code,access_level)
   SELECT v_next_id,p.permission_name,p.function_code,p.access_level FROM dual
   WHERE NOT EXISTS(SELECT 1 FROM permission WHERE function_code=p.function_code);
  IF SQL%ROWCOUNT=1 THEN v_next_id:=v_next_id+1; END IF;
 END LOOP;
END;
/

INSERT INTO role_permission(role_id,permission_id)
SELECT 1,p.permission_id FROM permission p WHERE p.function_code='SATISFACTION_RESPOND'
 AND NOT EXISTS(SELECT 1 FROM role_permission rp WHERE rp.role_id=1 AND rp.permission_id=p.permission_id);
INSERT INTO role_permission(role_id,permission_id)
SELECT 2,p.permission_id FROM permission p WHERE p.function_code IN ('SATISFACTION_RESULT_READ','SATISFACTION_MANAGE')
 AND NOT EXISTS(SELECT 1 FROM role_permission rp WHERE rp.role_id=2 AND rp.permission_id=p.permission_id);
INSERT INTO role_permission(role_id,permission_id)
SELECT 3,p.permission_id FROM permission p WHERE p.function_code IN
 ('SATISFACTION_RESPOND','SATISFACTION_RESULT_READ','SATISFACTION_MANAGE')
 AND NOT EXISTS(SELECT 1 FROM role_permission rp WHERE rp.role_id=3 AND rp.permission_id=p.permission_id);

 DECLARE
 v_survey NUMBER; v_question1 NUMBER; v_question2 NUMBER; v_question3 NUMBER;
 v_survey2 NUMBER; v_question4 NUMBER; v_question5 NUMBER; v_question6 NUMBER;
 v_response NUMBER;
 PROCEDURE add_demo_response(p_student NUMBER,p_actor NUMBER,p_score1 NUMBER,p_score2 NUMBER,p_opinion VARCHAR2) IS
 BEGIN
  satisfaction_workflow.start_response(p_actor,p_student,v_survey,v_response);
  satisfaction_workflow.answer_question(p_actor,v_response,v_question1,p_score1,NULL);
  satisfaction_workflow.answer_question(p_actor,v_response,v_question2,p_score2,NULL);
  satisfaction_workflow.answer_question(p_actor,v_response,v_question3,NULL,p_opinion);
  satisfaction_workflow.complete_response(p_actor,v_response);
 END;
BEGIN
 satisfaction_workflow.create_survey(2,1,'가상 PBL 프로그램 만족도',TRUNC(SYSDATE,'MM'),LAST_DAY(SYSDATE),v_survey);
 satisfaction_workflow.add_question(2,v_survey,1,'프로그램 전반에 만족하나요?','SCORE','Y',v_question1);
 satisfaction_workflow.add_question(2,v_survey,2,'운영 안내가 충분했나요?','SCORE','Y',v_question2);
 satisfaction_workflow.add_question(2,v_survey,3,'개선 의견을 남겨 주세요.','TEXT','Y',v_question3);
 satisfaction_workflow.set_survey_status(2,v_survey,'OPEN','시연을 위해 조사 공개');
 satisfaction_workflow.create_survey(2,2,'가상 SQL 특강 만족도',TRUNC(SYSDATE,'MM'),LAST_DAY(SYSDATE),v_survey2);
 satisfaction_workflow.add_question(2,v_survey2,1,'특강 내용에 만족하나요?','SCORE','Y',v_question4);
 satisfaction_workflow.add_question(2,v_survey2,2,'실습 난이도는 적절했나요?','SCORE','Y',v_question5);
 satisfaction_workflow.add_question(2,v_survey2,3,'추가 의견을 남겨 주세요.','TEXT','Y',v_question6);
 satisfaction_workflow.set_survey_status(2,v_survey2,'OPEN','시연을 위해 조사 공개');

 add_demo_response(1,101,5,4,'실습 시간이 충분해서 좋았습니다.');
 add_demo_response(2,102,4,3,'안내 자료를 조금 더 일찍 받고 싶습니다.');
 add_demo_response(3,103,5,5,'다음에도 참여하고 싶습니다.');
 satisfaction_workflow.start_response(104,4,v_survey,v_response);
 satisfaction_workflow.answer_question(104,v_response,v_question1,3,NULL);
 add_demo_response(5,105,4,4,'다음에도 참여하고 싶습니다.');

 FOR n IN 6..10 LOOP
  satisfaction_workflow.start_response(100+n,n,v_survey2,v_response);
  satisfaction_workflow.answer_question(100+n,v_response,v_question4,MOD(n,3)+3,NULL);
  satisfaction_workflow.answer_question(100+n,v_response,v_question5,4,NULL);
  satisfaction_workflow.answer_question(100+n,v_response,v_question6,NULL,'실습을 더 하고 싶습니다.');
  satisfaction_workflow.complete_response(100+n,v_response);
 END LOOP;
END;
/
