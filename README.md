# PBL 미션 2 Oracle 데이터베이스 구현

Oracle AI Database 26ai Free와 SQL Developer의 스크립트 실행(F5)을 기준으로 한 팀 통합 실습 저장소다.
현재 `jinseo` 브랜치에는 기존 마일리지·예산 구현을 보존하면서 학생 인적사항 관리와 TOPCIT 점수 관리를 추가했다.

## 구현 범위

- 학생·일반관리자·마스터관리자의 역할과 기능별 권한 데이터
- 학생 기본정보, 학적·입학 기준정보, 학생정보 수정 요청과 승인·반려
- TOPCIT 시험 회차, 학생별 회차 점수, 점수 수정 이력
- 프로그램 만족도 조사·문항·학생 응답 및 프로그램/학과/학년별 결과
- 공통 변경로그와 처리자 추적
- 학생 본인 조회 범위를 검사하는 패키지 기반 조회
- Q01~Q09 및 담당 영역 Q12
- 마일리지 신청·적립과 예산·지출 기능은 기존 구현을 그대로 포함

웹 화면, 실제 로그인, 실제 개인정보, 파일 업로드, Python 애플리케이션, 운영 배포는 범위에서 제외한다.

## 환경과 접속 전제

- DBMS: Oracle AI Database 26ai Free
- 클라이언트: Oracle SQL Developer 또는 SQLcl/SQL*Plus
- 문자 인코딩: UTF-8
- 세션 시간대: `+09:00`
- 업무 객체는 SYS/SYSTEM이 아닌 빈 테스트용 사용자에 생성
- 필요한 권한: `CREATE SESSION`, `CREATE TABLE`, `CREATE VIEW`, `CREATE PROCEDURE`, `CREATE TRIGGER`, `CREATE SEQUENCE` 및 테이블스페이스 할당량

접속 호스트, 포트, 서비스명, 사용자명은 로컬 접속 설정으로 관리한다. 비밀번호와 접속 문자열은 Git에 저장하지 않는다.

## 파일과 실행 순서

| 순서 | 파일 | 내용 |
|---:|---|---|
| 1 | `sql/fixtures/00_common_fixture.sql` | 단독 검증용 공통·학생·TOPCIT DDL 17개 |
| 2 | `sql/01_schema.sql` | 마일리지·예산 DDL과 전체 업무 패키지·뷰 |
| 3 | `sql/03_satisfaction_schema.sql` | 만족도 테이블·결과 뷰·권한 확인/업무 처리 패키지 |
| 4 | `sql/02_seed.sql` | 공통 역할·학생·TOPCIT 및 마일리지·예산 가상 데이터 |
| 5 | `sql/03_satisfaction_seed.sql` | 만족도 권한 부여와 가상 조사·응답 데이터 |
| 6 | `sql/03_queries.sql` | Q01~Q09와 Q12, 입력조건·예상값 |
| 7 | `sql/06_satisfaction_queries.sql` | Q10/Q11과 만족도 공통로그 조회 |
| 8 | `sql/04_tests.sql` | 학생·TOPCIT·마일리지·예산 오류·경계·권한·로그·롤백 자동 검증 |
| 선택 | `sql/05_workflow_examples.sql` | 기존 마일리지·지출 승인 전후 시연 |

학생·TOPCIT 수작업 예상값과 필수 검증 대응은 [`docs/학생_TOPCIT_구현및검증.md`](docs/%ED%95%99%EC%83%9D_TOPCIT_%EA%B5%AC%ED%98%84%EB%B0%8F%EA%B2%80%EC%A6%9D.md)에 정리했다.

빈 테스트 스키마에서는 `sql/run_demo.sql`을 파일로 열고 F5로 실행한다. 이 파일이 위 순서를 자동으로 호출한다.
`@@` 상대경로를 사용하므로 파일 내용을 새 탭에 복사하지 않는다.

```sql
SET SERVEROUTPUT ON
ALTER SESSION SET TIME_ZONE = '+09:00';
@sql/run_demo.sql
```

SQLcl/SQL*Plus에서는 저장소의 `sql` 디렉터리에서 `@run_demo.sql`로 실행한다.
DDL은 암묵적으로 커밋되므로 전체 생성 스크립트는 빈 전용 스키마에서 한 번만 실행한다.
재실행이 필요하면 본인 소유의 테스트 스키마를 재생성하거나 새 빈 사용자를 사용한다. 공동 스키마를 자동 삭제하는 스크립트는 제공하지 않는다.

## 학생정보 정책

