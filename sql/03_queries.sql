SET PAGESIZE 100
SET LINESIZE 200
-- SQL Developer에서는 F5(스크립트 실행). & 치환변수는 아래 예제값으로 정의한다.
DEFINE student_id = 1
DEFINE project_id = 1
DEFINE from_date = '2026-10-01'
DEFINE to_date_exclusive = '2026-11-01'
DEFINE target_type = 'MILEAGE'
DEFINE target_id = 1

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
