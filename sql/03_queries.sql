SET PAGESIZE 100
SET LINESIZE 200
-- SQL Developer에서는 F5(스크립트 실행). & 치환변수는 아래 예제값으로 정의한다.
DEFINE student_id = 1
DEFINE actor_user_id = 101
DEFINE target_student_id = 1
DEFINE project_id = 1
DEFINE from_date = '2026-10-01'
DEFINE to_date_exclusive = '2026-11-01'
DEFINE target_type = 'MILEAGE'
DEFINE target_id = 1

-- BEGIN STUDENT_AND_TOPCIT
-- Q01 특정 학생 기본정보 조회.
-- 목적/사용테이블: STUDENT·USER_ACCOUNT·DEPARTMENT·COLLEGE·학적·입학 코드로 현재 기본정보를 조회한다.
-- 입력/실행예시: actor_user_id=101, target_student_id=1. SQL Developer DEFINE 값을 사용한다.
-- 접근범위: 학생은 본인만, 일반관리자·마스터관리자는 지정 학생을 조회한다.
-- 예상결과: 101이 학생1을 조회하면 1행. 101이 학생2를 조회하면 -20001 오류.
-- 집계/NULL/중복: 집계 없음. 선택 연락처·이메일은 NULL 허용. 학생 PK 기준 1행이며 상세 JOIN 중복이 없다.
VARIABLE q01_cursor REFCURSOR
BEGIN
 student_topcit_workflow.open_student_profile(&actor_user_id,&target_student_id,:q01_cursor);
END;
/
PRINT q01_cursor

-- Q02 학생정보 수정 요청과 처리 이력 조회.
-- 목적/사용테이블: STUDENT_CHANGE_REQUEST·DETAIL·USER_ACCOUNT로 요청항목과 처리자를 조회한다.
-- 입력/실행예시: target_student_id=1. 승인대기·승인·반려를 모두 포함한다.
-- 접근범위: 학생 본인 또는 관리자 권한 확인 후 실행해야 하며, 이 SELECT 단독으로는 인증을 강제하지 않는다.
-- 예상결과: 학생1 승인 요청은 휴대전화번호·이메일 2행. 처리 전 요청은 처리자·처리일시·의견이 NULL이다.
-- 집계/NULL/중복: 요청상세 1건당 1행. 상태별 요청 헤더는 중복되며, 처리 전 처리정보는 NULL이다.
SELECT r.request_id,r.student_id,d.field_name,
 DBMS_LOB.SUBSTR(d.old_value,4000,1) old_value,
 DBMS_LOB.SUBSTR(d.new_value,4000,1) new_value,
 r.request_status,r.requested_at,r.processor_id,u.login_id processor_login,
 r.processed_at,r.process_comment
FROM student_change_request r
JOIN student_change_request_detail d ON d.request_id=r.request_id
LEFT JOIN user_account u ON u.user_id=r.processor_id
WHERE r.student_id=&target_student_id
ORDER BY r.requested_at,r.request_id,d.detail_id;

-- Q03 학생별 TOPCIT 회차별 점수와 변화.
-- 목적/사용테이블: TOPCIT_SCORE·TOPCIT_ROUND를 기준으로 회차 순서와 이전 대비 변화를 조회한다.
-- 입력/실행예시: student_id=1. 시험일자·회차ID 순으로 정렬한다.
-- 접근범위: 학생 본인 조회는 OPEN_TOPCIT_HISTORY를 사용하고, 아래 SELECT는 수작업 결과 검증용이다.
-- 예상결과: 학생1 제1회 600/변화 NULL, 제2회 650/변화 +50.
-- 집계/NULL/중복: 학생×회차 1행. 첫 회차 previous_score·score_change는 NULL이며 UNIQUE로 중복 점수가 없다.
SELECT score_id,student_id,round_id,round_name,exam_date,
 previous_score,total_score current_score,score_change
FROM v_topcit_score_change
WHERE student_id=&student_id
ORDER BY exam_date,round_id;