- `STUDENT`에는 승인된 현재 기본정보만 저장한다.
- 학생이 직접 요청할 수 있는 필드는 `mobile_phone`, `email`, `sms_yn`이다.
- 학과, 학적상태, 입학구분은 관리자 정책 영역이며 학생 요청 패키지에서 변경하지 않는다.
- 요청은 `PENDING`, `APPROVED`, `REJECTED` 상태만 허용한다.
- 승인 전과 반려 후에는 `STUDENT` 기본정보를 변경하지 않는다.
- 승인 시 요청 상세의 기존값이 현재 학생정보와 같은지 확인하여 오래된 요청의 덮어쓰기를 차단한다.
- 이미 승인·반려된 요청은 다시 처리할 수 없다.
- 패키지는 COMMIT하지 않으며 호출자가 성공 시 COMMIT, 실패 시 ROLLBACK한다.

## TOPCIT 정책

- 점수는 학생 테이블에 저장하지 않고 `TOPCIT_SCORE`에 회차별로 저장한다.
- 동일 학생·동일 회차는 `UNIQUE(student_id, round_id)`로 한 건만 허용한다.
- 점수 범위는 별도 정책이 없어 0~1000점으로 채택했다. 변경 시 `CK_TOPCIT_SCORE_RANGE`를 수정한다.
- 동일 값으로 수정하는 요청은 오류 `-20014`로 차단하고 불필요한 로그를 생성하지 않는다.
- 공식 점수 등록·수정은 `STUDENT_TOPCIT_WORKFLOW` 패키지를 사용하며, 수정 전후 점수를 `CHANGE_LOG`에 기록한다.
- 회차별·학과별·학년별 평균은 저장하지 않고 원천 점수에서 조회 시 계산한다.

## 접근통제와 트랜잭션

`OPEN_STUDENT_PROFILE`과 `OPEN_TOPCIT_HISTORY`는 전달받은 사용자 ID의 활성 계정과 역할을 검사한다.
학생은 자신의 `USER_ACCOUNT.user_id`와 연결된 학생만 조회할 수 있고, 일반관리자·마스터관리자는 지정 학생을 조회할 수 있다.

이 방식은 실습용 패키지 경로의 접근 범위를 검증한다. 같은 스키마에 직접 테이블 `SELECT`·DML 권한이 있으면 우회할 수 있으므로 운영 환경에서는 역할별 DB 사용자, 제한 뷰, 프로시저 실행 권한만 부여하는 구성이 추가로 필요하다. 실제 로그인 신원과 `p_actor` 값의 연결은 이번 범위에 포함하지 않는다.

학생 승인·반려와 TOPCIT 수정은 업무 데이터와 `CHANGE_LOG`를 하나의 트랜잭션에서 처리한다. 로그 기록 실패 시 패키지 내부 SAVEPOINT로 해당 호출의 변경을 되돌리며, 최종 COMMIT/ROLLBACK은 호출자가 결정한다.

## 테스트 데이터 규모

| 대상 | 규모 |
|---|---|
| 역할 | 학생·일반관리자·마스터관리자 3개 |
| 사용자·학생 | 학생 10명, 관리자 2명 |
| 소속 | 대학 1개, 학과 2개, 학년 2개 |
| 학생정보 수정 요청 | 5건: 승인 2, 반려 2, 대기 1 |
| TOPCIT | 회차 2개, 점수 15건 |
| 점수 변화 | 상승·하락·동일·한 회차만 응시 사례 포함 |
| 공통 로그 | 학생 요청 제출·승인·반려, 회차·점수 등록, 점수 수정 포함 |

모든 데이터는 가상 데이터이며 비밀번호 정보는 실제 인증에 사용할 수 없는 가상 해시 문자열이다.

## 주요 예상값

- Q01: 학생1의 승인된 휴대전화번호는 `010-1111-0001`
- Q02: 수정 요청 5건은 승인 2, 반려 2, 대기 1
- Q03: 학생1은 600점에서 650점으로 50점 상승, 학생2는 700점에서 680점으로 20점 하락
- Q04: 제1회 컴퓨터학과 1학년은 3명, 평균 766.67점
- Q12: 학생 요청 로그 9건, TOPCIT 회차 로그 2건, TOPCIT 점수 로그 16건
- 기존 마일리지·예산 예상값은 `docs/검증보고서.md`에 유지

## DB 제약과 패키지 검증의 구분

