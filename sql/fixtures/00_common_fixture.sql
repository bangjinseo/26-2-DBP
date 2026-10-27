-- BEGIN STUDENT_AND_TOPCIT
-- 독립 실습 전용 공통 DDL. 팀 통합 시 중복 실행하지 않고 팀 공통 DDL로 교체한다.
-- Oracle AI Database 26ai Free, 빈 실습 스키마에서 SQL Developer F5로 실행한다.

CREATE TABLE role (
 role_id NUMBER(19) CONSTRAINT pk_role PRIMARY KEY,
 role_code VARCHAR2(20 CHAR) CONSTRAINT nn_role_code NOT NULL,
 role_name VARCHAR2(50 CHAR) CONSTRAINT nn_role_name NOT NULL,
 description VARCHAR2(200 CHAR),
 is_active CHAR(1) DEFAULT 'Y' CONSTRAINT nn_role_active NOT NULL,
 CONSTRAINT uq_role_code UNIQUE(role_code),
 CONSTRAINT uq_role_name UNIQUE(role_name),
 CONSTRAINT uq_role_id_code UNIQUE(role_id,role_code),
 CONSTRAINT ck_role_active CHECK(is_active IN ('Y','N'))
);

CREATE TABLE permission (
 permission_id NUMBER(19) CONSTRAINT pk_permission PRIMARY KEY,
 permission_name VARCHAR2(50 CHAR) CONSTRAINT nn_permission_name NOT NULL,
 function_code VARCHAR2(50 CHAR) CONSTRAINT nn_permission_function NOT NULL,
 access_level VARCHAR2(20 CHAR) CONSTRAINT nn_permission_level NOT NULL,
 CONSTRAINT uq_permission_name UNIQUE(permission_name),
 CONSTRAINT uq_permission_function UNIQUE(function_code),
 CONSTRAINT ck_permission_level CHECK(access_level IN ('SELF','READ','WRITE','APPROVE','MASTER'))
);

CREATE TABLE role_permission (
 role_id NUMBER(19) CONSTRAINT nn_role_permission_role NOT NULL,
 permission_id NUMBER(19) CONSTRAINT nn_role_permission_perm NOT NULL,
 CONSTRAINT pk_role_permission PRIMARY KEY(role_id,permission_id),
 CONSTRAINT fk_role_permission_role FOREIGN KEY(role_id) REFERENCES role(role_id),
 CONSTRAINT fk_role_permission_perm FOREIGN KEY(permission_id) REFERENCES permission(permission_id)
);

CREATE TABLE user_account (
 user_id NUMBER(19) CONSTRAINT pk_user_account PRIMARY KEY,
 role_id NUMBER(19) CONSTRAINT nn_user_account_role NOT NULL,
 login_id VARCHAR2(50 CHAR) CONSTRAINT nn_user_account_login NOT NULL,
 password_info VARCHAR2(255 CHAR) CONSTRAINT nn_user_account_password NOT NULL,
 user_type VARCHAR2(20 CHAR) CONSTRAINT nn_user_account_type NOT NULL,
 is_active CHAR(1) DEFAULT 'Y' CONSTRAINT nn_user_account_active NOT NULL,
 created_at TIMESTAMP DEFAULT SYSTIMESTAMP CONSTRAINT nn_user_account_created NOT NULL,
 updated_at TIMESTAMP,
 CONSTRAINT uq_user_account_login UNIQUE(login_id),
 CONSTRAINT fk_user_account_role_type FOREIGN KEY(role_id,user_type) REFERENCES role(role_id,role_code),
 CONSTRAINT ck_user_account_type CHECK(user_type IN ('STUDENT','ADMIN','MASTER')),
 CONSTRAINT ck_user_account_active CHECK(is_active IN ('Y','N'))
);

CREATE TABLE college (
 college_id NUMBER(19) CONSTRAINT pk_college PRIMARY KEY,
 college_name VARCHAR2(100 CHAR) CONSTRAINT nn_college_name NOT NULL,
 is_active CHAR(1) DEFAULT 'Y' CONSTRAINT nn_college_active NOT NULL,
 CONSTRAINT uq_college_name UNIQUE(college_name),
 CONSTRAINT ck_college_active CHECK(is_active IN ('Y','N'))
);