-- Q04 TOPCIT 회차별·학과별·학년별 평균과 응시자 수.
-- 목적/사용테이블: TOPCIT_SCORE·ROUND·STUDENT·DEPARTMENT로 집단별 평균과 응시자 수를 조회한다.
-- 입력/실행예시: 전체 조회. 필요 시 WHERE에 round_id·department_id·grade 조건을 추가한다.
-- 접근범위: 관리자 집계용으로 가정하며, 운영 스키마에서는 역할별 SELECT/패키지 실행 권한을 제한해야 한다.
-- 예상결과: 제1회 컴퓨터학과 1학년 3명·766.67, 2학년 2명·600.
-- 집계/NULL/중복: 회차×학과×학년 1행, AVG 소수 둘째 자리 반올림. 점수 원천을 1회만 JOIN하여 중복 집계를 방지한다.
SELECT tr.round_id,tr.round_name,tr.exam_date,
 d.department_id,d.department_name,s.grade,
 ROUND(AVG(ts.total_score),2) average_score,COUNT(*) examinee_count
FROM topcit_score ts
JOIN topcit_round tr ON tr.round_id=ts.round_id
JOIN student s ON s.student_id=ts.student_id
JOIN department d ON d.department_id=s.department_id
GROUP BY tr.round_id,tr.round_name,tr.exam_date,d.department_id,d.department_name,s.grade
ORDER BY tr.exam_date,tr.round_id,d.department_id,s.grade;
-- END STUDENT_AND_TOPCIT

-- Q05 전체 학생 누적 유효 마일리지. 예상: 1=400,2=130,3=80,4=200,5~10=0,총810.
SELECT * FROM v_student_mileage ORDER BY student_id;
-- Q05 특정 학생 예시. ID 필터는 인증/접근통제 자체가 아니며 호출자의 신원 연계가 필요.
SELECT * FROM v_student_mileage WHERE student_id=&student_id;

-- Q06 프로그램별·기간별 승인 적립 상세. 기준일은 최초 승인일 approved_at.
-- [시작일,종료일미포함), 현재 APPROVED + ACTIVE만 포함. 증빙/이력은 합계 JOIN에서 제외.
SELECT p.program_id,p.detail_program_name,a.application_id,a.student_id,
 a.approved_at,c.earned_mileage
FROM program p JOIN mileage_standard ms ON ms.program_id=p.program_id
JOIN mileage_application a ON a.standard_id=ms.standard_id
JOIN mileage_accrual c ON c.application_id=a.application_id
WHERE a.status='APPROVED' AND c.status='ACTIVE'
 AND a.approved_at>=TO_DATE('&from_date','YYYY-MM-DD')
 AND a.approved_at<TO_DATE('&to_date_exclusive','YYYY-MM-DD')
ORDER BY p.program_id,a.application_id;
-- Q06 합계 예상: 프로그램1=400,2=50,3=360. 승인 내역 없는 프로그램도 0으로 표시.
SELECT p.program_id,p.detail_program_name,NVL(x.total_mileage,0) total_mileage,NVL(x.approval_count,0) approval_count
FROM program p LEFT JOIN (
 SELECT ms.program_id,SUM(c.earned_mileage) total_mileage,COUNT(*) approval_count
 FROM mileage_standard ms JOIN mileage_application a ON a.standard_id=ms.standard_id
 JOIN mileage_accrual c ON c.application_id=a.application_id
 WHERE a.status='APPROVED' AND c.status='ACTIVE'
 AND a.approved_at>=TO_DATE('&from_date','YYYY-MM-DD')
 AND a.approved_at<TO_DATE('&to_date_exclusive','YYYY-MM-DD')
 GROUP BY ms.program_id
) x ON x.program_id=p.program_id ORDER BY p.program_id;

-- Q07 대기 신청 + 증빙 메타데이터. 신청 단위 목록: 예상 2건, 첨부 수 2/1.
SELECT a.application_id,s.student_id,s.student_name,p.detail_program_name,
 ms.participation_award_type,a.applied_mileage,a.applied_at,
 NVL(f.file_count,0) file_count,f.file_names,f.storage_paths