- PK/FK/UNIQUE/NOT NULL/CHECK는 잘못된 단일 행 입력을 DB가 직접 차단한다.
- 본인 조회, 요청 상태 전이, 기존값 일치, 승인·로그 원자성, TOPCIT 동일값 수정 차단은 패키지가 검증한다.
- 여러 행을 합산하는 예산 한도는 기존 `PBL_WORKFLOW`가 행 잠금과 승인 합계로 검증한다.
- 검증 SQL로 확인한 조건과 DB가 자동 강제하는 조건을 동일한 것으로 설명하지 않는다.

모든 업무 FK는 `ON DELETE CASCADE`를 사용하지 않는다. 참조 중인 부모 삭제는 Oracle FK가 거부하며 이력은 물리 삭제 대신 상태와 로그로 보존한다.

## 1차 설계 대비 보완

| 대상 | 구현 보완 | 이유 |
|---|---|---|
| 사용자 유형 | ROLE·PERMISSION·ROLE_PERMISSION과 USER_ACCOUNT 연결 | 역할별 권한 확장 |
| 사용자 유형 중복 | `(role_id,user_type)` 복합 FK | 기존 마일리지·예산 호환 컬럼과 역할 코드 불일치 차단 |
| 학생 수정 요청 | 요청 헤더·상세 분리, 기존값 재검증 | 승인 전 데이터 분리와 갱신 충돌 방지 |
| 수정 가능 항목 | 연락처·이메일·SMS로 제한 | 학생 직접 변경 범위 명확화 |
| TOPCIT 범위 | 0~1000점 CHECK | 미확정 범위를 구현 정책으로 확정 |
| TOPCIT 변경 | 등록·수정 패키지와 전후 로그 | 점수 이력과 처리자 추적 |
| 접근 범위 | 패키지 기반 본인/관리자 조회 | 사용자 테이블 존재만으로 접근통제를 주장하지 않음 |

## 팀 통합 시 주의사항

- `fixtures`는 단독 실습용이다. 팀 공통 DDL을 사용하는 경우 중복 실행하지 않는다.
- 공통 `USER_ACCOUNT`, `STUDENT`, `PROGRAM`, `PROFESSOR`, `CHANGE_LOG`는 하나만 유지한다.
- 마일리지·예산 코드는 `student.student_name`, `user_account.user_type`을 사용하므로 통합 정의에서 해당 계약을 보존했다.
- 만족도 구현은 `sql/03_satisfaction_schema.sql`에서 네 업무 테이블, 두 결과 뷰와 `SATISFACTION_WORKFLOW`를 생성한다. 시드·Q10/Q11은 `sql/03_satisfaction_seed.sql`과 `sql/06_satisfaction_queries.sql`에 둔다.
- 만족도 구현은 공통 사용자·역할·권한·로그 테이블을 재사용한다. `SATISFACTION_RESPOND`, `SATISFACTION_RESULT_READ`, `SATISFACTION_MANAGE` 기능권한을 역할에 연결하고, 업무 패키지에서 활성 계정과 권한을 검사한다.
- 만족도는 조사 종료일까지 응답할 수 있고, 한 학생은 조사당 하나의 응답만 가진다. 문항 형식은 `SCORE`(1~5) 또는 `TEXT`이며, 필수 문항을 모두 답해야 완료할 수 있다. Q10/Q11 집계에서는 완료된 응답만 사용한다.
- 만족도 조사 생성·공개/종료·문항 생성·응답 완료를 `CHANGE_LOG`에 기록한다. 업무 패키지는 자체 COMMIT을 하지 않고 로그 실패 시 SAVEPOINT까지 되돌린다. 직접 테이블 접근 권한을 가진 동일 스키마 사용자는 패키지 검증을 우회할 수 있다.
- 기존 검증 원문은 마일리지·예산 구현 당시 결과다. 학생·TOPCIT 추가 후에는 빈 Oracle 스키마에서 전체 테스트를 다시 실행해야 한다.

## 현재 검증 상태

- 검증일: 2026-10-25, 한국 시간 기준
- 환경: Apple Silicon macOS 26.6.2, Podman Desktop 1.30.5, Oracle AI Database 26ai Free 23.26.3.0.0 ARM64
- 실행: 빈 `PBL2` 사용자에서 컨테이너 SQL*Plus로 `run_demo.sql` 전체 실행함
- 문자셋: `NLS_LANG=AMERICAN_AMERICA.AL32UTF8`로 한국어 시드를 검증함
- 결과: PASS 113개, `ALL TESTS PASSED`, `STUDENT/TOPCIT TESTS PASSED`, `DEMO COMPLETED` 확인함
- 객체: 테이블 29개, 뷰 4개, 패키지 2개와 본문 2개 모두 VALID, `USER_ERRORS=0`임
- 실행 원문: `verification/student-topcit-oracle-validation.txt`에 저장함
