# hanium_front

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Commit Message Convention
- 형식: `{이모지}{TYPE}: {설명} (#{이슈번호})`
  - 예시: `✨FEAT: 로그인 API 연동 (#12)`

| **이모지** | **타입** | **사용 상황** |
| :---: | :--- | :--- |
| ✨ | **FEAT** | 새로운 기능 추가 |
| 🐛 | **FIX** | 버그 수정 |
| 📝 | **DOCS** | 문서 수정 (README, 노션 링크, 수행계획서 등) |
| 🎨 | **STYLE** | 코드 포맷팅, UI 디자인 수정 (로직 변경 없음) |
| ♻️ | **REFACTOR** | 코드 리팩토링 (성능 개선, 가독성 향상) |
| ✅ | **TEST** | 테스트 코드 추가 및 수정 |
| ⚙️ | **CHORE** | 빌드 업무, 패키지 매니저, .gitignore 수정 |
| 💬 | **COMMENT** | 주석 추가 및 변경 |
| 🌱 | **BUILD** | 빌드 관련 파일 수정 (예: Gradle) |
| ⏪ | **REVERT** | 이전 커밋 되돌리기 |

## 개발 환경 세팅

`.env`는 gitignore 대상이라 clone 직후에는 없다. **아래 한 줄을 먼저 실행해야 빌드된다.**

```bash
cp .env.example .env
flutter pub get
flutter run
```

`.env`의 `API_BASE_URL`은 실행 환경에 맞게 바꾼다.

| 실행 환경 | 값 |
| :--- | :--- |
| 안드로이드 에뮬레이터 | `http://10.0.2.2:3000/api` |
| iOS 시뮬레이터 | `http://localhost:3000/api` |
| 실기기 → 내 PC 서버 | `http://<내PC_IP>:3000/api` |

> 안드로이드 에뮬레이터에서 `localhost`는 에뮬레이터 자기 자신을 가리킨다. 호스트 PC의 백엔드는 `10.0.2.2`로 접근해야 한다.

## 폴더 구조

```
lib/
├── core/        네트워크 공통 (Dio 설정, 토큰 저장, 예외 변환)
├── models/      서버 JSON ↔ 앱 객체
├── services/    API 호출. 화면에서 직접 쓰지 않고 Provider를 거친다
├── providers/   여러 화면이 공유하는 상태 (ChangeNotifier)
├── screens/     화면. 기능별 폴더로 묶는다
├── widgets/     화면들이 공유하는 UI 조각
├── utils/       검증 규칙 등 순수 함수
└── theme/       앱 공통 테마
```

새 기능을 붙일 때는 `services/`에 API 호출을 추가하고 `main.dart`의 `MultiProvider`에 등록한 뒤 화면에서 `context.read<...>()`로 가져다 쓴다.

## 인증 API 계약