CREATE TABLE department (
 department_id NUMBER(19) CONSTRAINT pk_department PRIMARY KEY,
 college_id NUMBER(19) CONSTRAINT nn_department_college NOT NULL,
 department_name VARCHAR2(100 CHAR) CONSTRAINT nn_department_name NOT NULL,
 track_type VARCHAR2(30 CHAR) CONSTRAINT nn_department_track NOT NULL,
 campus VARCHAR2(50 CHAR) CONSTRAINT nn_department_campus NOT NULL,
 is_active CHAR(1) DEFAULT 'Y' CONSTRAINT nn_department_active NOT NULL,
 CONSTRAINT fk_department_college FOREIGN KEY(college_id) REFERENCES college(college_id),
 CONSTRAINT uq_department_name UNIQUE(college_id,department_name),
 CONSTRAINT ck_department_track CHECK(track_type IN ('ENGINEERING','NATURAL')),
 CONSTRAINT ck_department_active CHECK(is_active IN ('Y','N'))
);

CREATE TABLE student_status_code (
 status_code VARCHAR2(20 CHAR) CONSTRAINT pk_student_status_code PRIMARY KEY,
 status_name VARCHAR2(50 CHAR) CONSTRAINT nn_student_status_name NOT NULL,
 is_active CHAR(1) DEFAULT 'Y' CONSTRAINT nn_student_status_active NOT NULL,
 CONSTRAINT uq_student_status_name UNIQUE(status_name),
 CONSTRAINT ck_student_status_active CHECK(is_active IN ('Y','N'))
);

CREATE TABLE admission_type_code (
 admission_type_code VARCHAR2(20 CHAR) CONSTRAINT pk_admission_type PRIMARY KEY,
 admission_type_name VARCHAR2(50 CHAR) CONSTRAINT nn_admission_type_name NOT NULL,
 is_active CHAR(1) DEFAULT 'Y' CONSTRAINT nn_admission_type_active NOT NULL,
 CONSTRAINT uq_admission_type_name UNIQUE(admission_type_name),
 CONSTRAINT ck_admission_type_active CHECK(is_active IN ('Y','N'))
);

CREATE TABLE student (
 student_id NUMBER(19) CONSTRAINT pk_student PRIMARY KEY,
 user_id NUMBER(19) CONSTRAINT nn_student_user NOT NULL,
 department_id NUMBER(19) CONSTRAINT nn_student_department NOT NULL,
 status_code VARCHAR2(20 CHAR) CONSTRAINT nn_student_status NOT NULL,
 status_changed_at TIMESTAMP DEFAULT SYSTIMESTAMP CONSTRAINT nn_student_status_changed NOT NULL,
 admission_type_code VARCHAR2(20 CHAR) CONSTRAINT nn_student_admission NOT NULL,
 student_no VARCHAR2(20 CHAR) CONSTRAINT nn_student_no NOT NULL,
 student_name VARCHAR2(50 CHAR) CONSTRAINT nn_student_name NOT NULL,
 grade NUMBER(1) CONSTRAINT nn_student_grade NOT NULL,
 admission_date DATE CONSTRAINT nn_student_admission_date NOT NULL,
 mobile_phone VARCHAR2(20 CHAR),
 sms_yn CHAR(1) DEFAULT 'N' CONSTRAINT nn_student_sms NOT NULL,
 email VARCHAR2(100 CHAR),
 CONSTRAINT uq_student_user UNIQUE(user_id),
 CONSTRAINT uq_student_no UNIQUE(student_no),
 CONSTRAINT fk_student_user FOREIGN KEY(user_id) REFERENCES user_account(user_id),
 CONSTRAINT fk_student_department FOREIGN KEY(department_id) REFERENCES department(department_id),
 CONSTRAINT fk_student_status FOREIGN KEY(status_code) REFERENCES student_status_code(status_code),
 CONSTRAINT fk_student_admission FOREIGN KEY(admission_type_code) REFERENCES admission_type_code(admission_type_code),
 CONSTRAINT ck_student_grade CHECK(grade BETWEEN 1 AND 4),
 CONSTRAINT ck_student_sms CHECK(sms_yn IN ('Y','N'))
);

CREATE TABLE student_status_history (
 history_id NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_student_status_history PRIMARY KEY,
 student_id NUMBER(19) CONSTRAINT nn_status_history_student NOT NULL,
 old_status_code VARCHAR2(20 CHAR) CONSTRAINT nn_status_history_old NOT NULL,
 new_status_code VARCHAR2(20 CHAR) CONSTRAINT nn_status_history_new NOT NULL,
 changed_by NUMBER(19) CONSTRAINT nn_status_history_actor NOT NULL,
 change_date TIMESTAMP DEFAULT SYSTIMESTAMP CONSTRAINT nn_status_history_date NOT NULL,
 change_reason VARCHAR2(500 CHAR) CONSTRAINT nn_status_history_reason NOT NULL,
 CONSTRAINT fk_status_history_student FOREIGN KEY(student_id) REFERENCES student(student_id),
 CONSTRAINT fk_status_history_old FOREIGN KEY(old_status_code) REFERENCES student_status_code(status_code),
 CONSTRAINT fk_status_history_new FOREIGN KEY(new_status_code) REFERENCES student_status_code(status_code),
 CONSTRAINT fk_status_history_actor FOREIGN KEY(changed_by) REFERENCES user_account(user_id),
 CONSTRAINT ck_status_history_change CHECK(old_status_code <> new_status_code)
);

