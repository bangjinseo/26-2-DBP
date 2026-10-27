-- Q10. 프로그램별·문항별 평균 및 완료 응답 수. 주관식 평균은 NULL.
DEFINE survey_id = 1
SELECT survey_id,survey_name,program_id,detail_program_name,
 question_id,question_order,question_text,question_type,average_score,response_count
FROM v_satisfaction_summary
WHERE survey_id=&survey_id
ORDER BY question_order,question_id;

-- 권한을 확인하는 커서 방식 결과 조회. actor는 admin_demo=2 또는 master_demo=1.
VARIABLE q10_result REFCURSOR
BEGIN satisfaction_workflow.open_result(2,&survey_id,:q10_result); END;
/
PRINT q10_result

-- Q11. 학과·학년 점수 평균과 응답 수 + 익명 주관식 의견.
SELECT survey_id,program_id,detail_program_name,question_id,question_text,question_type,
 department_id,department_name,grade,average_score,response_count,answer_text
FROM v_satisfaction_by_department
WHERE survey_id=&survey_id
ORDER BY department_name,grade,question_order,answer_text;

VARIABLE q11_result REFCURSOR
BEGIN satisfaction_workflow.open_department_result(2,&survey_id,:q11_result); END;
/
PRINT q11_result

-- 만족도 조사 업무 로그: 공통 권한 확인을 업무 패키지에서 수행한 처리만 기록.
SELECT l.log_id,l.target_type,l.target_id,l.action_type,u.login_id actor_login,
 l.processed_at,DBMS_LOB.SUBSTR(l.old_value,4000,1) old_value,
 DBMS_LOB.SUBSTR(l.new_value,4000,1) new_value,l.reason
FROM change_log l JOIN user_account u ON u.user_id=l.actor_user_id
WHERE l.target_type IN ('SATISFACTION_SURVEY','SURVEY_QUESTION','SURVEY_RESPONSE')
ORDER BY l.processed_at,l.log_id;