> **계약의 원본은 백엔드 저장소의 스펙 문서다.** 이 표는 요약일 뿐이니, 다를 때는 항상 아래가 맞다.
> [`docs/API_SPEC_AUTH.md`](https://github.com/hanium-2026-dongduk/Hanium-back/blob/seo/docs/API_SPEC_AUTH.md) ·
> [`docs/API_SPEC_PROFILE.md`](https://github.com/hanium-2026-dongduk/Hanium-back/blob/seo/docs/API_SPEC_PROFILE.md)
> (현재 [Hanium-back PR #2](https://github.com/hanium-2026-dongduk/Hanium-back/pull/2) 브랜치에 있음)

모든 응답은 봉투에 담겨 온다. **실제 값은 전부 `data` 안에 있다.**

```jsonc
// 성공
{ "success": true, "message": "...", "data": { ... } }
// 실패
{ "success": false, "message": "...", "errors": [ ... ] }
```

### 인증 (`/api/auth`)

| 메서드 | 경로 | 요청 | `data` 응답 |
| :--- | :--- | :--- | :--- |
| POST | `/auth/email/send` | `email` | - |
| POST | `/auth/email/verify` | `email`, `code` | - |
| POST | `/auth/signup` | `email`, `password` | `user` **(토큰 없음)** |
| POST | `/auth/login` | `email`, `password` | `accessToken`, `refreshToken`, `user` |
| POST | `/auth/refresh` | `refreshToken` | `accessToken`, `refreshToken` |
| POST | `/auth/logout` | `refreshToken` | - |
| POST | `/auth/password/reset-request` | `email` | - |
| PUT | `/auth/password/reset` | `email`, `code`, `newPassword` | - |

**회원가입은 3단계다.** `email/send` → `email/verify` → `signup` 순서를 지켜야 하며, 인증을 건너뛰면 403이다.
가입 응답에는 토큰이 없어서 `AuthProvider`가 곧바로 로그인까지 이어 준다.

비밀번호는 **8자 이상 + 영문 + 숫자 + 특수문자**여야 한다. (`Validators.password`가 같은 규칙을 본다)

`user`는 `user_id`, `email`, `role`, `status`다. **이름 컬럼이 없다.**

### 자녀 프로필 (`/api/children`)

경로가 `/profiles`가 아니라 **`/children`**이고, 수정은 `PATCH`가 아니라 **`PUT`**이다.

| 메서드 | 경로 | 요청 | `data` 응답 |
| :--- | :--- | :--- | :--- |
| GET | `/children` | (Bearer) | `profiles: [...]` |
| POST | `/children` | 아래 필드 | `profile` |
| GET | `/children/:id` | (Bearer) | `profile` |
| PUT | `/children/:id` | 아래 필드 | `profile` |
| DELETE | `/children/:id` | (Bearer) | - |
| PATCH | `/children/:id/activate` | (Bearer) | `profile` |

필드는 `child_profile_id`, `user_id`, `child_name`(1~100자), `age`(1~15, 선택), `learning_level`(`beginner`/`intermediate`/`advanced`), `vocabulary_level`(선택), `profile_image_url`(선택), `is_active`.
**생년월일과 아바타 키는 서버에 없다** — 나이와 이미지 URL로 대신한다.

활성 프로필은 보호자당 최대 1개다. 첫 프로필은 자동으로 활성이 되고, 전환은 `activate` API로만 된다.
수정 요청에 반영할 필드가 하나도 없으면 서버가 400을 낸다.

### 토큰 취급

토큰은 `flutter_secure_storage`에 저장한다. 401을 받으면 `ApiClient`가 리프레시를 한 번 시도한 뒤 원래 요청을 재시도하고, 갱신까지 실패하면 토큰을 지우고 로그인 화면으로 돌아간다.

**리프레시 토큰은 서버가 항상 회전시킨다.** 갱신에 쓴 토큰은 즉시 폐기되므로 응답으로 받은 새 토큰을 반드시 저장해야 한다.

서버에 "내 정보" 엔드포인트가 없어서, 로그인할 때 받은 `user`를 토큰과 함께 저장해두고 앱 재시작 시 복원한다. 저장된 토큰이 아직 살아있는지는 `GET /api/children`을 한 번 불러 확인한다.

## 테스트

```bash
flutter test          # 단위 테스트. 통합 테스트는 자동으로 건너뛴다
```

`test/integration/`은 **실제로 띄운 백엔드**에 붙어서 계약이 맞는지 확인한다. 단위 테스트는 "우리가 믿는 계약"만 검증하므로 그 믿음 자체가 틀리면 잡지 못한다 — 실제로 그런 일이 있었고, 그래서 이 테스트가 있다.

돌리려면 백엔드와 MySQL이 필요하다.

```bash
# 1. DB
docker run -d --name hanium-mysql \
  -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=hanium \
  -p 3306:3306 mysql:8

# 2. 백엔드 (Hanium-back 저장소에서)
npm install
# .env 작성 후 스키마 생성 → 마이그레이션 → 기동
node -e "require('dotenv').config();require('./src/models').sequelize.sync({force:true}).then(()=>process.exit())"
npm run migrate
node src/server.js

# 3. 프론트 (이 저장소에서)
flutter test test/integration/auth_flow_test.dart \
  --dart-define=RUN_INTEGRATION=true \
  --dart-define=API_BASE_URL=http://127.0.0.1:3000/api \
  --dart-define=MAIL_SINK_FILE=/경로/last-code.txt
```

회원가입이 이메일 인증을 요구하므로 인증번호를 받을 방법이 필요하다. `MAIL_SINK_FILE`은 백엔드가 보낸 인증번호를 적어두는 파일 경로다. 로컬 SMTP 싱크를 쓰거나, 백엔드 DB의 `email_verifications` 테이블에서 직접 읽어 같은 형식(`{"to":"...","code":"123456"}`)으로 떨어뜨려도 된다.

> **알려진 걸림돌**: `sequelize.sync()`로 만든 스키마에 마이그레이션 `0003`을 적용하면 `ERROR 1215 Cannot add foreign key constraint`가 난다. `sync()`가 `child_profiles.user_id`에 `ON UPDATE CASCADE` FK를 먼저 만드는데, MySQL은 STORED 생성 컬럼(`active_owner_id`)이 참조하는 컬럼에 그런 FK를 허용하지 않는다. 해당 FK를 지우고 `0003`을 적용한 뒤 `ON UPDATE RESTRICT`로 다시 걸면 된다. (백엔드 `0006`이 같은 이유로 이미 RESTRICT를 쓰고 있다)