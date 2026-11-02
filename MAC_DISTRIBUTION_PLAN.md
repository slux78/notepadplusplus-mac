# macOS 배포와 Windows 전용 기능 정리 계획

결정일: 2026-10-30. 이 프로젝트는 독립적인 macOS 편집기로 배포한다. Windows 플러그인 ABI 및 Plugins Admin은 구현 범위에서 제외한다. Windows 설치 프로그램, 레지스트리, 트레이, WinGUp의 내부 구현을 옮기지 않고, 사용자에게 필요한 동작만 macOS 방식으로 제공한다. 현재 개발자는 Apple Developer Program 유료 회원이 아니므로 Developer ID 서명과 Apple 공증은 릴리스의 선행 조건으로 두지 않는다.

## 저장소와 공개 범위

- 공개 및 릴리스 대상은 사용자 소유의 `github.com/slux78/notepadplusplus-mac`이다. 공개 목적은 다른 사람이 이 비공식 macOS 포트를 내려받아 사용하거나 소스 코드를 참고할 수 있게 하는 것이다.
- `notepad-plus-plus/notepad-plus-plus`와 공식 설명서 저장소는 참조·출처 표기 대상이다. 이 프로젝트의 변경 사항을 공식 저장소에 push하거나 공식 릴리스로 게시하지 않는다.
- 이 작업 환경에서 확인한 Git `origin`은 `git@github.com:slux78/notepadplusplus-mac.git` 하나다. 실제 GitHub 게시나 Release 생성은 별도 명시적 요청이 있을 때 수행한다.

## WinGUp이 하는 일

