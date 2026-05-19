# Mac App Grid 개발자 핸드오프 v1.0

작성일: 2026-05-19  
작업 위치: `/Users/jyb-m3max/Desktop/codex/LaunchPadReborn`  
주 문서: `docs/mac-app-grid-deliverables-v1.md`

```txt
HANDOFF
Agent: Orchestrator
Objective: macOS 26 Tahoe 이후 Launchpad형 사용성을 대체하는 독립형 macOS 앱 런처 MVP 설계 및 구현
In Scope: 앱 스캔, 앱 아이콘 그리드, 검색, 앱 실행, 전체 화면 런처, 전역 단축키, 사용자 정렬, 폴더, 숨긴 앱 관리, 설정, 로그인 시 자동 실행, Developer ID 배포 준비
Out of Scope: Apple Launchpad 원본 복원, Launchpad 내부 DB 수정, SIP 해제, 관리자 권한 요구, private API, 시스템 파일 수정, 앱 삭제/설치 관리, iCloud 동기화, 트랙패드 핀치 완전 재현
Security Requirements: 앱 목록/레이아웃은 로컬 저장만 허용, 사용자 문서/사진/다운로드 폴더 접근 금지, 네트워크 전송 없음, 로그에 민감 경로/환경값 최소화, 관리자 권한 요구 금지
Top Threat Notes: 1) 앱 목록이 사생활 정보가 될 수 있으므로 외부 전송 금지. 2) 손상 JSON/깨진 앱 번들은 크래시 대신 복구. 3) 전역 단축키 충돌은 설정 안내로 처리.
Dependencies: Swift, SwiftUI, AppKit, Foundation, ServiceManagement, NSWorkspace, FileManager, Bundle; MVP는 새 외부 의존성 없이 시작
Acceptance Criteria: 1초 이내 런처 표시, 앱 200개 검색 즉시 반응, 앱 클릭/Enter 실행, 정렬/폴더 재실행 후 유지, 손상 파일 복구, 전역 단축키 동작, 로그인 시 자동 실행 토글, Developer ID/Notarization 문서화
Evidence Required: swift build 성공, 단위 테스트 통과, macOS 14+ 수동 QA, macOS 26 Tahoe 스모크 테스트, DMG 설치/삭제 확인, codesign/notarytool 검증 로그
Open Risks/Questions: Carbon HotKey 장기 호환성 검토(Owner: FullStackDev, Due: MVP 안정화 전), Mac App Store 샌드박스 버전 가능성 검토(Owner: Orchestrator, Due: 외부 배포 후)
```

## 개발자에게 바로 전달할 요청문

macOS용 앱 그리드 런처를 개발하고 싶습니다.

배경:
macOS 26 Tahoe 이후 기존 Launchpad 사용 경험이 사라지거나 바뀌면서, 앱을 한눈에 보고 폴더로 정리하고 빠르게 실행할 수 있는 대체 앱이 필요합니다.

제품 방향:
Launchpad 원본을 복원하거나 시스템을 해킹하는 앱이 아니라, 독립적으로 동작하는 안전한 macOS 앱 런처를 만들고 싶습니다.

가칭:
Mac App Grid

핵심 목표:

1. Mac의 앱을 자동으로 스캔한다.
2. 앱 아이콘을 그리드로 보여준다.
3. 앱 이름으로 검색할 수 있다.
4. 클릭하거나 Enter로 앱을 실행한다.
5. 사용자가 앱 순서를 직접 정리할 수 있다.
6. 앱을 폴더로 묶을 수 있다.
7. 전역 단축키로 런처를 열고 닫을 수 있다.
8. 로그인 시 자동 실행을 설정할 수 있다.
9. 관리자 권한, SIP 해제, private API 없이 동작한다.
10. Developer ID 서명과 Notarization으로 외부 배포 가능해야 한다.

기술 스택:

- Swift
- SwiftUI
- AppKit
- Foundation
- ServiceManagement
- NSWorkspace
- FileManager
- Bundle / Info.plist
- UserDefaults + Application Support JSON

지원 범위:

- macOS 14 이상
- macOS 26 Tahoe 대응 필수
- Apple Silicon 우선
- 가능하면 Intel Mac 지원

MVP 필수 기능:

1. `/Applications`, `~/Applications`, `/System/Applications` 스캔
2. `.app` 번들 목록화
3. 앱 이름, bundleIdentifier, 경로, 아이콘 읽기
4. 앱 아이콘 그리드 표시
5. 검색 기능
6. 앱 클릭/Enter 실행
7. 전체 화면 런처 UI
8. 전역 단축키, 기본값 `Option + Space`
9. 앱 순서 저장
10. 폴더 생성/수정/삭제
11. 숨긴 앱 관리
12. 설정 화면
13. 로그인 시 자동 실행
14. 레이아웃 초기화/복구

제외할 기능:

- Apple Launchpad 원본 복원
- Launchpad 내부 DB 수정
- SIP 해제 요구
- 관리자 권한 요구
- 시스템 파일 수정
- 앱 삭제 기능
- iCloud 동기화
- 트랙패드 핀치 제스처 완전 재현

현재 로컬 상태:

- `/Users/jyb-m3max/Desktop/codex/LaunchPadReborn`에 Swift Package 초안이 있다.
- 현재 초안은 한 파일에 구현이 몰려 있어 구조 분리가 필요하다.
- `swift build`는 현재 실패한다. 주요 원인은 Swift 6 actor isolation, macOS unavailable SwiftUI page style, `NSSwipeGestureRecognizer` 사용, HotKey 타입 불일치, `NSHostingController` rootView 타입 문제다.

먼저 할 일:

1. 프로젝트/제품명을 `MacAppGrid` 계열로 정리한다.
2. 빌드 실패를 수정한다.
3. App/Models/Services/Views/Stores 구조로 분리한다.
4. 앱 스캔 + 검색 + 실행을 먼저 완성한다.
5. 그 다음 정렬, 폴더, 설정, 로그인 항목, 배포 패키징으로 확장한다.

## 개발자 검수 체크리스트

- [ ] SwiftUI + AppKit 구조를 제안했는가
- [ ] NSWorkspace 공식 API로 앱 실행을 처리하는가
- [ ] FileManager deep enumeration으로 앱 경로 스캔을 처리하는가
- [ ] Bundle / Info.plist 기반 메타데이터 추출을 설명했는가
- [ ] private API를 쓰지 않겠다고 명확히 했는가
- [ ] SIP 해제를 요구하지 않는가
- [ ] 관리자 권한을 요구하지 않는가
- [ ] 전역 단축키 구현 방식과 충돌 처리를 설명했는가
- [ ] SMAppService 기반 로그인 시 자동 실행을 설명했는가
- [ ] Application Support JSON 저장과 손상 파일 복구를 설명했는가
- [ ] 앱 200개 이상일 때 성능 고려가 있는가
- [ ] Notarization, Hardened Runtime, Developer ID 배포를 이해하고 있는가
- [ ] 설치/삭제 안내와 개인정보 처리방침까지 산출물에 포함했는가

## 보안 게이트

```txt
SECURITY GATE
- Secrets: 하드코딩할 토큰/키 없음. 로그에 민감값 출력 금지.
- AuthN/AuthZ: 서버/계정 기능 없음. 관리자 권한 요구 금지.
- Input/Output: 앱 번들 메타데이터, JSON 설정 파일 decode 실패를 정상 처리.
- Dependencies: MVP는 새 의존성 없이 SwiftUI/AppKit/Foundation/ServiceManagement 사용.
- Data Handling: 앱 목록/레이아웃은 로컬 Application Support에만 저장. 외부 전송 없음.
- Abuse Controls: 네트워크 기능 없음. 자동 실행/단축키는 사용자가 설정에서 끌 수 있어야 함.
- Tests: 깨진 앱 번들, 사라진 앱 경로, 손상된 JSON, 단축키 충돌에 대한 negative-path 테스트 필요.
- Residual Risk: Carbon HotKey 장기 호환성, App Store sandbox 심사 가능성은 MVP 배포 전 재검토.
```

## 공식 근거

- Apple Developer Documentation: `NSWorkspace.openApplication(at:configuration:completionHandler:)`
- Apple Developer Documentation: `FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options:)`
- Apple Developer Documentation: `Bundle.infoDictionary`
- Apple Developer Documentation: `SMAppService`
- Apple Developer Documentation: `Notarizing macOS software before distribution`
- Apple Developer Documentation: `App Sandbox`

