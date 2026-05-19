# Mac App Grid 개발 산출물 v1.0

작성일: 2026-05-19  
대상: macOS Launchpad형 독립 앱 런처 MVP  
권장 제품명: `Mac App Grid` 또는 `AppBoard`  
현재 로컬 초안 경로: `/Users/jyb-m3max/Desktop/codex/LaunchPadReborn`

## 1. 전체 기술 설계서

### 1.1 목표

macOS 26 Tahoe 이후 바뀐 앱 실행 경험을 보완하기 위해, 시스템 내부 Launchpad를 복원하거나 수정하지 않는 독립형 앱 런처를 만든다.

핵심 성공 기준:

- 단축키 입력 후 1초 이내에 앱 그리드가 열린다.
- `/Applications`, `~/Applications`, `/System/Applications`의 앱을 자동 스캔한다.
- 사용자는 앱을 검색, 클릭 실행, 직접 정렬, 폴더 구성할 수 있다.
- 관리자 권한, SIP 해제, private API, Launchpad DB 수정 없이 동작한다.
- Developer ID 서명, Notarization, DMG 배포가 가능해야 한다.

### 1.2 공식 API 기준

- 앱 실행: `NSWorkspace.shared.openApplication(at:configuration:completionHandler:)`
- 앱/파일 탐색: `FileManager.contentsOfDirectory(...)`와 `FileManager.enumerator(...)`
- 앱 메타데이터: `Bundle(url:)`, `Bundle.infoDictionary`, `CFBundleDisplayName`, `CFBundleName`, `bundleIdentifier`
- 로그인 시 실행: macOS 13 이상 `SMAppService`
- 배포: Developer ID 서명, Hardened Runtime, Notarization, DMG

참고:

- Apple Developer Documentation: [`NSWorkspace.openApplication(at:configuration:completionHandler:)`](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication%28at%3Aconfiguration%3Acompletionhandler%3A%29?changes=_6)
- Apple Developer Documentation: [`NSWorkspace.OpenConfiguration`](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration?language=_8)
- Apple Developer Documentation: [`FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options:)`](https://developer.apple.com/documentation/foundation/filemanager/contentsofdirectory%28at%3Aincludingpropertiesforkeys%3Aoptions%3A%29?changes=_1_5)
- Apple Developer Documentation: [`FileManager.DirectoryEnumerationOptions`](https://developer.apple.com/documentation/foundation/filemanager/directoryenumerationoptions?changes=_1)
- Apple Developer Documentation: [`Bundle.infoDictionary`](https://developer.apple.com/documentation/foundation/bundle/infodictionary?changes=_9)
- Apple Developer Documentation: [`SMAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice?changes=_4)
- Apple Developer Documentation: [`SMAppService.register()`](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29)
- Apple Developer Documentation: [`Notarizing macOS software before distribution`](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution?changes=_1)
- Apple Developer Support: [`Developer ID`](https://developer.apple.com/support/developer-id/)
- Apple Developer Documentation: [`App Sandbox`](https://developer.apple.com/documentation/Security/app-sandbox)
- Apple Developer Documentation: [`Protecting user data with App Sandbox`](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- 배경 참고: [Macworld - macOS Tahoe Apps replaces Launchpad](https://www.macworld.com/article/2830963/macos-tahoe-apps-replaces-launchpad.html), [MacRumors - macOS Tahoe transforms Launchpad into App Library](https://www.macrumors.com/2025/06/09/macos-tahoe-launchpad-app-library/)

### 1.3 중요한 기술 판단

`contentsOfDirectory`는 얕은 탐색이다. `/Applications/Utilities`처럼 하위 폴더에 들어간 `.app`까지 안정적으로 찾으려면 MVP에서는 다음 정책을 쓴다.

- 1차 스캔 대상 루트: `/Applications`, `~/Applications`, `/System/Applications`
- 실제 탐색 구현: `FileManager.enumerator(at:includingPropertiesForKeys:options:errorHandler:)`
- `.app` 번들을 발견하면 `skipDescendants()`로 번들 내부 탐색을 중단한다.
- 숨김 파일은 기본 제외하되, 설정에서 시스템/숨김 앱 표시 옵션을 분리한다.

### 1.4 앱 구조

권장 구조:

```txt
MacAppGrid
├─ App
│  ├─ MacAppGridApp.swift
│  └─ AppDelegate.swift
├─ Models
│  ├─ AppItem.swift
│  ├─ FolderItem.swift
│  ├─ LayoutConfig.swift
│  └─ SettingsConfig.swift
├─ Services
│  ├─ AppScanner.swift
│  ├─ AppLauncher.swift
│  ├─ LayoutStore.swift
│  ├─ HotKeyService.swift
│  ├─ LoginItemService.swift
│  └─ AppFileWatcher.swift
├─ Stores
│  ├─ AppCatalogStore.swift
│  ├─ LauncherStateStore.swift
│  └─ SettingsStore.swift
├─ Views
│  ├─ LauncherView.swift
│  ├─ AppGridView.swift
│  ├─ AppIconView.swift
│  ├─ FolderGridView.swift
│  ├─ FolderDetailView.swift
│  └─ SettingsView.swift
├─ Support
│  ├─ IconCache.swift
│  ├─ AppIdentityResolver.swift
│  └─ KeyboardShortcutRecorder.swift
└─ Resources
   └─ Assets.xcassets
```

현재 로컬 초안은 `Sources/LaunchPadReborn/LaunchPadReborn.swift` 한 파일에 대부분 구현이 들어 있다. MVP로 계속 개발하려면 먼저 위 구조로 분리하는 것이 필요하다.

### 1.5 런타임 흐름

1. 앱 시작
2. 상태바 아이콘과 전역 단축키 등록
3. 레이아웃/설정 JSON 로드
4. 캐시된 앱 목록 즉시 표시
5. 백그라운드에서 앱 스캔
6. 변경분을 앱 카탈로그에 반영
7. 사용자가 검색/클릭/Enter로 앱 실행
8. 실행 성공 시 `lastOpenedAt` 갱신
9. 설정에 따라 런처 자동 닫기

### 1.6 앱 스캔 정책

대상 경로:

- `/Applications`
- `~/Applications`
- `/System/Applications`

식별 규칙:

- 1순위: `bundleIdentifier`
- 2순위: 표준화된 앱 경로
- 중복 발생 시 사용자 앱 경로를 시스템 앱보다 우선한다.

에러 처리:

- 읽기 불가 경로는 스캔 실패로 처리하지 않고 건너뛴다.
- 깨진 번들은 기본 이름과 기본 아이콘으로 표시한다.
- 앱 경로가 사라진 항목은 레이아웃에는 남기되 UI에서 "찾을 수 없음" 상태로 표시한다.

### 1.7 앱 실행 정책

```swift
let configuration = NSWorkspace.OpenConfiguration()
NSWorkspace.shared.openApplication(
    at: appURL,
    configuration: configuration
) { runningApp, error in
    // success/failure handling
}
```

실패 처리:

- 앱 경로 없음: 앱 목록 새로고침 안내
- 실행 실패: 오류 메시지와 Finder에서 보기 버튼
- 권한 문제: 시스템 설정 안내
- 실행 후 닫기 옵션이 켜져 있으면 런처 숨김

### 1.8 저장 방식

MVP는 JSON 파일을 권장한다. SQLite는 검색/동기화/대량 상태가 커지는 2차 버전에서 검토한다.

저장 위치:

```txt
~/Library/Application Support/MacAppGrid/apps-cache.json
~/Library/Application Support/MacAppGrid/layout.json
~/Library/Application Support/MacAppGrid/settings.json
~/Library/Application Support/MacAppGrid/backups/
```

저장 원칙:

- 저장은 atomic write로 처리한다.
- JSON decode 실패 시 `.corrupt-YYYYMMDD-HHMMSS.json`으로 백업 후 기본 레이아웃으로 복구한다.
- 사용자 문서/사진/다운로드 폴더에는 접근하지 않는다.

### 1.9 현재 코드 상태와 즉시 수정할 갭

현재 `LaunchPadReborn` Swift Package에는 초기 구현이 있으나, `swift build` 결과 빌드 실패 상태다.

주요 빌드 실패:

- Swift 6 actor isolation 오류: AppKit/SwiftUI 상태 접근에 `@MainActor` 경계가 부족하다.
- `NSSwipeGestureRecognizer` 타입을 찾지 못한다. macOS AppKit에서는 다른 제스처 처리 방식으로 교체가 필요하다.
- `cmdKey`, `kVK_ANSI_L` 타입이 `UInt32`와 맞지 않는다.
- `NSHostingController<OverlayView>`에 environment object를 붙인 `some View`를 직접 넣는 제네릭 타입 문제가 있다.
- SwiftUI `.tabViewStyle(.page(indexDisplayMode:))`는 macOS에서 unavailable이다.
- 현재 단축키 기본값은 `Command + L`인데, 제품 요구사항은 `Option + Space`다.
- `Package.swift`의 최소 지원 버전은 macOS 13으로 되어 있어, 요구사항의 macOS 14 이상과 맞지 않는다.

즉시 권장 조치:

1. 제품명과 번들 명칭을 `MacAppGrid` 계열로 바꾼다.
2. 단일 Swift 파일을 App/Models/Services/Views/Stores로 분리한다.
3. `AppDelegate`, `OverlayController`, UI 이벤트 핸들러를 `@MainActor` 경계로 정리한다.
4. macOS에서 사용 가능한 페이지/스크롤 UI로 교체한다.
5. 단축키 서비스는 Carbon 기반 유지 또는 `KeyboardShortcuts` 같은 의존성 도입 여부를 별도 승인받는다. MVP는 새 의존성 없이 Carbon으로 시작한다.

## 2. 화면 설계 초안

### 2.1 메인 런처

```txt
┌──────────────────────────────────────────────────────────────┐
│                         [ 앱 검색 ]                           │
│                                                              │
│  최근 앱                                                     │
│  Safari    Xcode     Cursor    Slack     Terminal            │
│                                                              │
│  폴더                                                        │
│  개발 도구      디자인      커뮤니케이션                       │
│                                                              │
│  전체 앱                                                     │
│  Safari    Mail      Figma     Xcode     Slack     Notes     │
│  Notion    Chrome    Cursor    Zoom      Terminal  Finder    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

MVP UI 기준:

- 전체 화면 또는 전체 화면에 가까운 borderless overlay window
- 상단 중앙 검색창 자동 포커스
- 스크롤 방식 우선
- 앱 아이콘은 56~64pt, 셀은 84~96pt
- 앱 이름은 최대 2줄
- 검색 결과 0개 상태 제공
- Esc: 검색어가 있으면 검색어 제거, 없으면 런처 닫기
- Enter: 첫 번째 또는 현재 선택 앱 실행
- 방향키: 그리드 선택 이동

### 2.2 폴더 화면

```txt
┌──────────────────────────────────────┐
│ 개발 도구                         ✕  │
├──────────────────────────────────────┤
│ Xcode      Cursor     Terminal       │
│ Docker     Postman    GitHub         │
│                                      │
│ [이름 변경]              [폴더 삭제] │
└──────────────────────────────────────┘
```

MVP UI 기준:

- 폴더 클릭 시 modal sheet 또는 overlay panel
- 바깥 클릭/ESC로 닫기
- 폴더명 수정 가능
- 폴더 내 앱 제거 가능
- 폴더 삭제 시 앱 자체는 삭제하지 않음

### 2.3 설정 화면

```txt
설정
├─ 일반
│  ├─ 로그인 시 자동 실행
│  ├─ 앱 실행 후 런처 닫기
│  └─ 메뉴바 아이콘 표시
├─ 단축키
│  └─ 런처 열기/닫기: Option + Space
├─ 보기
│  ├─ 아이콘 크기: 작게 / 보통 / 크게
│  ├─ 보기 방식: 전체 앱 / 폴더별 / 최근 사용
│  └─ 숨긴 앱 관리
└─ 고급
   ├─ 앱 목록 새로고침
   ├─ 레이아웃 백업
   ├─ 레이아웃 복원
   └─ 레이아웃 초기화
```

설정은 SwiftUI `Settings` scene으로 분리한다. 메인 런처 안에 설정을 억지로 넣지 않는다.

## 3. 데이터 모델 설계

### 3.1 AppItem

```swift
struct AppItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let path: String
    let source: AppSource
    var aliases: [String]
    var isHidden: Bool
    var sortOrder: Int
    var lastOpenedAt: Date?
}

enum AppSource: String, Codable {
    case systemApplications
    case globalApplications
    case userApplications
    case unknown
}
```

### 3.2 FolderItem

```swift
struct FolderItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var appIds: [String]
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
}
```

### 3.3 LayoutItem

```swift
enum LayoutItem: Codable, Hashable {
    case app(appId: String, sortOrder: Int)
    case folder(folderId: String, sortOrder: Int)
}
```

### 3.4 LayoutConfig

```swift
struct LayoutConfig: Codable {
    var version: Int
    var items: [LayoutItem]
    var folders: [FolderItem]
    var hiddenAppIds: [String]
    var updatedAt: Date
}
```

### 3.5 SettingsConfig

```swift
struct SettingsConfig: Codable {
    var openHotKey: HotKeyConfig
    var launchAtLogin: Bool
    var closeAfterLaunchingApp: Bool
    var iconSize: IconSize
    var viewMode: ViewMode
    var showSystemApps: Bool
    var showMenuBarIcon: Bool
}
```

### 3.6 데이터 무결성 규칙

- `LayoutConfig.version`으로 마이그레이션 가능하게 만든다.
- 앱이 사라져도 레이아웃 항목은 즉시 삭제하지 않고 missing 상태로 둔다.
- 폴더 안 앱 ID가 앱 카탈로그에 없으면 흐리게 표시하거나 자동 정리 후보로 표시한다.
- 모든 저장 파일은 decode 실패 시 복구 경로가 있어야 한다.

## 4. 개발 일정

### 4.1 1단계: 프로토타입 정리 및 빌드 복구

예상: 2~4일  
권장 담당: FullStackDev

완료 기준:

- Swift Package 또는 Xcode 프로젝트가 빌드된다.
- 단일 Swift 파일이 최소 App/Models/Services/Views로 분리된다.
- 앱 스캔, 검색, 클릭 실행이 정상 동작한다.
- 기존 `Command + L` 단축키를 `Option + Space` 기본값으로 바꾼다.
- macOS unavailable UI API를 제거한다.

### 4.2 2단계: MVP 기능 구현

예상: 2~3주  
권장 담당: FullStackDev + DesignMarketing

완료 기준:

- 전체 화면 런처
- 앱 스캔 캐시
- 검색 자동 포커스
- 방향키/Enter/Esc 키보드 조작
- 사용자 순서 저장
- 폴더 생성/이름 변경/삭제/앱 추가/앱 제거
- 숨긴 앱 관리
- 설정 화면
- 로그인 시 자동 실행
- 레이아웃 초기화

### 4.3 3단계: 안정화와 QA

예상: 1~2주  
권장 담당: FullStackDev + Orchestrator

완료 기준:

- 앱 200개 기준 검색/스크롤 성능 확인
- 손상된 JSON 복구 테스트
- 앱 경로 삭제/이동 테스트
- 단축키 충돌 UX 테스트
- Intel 가능 여부 확인
- macOS 14, 15, 26 기준 최소 스모크 테스트

### 4.4 4단계: 외부 배포 준비

예상: 3~5일  
권장 담당: Orchestrator

완료 기준:

- Developer ID 서명
- Hardened Runtime
- Notarization
- DMG 생성
- 설치/삭제 안내
- 개인정보 처리방침
- 권한 및 보안 설명

## 5. 예상 리스크

### 5.1 기술 리스크

| 리스크 | 영향 | 대응 |
| --- | --- | --- |
| 전역 단축키 충돌 | 사용자가 런처를 열지 못함 | 기본값 `Option + Space`, 충돌 시 설정 유도 |
| 앱 스캔 성능 저하 | 첫 실행 지연 | 캐시 우선 표시, 백그라운드 재스캔 |
| 깨진 앱 번들 | 크래시 가능 | Bundle 읽기 실패를 정상 케이스로 처리 |
| Swift 6 actor isolation | 빌드 실패 | UI/AppKit 경계는 `@MainActor`로 정리 |
| macOS unavailable API | 빌드 실패 | macOS 전용 SwiftUI/AppKit 패턴으로 교체 |
| Carbon HotKey API 장기 유지성 | 향후 호환성 리스크 | 서비스 계층으로 격리하고 대체 가능하게 설계 |

### 5.2 제품/심사 리스크

| 리스크 | 영향 | 대응 |
| --- | --- | --- |
| Launchpad 상표/혼동 | 마케팅/심사 리스크 | 제품명에 Launchpad 직접 사용 금지 |
| App Store Sandbox 제약 | 기능 제한 | 1차는 Developer ID 외부 배포 |
| Apple 내부 DB 접근 유혹 | 업데이트 취약성 | MVP와 기본 정책에서 명시적으로 제외 |
| 로그인 항목 UX 변화 | 사용자 혼란 | SMAppService 상태를 설정에 명확히 표시 |

### 5.3 보안/프라이버시 리스크

| 리스크 | 영향 | 대응 |
| --- | --- | --- |
| 불필요한 파일 접근 | 신뢰 하락 | 앱 경로 외 접근 금지 |
| 앱 목록이 민감 정보가 될 수 있음 | 프라이버시 이슈 | 로컬 저장만, 외부 전송 없음 |
| 에러 로그에 경로 과다 노출 | 개인정보 노출 | 로그 최소화, 사용자 공유 전 확인 |
| 관리자 권한 요구 | 보안 리스크 | 요구 금지 |

## 6. MVP 견적

### 6.1 기능별 예상 공수

| 영역 | 예상 공수 |
| --- | ---: |
| 기존 코드 빌드 복구/구조 분리 | 2~4일 |
| 앱 스캔/캐시/아이콘 처리 | 2~3일 |
| 런처 UI/검색/키보드 조작 | 4~6일 |
| 앱 실행/오류 처리/최근 실행 | 1~2일 |
| 정렬 저장/드래그 정렬 | 3~5일 |
| 폴더 CRUD/폴더 내부 UI | 4~6일 |
| 설정 화면 | 2~4일 |
| 전역 단축키 설정 | 2~4일 |
| 로그인 시 자동 실행 | 1~2일 |
| 안정성 테스트/성능 개선 | 4~7일 |
| 서명/노터라이즈/DMG/문서 | 3~5일 |

### 6.2 전체 범위 견적

- 프로토타입 빌드 가능 상태: 2~4일
- 실사용 MVP: 4~6주
- 외부 배포 가능 MVP: 5~7주

전제:

- 디자이너 없이 기본 macOS 스타일로 진행
- 새 외부 의존성 추가 없음
- Mac App Store 심사는 범위 제외
- macOS 14 이상, Apple Silicon 우선

## 7. 수락 기준

MVP 완료 판정은 아래를 모두 만족해야 한다.

- 앱 실행 후 1초 이내에 캐시된 그리드가 표시된다.
- 앱 200개 기준 검색 입력이 즉시 반영된다.
- `/Applications`, `~/Applications`, `/System/Applications` 앱이 스캔된다.
- 앱 클릭과 Enter 실행이 된다.
- 실행 실패가 크래시가 아니라 사용자 메시지로 처리된다.
- 앱 순서와 폴더가 재실행 후 유지된다.
- 손상된 layout/settings JSON에서 기본 상태로 복구된다.
- 전역 단축키로 열기/닫기가 된다.
- 로그인 시 자동 실행을 켜고 끌 수 있다.
- 관리자 권한, SIP 해제, private API가 필요 없다.
- Developer ID 서명과 Notarization 경로가 문서화되어 있다.

## 8. 검증 계획

### 8.1 단위 테스트

- `AppScannerTests`: 일반 앱, 중복 bundle ID, bundle ID 없음, 깨진 bundle 처리
- `LayoutStoreTests`: 저장/불러오기, 손상 JSON 복구, 앱 삭제 후 레이아웃 보존
- `FolderStoreTests`: 폴더 생성/이름 변경/삭제, 앱 추가/제거
- `SettingsStoreTests`: 기본값, 저장 실패, 설정 마이그레이션

### 8.2 통합 테스트

- 실제 `/Applications` 스캔 결과가 비어 있지 않은지 확인
- 앱 경로가 존재하지 않을 때 실행 에러가 UI 상태로 반영되는지 확인
- 앱 200개 더미 카탈로그 기준 검색 필터링 속도 확인
- 전역 단축키 등록 실패/충돌 상태 확인

### 8.3 수동 QA

- macOS 14 이상에서 앱 실행, 검색, 클릭 실행
- macOS 26 Tahoe에서 Apps/Spotlight 흐름과 충돌 여부 확인
- 로그인 시 자동 실행 켜기/끄기 확인
- DMG 설치 후 첫 실행 Gatekeeper/Notarization 상태 확인

## 9. 보안 게이트

```txt
SECURITY GATE
- Secrets: 하드코딩할 토큰/키 없음. 로그에 민감값 출력 금지.
- AuthN/AuthZ: 서버/계정 기능 없음. 관리자 권한 요구 금지.
- Input/Output: 앱 번들 메타데이터, JSON 설정 파일 decode 실패를 정상 처리.
- Dependencies: MVP는 새 의존성 없이 SwiftUI/AppKit/Foundation/ServiceManagement 사용.
- Data Handling: 앱 목록/레이아웃은 로컬 Application Support에만 저장. 외부 전송 없음.
- Abuse Controls: 네트워크 기능 없음. 자동 실행/단축키는 사용자가 설정에서 끌 수 있어야 함.
- Tests: 깨진 앱 번들, 사라진 앱 경로, 손상된 JSON, 단축키 충돌에 대한 negative-path 테스트 필요.
- Residual Risk: Carbon hotkey 장기 호환성, App Store sandbox 심사 가능성은 MVP 배포 전 재검토.
```

## 10. 적용 컨트롤

```txt
APPLIED CONTROLS
- Skills Used: create-prd, build-macos-apps:swiftui-patterns
- MCP/Tools Used: web search, shell, apply_patch
- Hooks Active: AGENTS.md security gate, skill recommendation overlay, verification-before-completion
- Rules Applied: no private API, no SIP disablement, no admin privilege, official API verification, least-privilege data handling
```

## 11. 다음 실행 순서

1. `LaunchPadReborn`을 `MacAppGrid`로 제품/번들 네이밍 정리
2. 빌드 실패 수정
3. 단일 Swift 파일 구조 분리
4. 앱 스캔/검색/실행만 먼저 완성
5. 설정/정렬/폴더 순서로 MVP 확장
6. 성능/에러 복구 테스트
7. Developer ID/Notarization/DMG 배포 패킷 준비