FROM mileage_application a JOIN student s ON s.student_id=a.student_id
JOIN mileage_standard ms ON ms.standard_id=a.standard_id
JOIN program p ON p.program_id=ms.program_id
LEFT JOIN (
 SELECT application_id,COUNT(*) file_count,
 LISTAGG(file_name, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP(ORDER BY attachment_file_id) file_names,
 LISTAGG(storage_path, '; ' ON OVERFLOW TRUNCATE) WITHIN GROUP(ORDER BY attachment_file_id) storage_paths
 FROM attachment_file GROUP BY application_id
) f ON f.application_id=a.application_id
WHERE a.status='PENDING' ORDER BY a.applied_at,a.application_id;

-- Q08 전체 사업 예산 현황. 승인 지출 사전집계 후 JOIN. 금액 단위 원, 집행률 %.
SELECT * FROM v_budget_summary ORDER BY project_id,project_budget_id;
-- Q08 특정 사업: 최초예산/현재예산/한도/예산잔액/한도잔여액을 구분.
SELECT * FROM v_budget_summary WHERE project_id=&project_id ORDER BY project_budget_id;

-- Q09 교수별 승인 지출: 예상 교수1=600000,2=600000,3=300000.
SELECT p.professor_id,p.name,NVL(x.approved_amount,0) approved_amount
FROM professor p LEFT JOIN (
 SELECT e.professor_id,SUM(e.expense_amount) approved_amount FROM expense e
 JOIN project_budget b ON b.project_budget_id=e.project_budget_id
 WHERE e.status='APPROVED' AND b.project_id=&project_id GROUP BY e.professor_id
) x ON x.professor_id=p.professor_id ORDER BY p.professor_id;
-- Q09 지출주체별: 산학협력=700000,전공=500000,융합=300000.
SELECT s.expense_subject_id,s.subject_name,NVL(x.approved_amount,0) approved_amount
FROM expense_subject s LEFT JOIN (
 SELECT e.expense_subject_id,SUM(e.expense_amount) approved_amount FROM expense e
 JOIN project_budget b ON b.project_budget_id=e.project_budget_id
 WHERE e.status='APPROVED' AND b.project_id=&project_id GROUP BY e.expense_subject_id
) x ON x.expense_subject_id=s.expense_subject_id ORDER BY s.expense_subject_id;
-- Q09 교수×주체 교차 내역. 각 교수의 배정예산/잔액으로 해석하지 않는다.
SELECT e.professor_id,p.name,e.expense_subject_id,s.subject_name,SUM(e.expense_amount) approved_amount
FROM expense e JOIN professor p ON p.professor_id=e.professor_id
JOIN expense_subject s ON s.expense_subject_id=e.expense_subject_id
JOIN project_budget b ON b.project_budget_id=e.project_budget_id
WHERE e.status='APPROVED' AND b.project_id=&project_id
GROUP BY e.professor_id,p.name,e.expense_subject_id,s.subject_name ORDER BY e.professor_id,e.expense_subject_id;

-- Q12 담당 영역의 대상별 로그. 날짜는 로그 처리시각 processed_at.
-- 최초 시드의 마일리지 신청/승인/지출/예산 변경은 실제 실행시각으로 기록된다.
SELECT l.log_id,l.target_type,l.target_id,l.action_type,l.actor_user_id,u.login_id,
 l.processed_at,l.old_value,l.new_value,l.reason
FROM change_log l JOIN user_account u ON u.user_id=l.actor_user_id
WHERE l.target_type='&target_type' AND l.target_id=&target_id ORDER BY l.processed_at,l.log_id;
-- 전체 담당 영역 로그 예시
SELECT target_type,action_type,COUNT(*) log_count FROM change_log
WHERE target_type IN ('MILEAGE','EXPENSE','BUDGET') GROUP BY target_type,action_type ORDER BY target_type,action_type;

-- BEGIN STUDENT_AND_TOPCIT
-- Q12 학생정보·TOPCIT 대상별 변경·승인 로그.
-- 목적/사용테이블: CHANGE_LOG·USER_ACCOUNT로 대상·작업·처리자·일시·변경내용을 조회한다.
-- 입력/실행예시: 담당 대상유형 전체. target_type·target_id 조건을 추가하면 특정 대상만 조회 가능하다.
-- 접근범위: 로그 조회 권한이 있는 관리자용으로 가정한다.
-- 예상결과: 학생요청 9건, TOPCIT 회차 2건, TOPCIT 점수 16건.
-- 집계/NULL/중복: 로그 1건당 1행. old_value/new_value는 CLOB이며 작업 성격에 따라 NULL 가능, 표시를 위해 앞 4000자를 출력한다.
SELECT l.log_id,l.target_type,l.target_id,l.action_type,
 l.actor_user_id,u.login_id,l.processed_at,
 DBMS_LOB.SUBSTR(l.old_value,4000,1) old_value,
 DBMS_LOB.SUBSTR(l.new_value,4000,1) new_value,l.reason
FROM change_log l JOIN user_account u ON u.user_id=l.actor_user_id
WHERE l.target_type IN ('STUDENT_CHANGE_REQUEST','TOPCIT_ROUND','TOPCIT_SCORE')
ORDER BY l.processed_at,l.log_id;
-- END STUDENT_AND_TOPCIT