WinGUp은 Notepad++의 **업데이트 도우미**다. 공식 설명서에 따르면 설치판은 기본적으로 약 15일마다 새 버전을 확인하고, `? > Update Notepad++`로 수동 확인할 수도 있다. 새 버전이 있으면 다운로드와 설치를 제안하고 기존 앱을 닫은 뒤 설치 프로그램을 실행한다. 새 버전을 곧바로 자동 배포하지 않는 안전 지연도 있다. 편집기 기능이나 파일 포맷이 아니다. [공식 설명서](https://github.com/notepad-plus-plus/npp-usermanual/blob/41d96945ec8d11d4100356293f4f30e60c1418c0/content/docs/upgrading.md)

## 대응 관계

| Windows의 항목 | 이 앱의 macOS 결정 | 이유 |
| --- | --- | --- |
| 설치 프로그램 | 현재는 서명·공증되지 않은 `.app`을 `.dmg`에 담아 직접 배포 | DMG는 설치 파일의 컨테이너일 뿐 Gatekeeper 신뢰를 부여하지 않는다. 사용자는 Applications로 복사한 뒤 최초 실행을 허용해야 할 수 있다. |
| 레지스트리 파일 연결 | `Info.plist`의 문서 타입 선언, Finder의 **Open With** | 앱이 임의로 기본 앱을 바꾸지 않는다. |
| Explorer의 “Edit with Notepad++” DLL | 1차 배포에는 추가 확장 없음. Finder **Open With**와 드래그 앤 드롭 사용 | 기본 경로로 파일 열기 목적을 달성한다. 별도 Finder Quick Action은 실제 수요가 있을 때 검토한다. |
| 시스템 트레이 | 기본적으로 구현하지 않음. Dock, 앱 전환기, 숨기기/최소화 사용 | 편집기를 별도 상태 메뉴에 상주시킬 필요가 확인되지 않았다. 메뉴 막대 아이콘이 필요해지면 별도 선택 기능으로 설계한다. |
| WinGUp | GitHub Releases에서 새 DMG를 사용자가 내려받아 교체 설치 | 이 앱은 백그라운드 점검·자동 다운로드·자동 설치를 하지 않는다. |
| Windows Plugins/Plugins Admin | 구현하지 않음 | Windows용 DLL의 동작·ABI를 모르는 상태에서 호환을 약속할 수 없다. 현재 메뉴의 MIME/Converter/NppExport 기능은 필요하면 **Tools**의 내장 명령으로 정리한다. |

## 작업 순서와 완료 조건

### 1. UI와 버전 표기 정리

- **Plugins** 메뉴 및 Plugins Admin 호환을 암시하는 문구 제거. 현재 내장 변환 명령은 **Tools**로 옮겨 기능 자체는 유지한다.
- 환경 설정의 “Register with macOS Finder” 버튼은 실제 작업 없이 성공만 표시하므로 제거한다. 문서 타입 선언과 Finder에서 기본 앱을 바꾸는 방법을 안내한다.
- 앱 자체의 버전과 Windows 원본의 참조 버전을 분리한다. `CFBundleVersion`은 릴리스마다 증가하는 1~3개 정수 구성으로 관리한다. 현재 `8.9.8.1`은 네 구성 요소라 수정이 필요하다. `CFBundleShortVersionString`도 macOS 배포용 앱 버전으로 정한다.
- 완료 조건: UI에 동작하지 않는 등록/업데이트 명령이 없고, About과 릴리스 산출물의 버전이 일치한다.

### 2. 무료 계정 기준 DMG 릴리스 파이프라인

- 현재 `bundle.sh`의 `.app` 생성 단계를 정리하고 릴리스용 빌드·버전·아이콘 입력을 재현 가능하게 만든다.
- 앱이 들어 있는 DMG를 만들고 릴리스 페이지에 버전, 소스 커밋, SHA-256 체크섬, 변경 내역을 함께 게시한다. Developer ID 서명·Apple 공증을 했다고 표시하지 않는다. 로컬의 임시/ad-hoc 서명은 Gatekeeper가 인정하는 Developer ID 서명과 다름을 분명히 한다.
- DMG 안에는 앱과 Applications 바로가기를 넣는다. 사용자 데이터·세션·설정은 앱 번들 밖의 사용자 Application Support에 보관해 앱 교체 시 유지되게 한다.
- 릴리스 안내에는 Apple이 안내하는 경로만 쓴다: 앱 실행을 시도한 다음 **시스템 설정 > 개인정보 보호 및 보안 > 그래도 열기(Open Anyway)**. Gatekeeper 전체 비활성화나 quarantine 속성 제거 명령은 안내하지 않는다. 관리형 Mac에서는 이 옵션이 제한될 수 있음을 안내한다.
- 깨끗한 다른 Mac에서 DMG 설치, 최초 실행 허용 절차, Finder Open With, 파일 드래그, 기본 앱 변경, 기존 버전 덮어쓰기, 세션/설정 유지, 오프라인 실행을 시험한다.
- 완료 조건: 사용자가 배포 출처와 제한을 이해한 상태에서 Apple의 기본 UI 절차로 실행할 수 있고, 새 버전으로 교체해도 사용자 데이터가 유지된다.

### 3. GitHub Releases 수동 업데이트

- 각 안정판을 `https://github.com/slux78/notepadplusplus-mac/releases`에 태그·변경 내역·DMG 파일로 게시한다. 최신판 링크는 [GitHub의 `/releases/latest`](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)를 사용한다.
- 앱의 **? > 최신 Mac 릴리스 다운로드...** 메뉴는 해당 GitHub 페이지를 브라우저로 연다. 현재 설치 버전은 About에서 확인하고, 새 버전이 있으면 사용자가 DMG를 내려받아 앱을 종료한 뒤 Applications의 기존 앱을 교체한다.
- 새 버전 설치 후 세션과 설정이 유지되는지 시험한다. 기존 앱에 저장되지 않은 문서가 있으면 종료 전에 저장 확인이 작동해야 한다.
- 백그라운드 버전 조회, 알림, 앱 내부 다운로드·설치, WinGUp, Sparkle은 이 계획의 범위에 넣지 않는다.
- 완료 조건: 릴리스 페이지에서 DMG를 내려받아 기존 앱을 교체할 수 있고, 사용자 데이터가 유지된다.

## 현재 코드에서 확인한 출발점

- `bundle.sh`: `.app` 생성 및 문서 타입 선언은 있으나 DMG, 배포용 서명, 공증 단계가 없다.
- `main.swift`: Finder가 전달한 파일을 `application(_:openFiles:)`에서 연다.
- `PreferencesView.swift`: Finder 등록 버튼이 실제 등록 없이 성공 메시지만 표시한다.
- `NppWorkspace.swift`: 파일 연결 확장자 목록은 메모리의 설정값일 뿐 Finder 기본 앱 선택과 연결되지 않는다.

## 나중에 유료 Developer ID를 확보하면

이때 별도 릴리스 작업으로 Developer ID Application 인증서와 hardened runtime으로 앱을 서명하고, DMG를 Apple에 공증한 뒤 티켓을 stapling한다. 새로 서명한 버전은 기존 미서명 버전에서 실제 교체 설치를 시험한다. 이 절차가 끝나기 전에는 “공증됨” 또는 “Gatekeeper 경고 없음”을 약속하지 않는다. [Apple 공증 요건](https://developer.apple.com/documentation/security/resolving-common-notarization-issues), [Apple Developer ID](https://developer.apple.com/developer-id/)

## 참고 자료

- [Notepad++ Upgrading 설명서](https://github.com/notepad-plus-plus/npp-usermanual/blob/41d96945ec8d11d4100356293f4f30e60c1418c0/content/docs/upgrading.md)
- [Apple: Mac 배포용 패키징](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Apple: 공증](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: 확인되지 않은 개발자 앱 열기](https://support.apple.com/en-au/102445)
- [Apple: 문서 타입과 앱 우선순위](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledocumenttypes/lshandlerrank)
- [Apple: CFBundleVersion](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion)
- [GitHub: 최신 릴리스 링크](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)
