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

백엔드([Hanium-back](https://github.com/hanium-2026-dongduk/Hanium-back))와 맞춰야 하는 스펙. 실패 응답은 공통으로 `{ "message": "..." }`.

| 메서드 | 경로 | 요청 | 응답 |
| :--- | :--- | :--- | :--- |
| POST | `/api/auth/signup` | `email`, `password`, `name` | `accessToken`, `refreshToken`, `user` |
| POST | `/api/auth/login` | `email`, `password` | `accessToken`, `refreshToken`, `user` |
| POST | `/api/auth/refresh` | `refreshToken` | `accessToken`, `refreshToken` |
| POST | `/api/auth/logout` | (Bearer) | - |
| GET | `/api/users/me` | (Bearer) | `id`, `email`, `name` |
| GET | `/api/profiles` | (Bearer) | `{ profiles: [...] }` |
| POST | `/api/profiles` | `name`, `birthDate?`, `avatarKey?` | `{ profile: {...} }` |
| PATCH | `/api/profiles/:id` | 위와 동일 | `{ profile: {...} }` |
| DELETE | `/api/profiles/:id` | (Bearer) | - |

토큰은 `flutter_secure_storage`에 저장하고, 401을 받으면 `ApiClient`가 리프레시를 한 번 시도한 뒤 원래 요청을 재시도한다. 갱신까지 실패하면 토큰을 지우고 로그인 화면으로 돌아간다.