CREATE TABLE student_change_request (
 request_id NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY CONSTRAINT pk_student_change_request PRIMARY KEY,
 student_id NUMBER(19) CONSTRAINT nn_change_request_student NOT NULL,
 request_status VARCHAR2(20 CHAR) DEFAULT 'PENDING' CONSTRAINT nn_change_request_status NOT NULL,
 requested_at TIMESTAMP DEFAULT SYSTIMESTAMP CONSTRAINT nn_change_request_date NOT NULL,
 processor_id NUMBER(19),
 processed_at TIMESTAMP,
 process_comment VARCHAR2(500 CHAR),
 CONSTRAINT fk_change_request_student FOREIGN KEY(student_id) REFERENCES student(student_id),
 CONSTRAINT fk_change_request_processor FOREIGN KEY(processor_id) REFERENCES user_account(user_id),
 CONSTRAINT ck_change_request_status CHECK(request_status IN ('PENDING','APPROVED','REJECTED')),
 CONSTRAINT ck_change_request_processing CHECK(
  (request_status='PENDING' AND processor_id IS NULL AND processed_at IS NULL AND process_comment IS NULL)
  OR
  (request_status IN ('APPROVED','REJECTED') AND processor_id IS NOT NULL AND processed_at IS NOT NULL AND process_comment IS NOT NULL)
 )
);

CREATE TABLE student_change_request_detail (
 detail_id NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_change_request_detail PRIMARY KEY,
 request_id NUMBER CONSTRAINT nn_change_detail_request NOT NULL,
 field_name VARCHAR2(50 CHAR) CONSTRAINT nn_change_detail_field NOT NULL,
 old_value CLOB,
 new_value CLOB CONSTRAINT nn_change_detail_new NOT NULL,
 CONSTRAINT fk_change_detail_request FOREIGN KEY(request_id) REFERENCES student_change_request(request_id),
 CONSTRAINT uq_change_detail_field UNIQUE(request_id,field_name),
 CONSTRAINT ck_change_detail_field CHECK(field_name IN ('mobile_phone','email','sms_yn'))
);

CREATE TABLE topcit_round (
 round_id NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY CONSTRAINT pk_topcit_round PRIMARY KEY,
 round_name VARCHAR2(100 CHAR) CONSTRAINT nn_topcit_round_name NOT NULL,
 exam_date DATE CONSTRAINT nn_topcit_round_date NOT NULL,
 created_by NUMBER(19) CONSTRAINT nn_topcit_round_creator NOT NULL,
 created_at TIMESTAMP DEFAULT SYSTIMESTAMP CONSTRAINT nn_topcit_round_created NOT NULL,
 CONSTRAINT uq_topcit_round UNIQUE(round_name,exam_date),
 CONSTRAINT fk_topcit_round_creator FOREIGN KEY(created_by) REFERENCES user_account(user_id)
);

CREATE TABLE topcit_score (
 score_id NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY CONSTRAINT pk_topcit_score PRIMARY KEY,
 student_id NUMBER(19) CONSTRAINT nn_topcit_score_student NOT NULL,
 round_id NUMBER(19) CONSTRAINT nn_topcit_score_round NOT NULL,
 total_score NUMBER CONSTRAINT nn_topcit_score_total NOT NULL,
 created_by NUMBER(19) CONSTRAINT nn_topcit_score_creator NOT NULL,
 created_at TIMESTAMP DEFAULT SYSTIMESTAMP CONSTRAINT nn_topcit_score_created NOT NULL,
 updated_by NUMBER(19),
 updated_at TIMESTAMP,
 remark VARCHAR2(500 CHAR),
 CONSTRAINT uq_topcit_score UNIQUE(student_id,round_id),
 CONSTRAINT fk_topcit_score_student FOREIGN KEY(student_id) REFERENCES student(student_id),
 CONSTRAINT fk_topcit_score_round FOREIGN KEY(round_id) REFERENCES topcit_round(round_id),
 CONSTRAINT fk_topcit_score_creator FOREIGN KEY(created_by) REFERENCES user_account(user_id),
 CONSTRAINT fk_topcit_score_updater FOREIGN KEY(updated_by) REFERENCES user_account(user_id),
 CONSTRAINT ck_topcit_score_range CHECK(total_score BETWEEN 0 AND 1000),
 CONSTRAINT ck_topcit_score_integer CHECK(total_score=TRUNC(total_score)),
 CONSTRAINT ck_topcit_score_update_meta CHECK(
  (updated_by IS NULL AND updated_at IS NULL) OR (updated_by IS NOT NULL AND updated_at IS NOT NULL)
 )
);

-- 다른 담당 영역이 함께 참조하는 공통 엔터티.
CREATE TABLE program (
 program_id NUMBER(19) CONSTRAINT pk_program PRIMARY KEY,
 program_type VARCHAR2(30 CHAR) CONSTRAINT nn_program_type NOT NULL,
 detail_program_name VARCHAR2(100 CHAR) CONSTRAINT nn_program_name NOT NULL,
 program_date DATE CONSTRAINT nn_program_date NOT NULL,
 host_org VARCHAR2(100 CHAR)
);

CREATE TABLE professor (
 professor_id NUMBER(19) CONSTRAINT pk_professor PRIMARY KEY,
 name VARCHAR2(50 CHAR) CONSTRAINT nn_professor_name NOT NULL,
 affiliation VARCHAR2(100 CHAR),
 is_active CHAR(1) DEFAULT 'Y' CONSTRAINT nn_professor_active NOT NULL,
 CONSTRAINT ck_professor_active CHECK(is_active IN ('Y','N'))
);

CREATE TABLE change_log (
 log_id NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_change_log PRIMARY KEY,
 actor_user_id NUMBER(19) CONSTRAINT nn_change_log_actor NOT NULL,
 target_type VARCHAR2(50 CHAR) CONSTRAINT nn_change_log_target_type NOT NULL,
 target_id NUMBER(19) CONSTRAINT nn_change_log_target_id NOT NULL,
 action_type VARCHAR2(30 CHAR) CONSTRAINT nn_change_log_action NOT NULL,
 old_value CLOB,
 new_value CLOB,
 processed_at TIMESTAMP DEFAULT SYSTIMESTAMP CONSTRAINT nn_change_log_date NOT NULL,
 reason VARCHAR2(500 CHAR),
 CONSTRAINT fk_change_log_actor FOREIGN KEY(actor_user_id) REFERENCES user_account(user_id)
);

CREATE INDEX ix_user_account_role ON user_account(role_id);
CREATE INDEX ix_department_college ON department(college_id);
CREATE INDEX ix_student_department ON student(department_id);
CREATE INDEX ix_status_history_student ON student_status_history(student_id,change_date);
CREATE INDEX ix_change_request_student ON student_change_request(student_id,request_status);
CREATE INDEX ix_change_detail_request ON student_change_request_detail(request_id);
CREATE INDEX ix_topcit_score_round ON topcit_score(round_id,student_id);
CREATE INDEX ix_change_log_target ON change_log(target_type,target_id,processed_at);

COMMENT ON TABLE role IS '사용자 유형별 역할 기준정보';
COMMENT ON TABLE permission IS '기능별 접근 권한 기준정보';
COMMENT ON TABLE role_permission IS '역할과 권한의 N:M 연결';
COMMENT ON TABLE user_account IS '로그인 계정과 활성 상태';
COMMENT ON TABLE college IS '소속 대학 기준정보';
COMMENT ON TABLE department IS '대학 하위 학과·계열·캠퍼스 기준정보';
COMMENT ON TABLE student_status_code IS '학적상태 코드 기준정보';
COMMENT ON TABLE admission_type_code IS '입학구분 코드 기준정보';
COMMENT ON TABLE student IS '승인된 학생 현재 기본정보';
COMMENT ON TABLE student_status_history IS '학생 학적상태 변경 이력';
COMMENT ON TABLE student_change_request IS '학생 인적사항 변경 요청과 처리 상태';
COMMENT ON TABLE student_change_request_detail IS '인적사항 변경 요청의 항목별 전후 값';
COMMENT ON TABLE topcit_round IS 'TOPCIT 시험 회차';
COMMENT ON TABLE topcit_score IS '학생별 TOPCIT 회차 점수';
COMMENT ON TABLE change_log IS '주요 업무 변경·승인·반려 공통 로그';
-- END STUDENT_AND_TOPCIT
