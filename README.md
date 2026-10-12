# DHKim 학습노트 — Word 글을 인터넷 사이트로

Word(.docx)로 쓴 글을 `docx` 폴더에 넣기만 하면 자동으로 웹사이트가 만들어지는 프로젝트입니다.
형광펜, 표, 박스(시험 메모 같은 한 칸짜리 표), `flowchart LR …`처럼 적어 둔 흐름도까지 그대로 살려서 바꿔 줍니다.

```
docx/                 ← Word 원본을 넣는 곳 (하위 폴더 이름 = 사이트의 분류)
  물류관리사/
    3.화물자동차_운수사업법_해설.docx
    ...
content/              ← (선택) Markdown으로 직접 쓰는 글
tools/                ← 변환 프로그램 (손댈 필요 없음)
layouts/, static/     ← 사이트 디자인
hugo.toml             ← 사이트 이름·소개 문구 설정
.github/workflows/    ← GitHub에 올리면 자동으로 사이트를 만드는 설정
```

---

## 1. 처음 한 번만: GitHub에 사이트 열기 (설치 없이 웹에서만)

1. **GitHub 가입**: https://github.com 에서 무료 계정을 만듭니다. 아이디가 사이트 주소가 됩니다.
2. **저장소 만들기**: 오른쪽 위 `+` → **New repository**
   - Repository name: `아이디.github.io` (예: 아이디가 `dhkim`이면 `dhkim.github.io`)
   - **Public** 선택 → **Create repository**
3. **파일 올리기**: 새 저장소 화면의 **uploading an existing file** 링크를 누르고,
   이 압축을 푼 폴더 **안의 내용 전부**(`.github` 폴더 포함)를 끌어다 놓은 뒤 **Commit changes**.
   - `.github` 폴더가 안 보이면: 윈도우 탐색기 `보기 → 숨긴 항목` 체크, 맥은 Finder에서 `⌘ + Shift + .`
   - 웹 업로드는 한 번에 100개까지입니다. Word 파일이 수백 개면 여러 번 나눠 올리거나, 아래 3번의 GitHub Desktop을 쓰세요.
4. **공개 설정**: 저장소의 **Settings → Pages → Build and deployment → Source** 를 **GitHub Actions** 로 바꿉니다.
5. **확인**: **Actions** 탭에서 초록색 ✔ 표시가 뜨면(1~2분) `https://아이디.github.io` 에 사이트가 열립니다.
   - 처음에 Pages 설정 전에 올려서 빨간 ✘가 떴다면: Actions → 실패한 항목 → **Re-run all jobs**.

## 2. 글을 추가·수정할 때

- 저장소에서 `docx/물류관리사` 폴더로 들어가 **Add file → Upload files** 로 Word 파일을 올리고 **Commit changes**.
- 같은 이름으로 올리면 수정본으로 바뀝니다. 지우려면 파일을 열고 휴지통 아이콘.
- 1~2분 뒤 사이트에 자동 반영됩니다.
- **새 분류**를 만들려면 `docx` 아래에 새 폴더를 만들면 됩니다(예: `docx/물류관리론/…`). 위쪽 메뉴에 자동으로 생깁니다.

## 3. Word 파일이 수백 개일 때: GitHub Desktop

웹 업로드보다 훨씬 편합니다. https://desktop.github.com 설치 → 로그인 → 저장소를 **Clone** →
내 PC에 생긴 폴더의 `docx/` 안에 Word 파일을 복사 → GitHub Desktop에서 **Commit** → **Push origin**. 끝입니다.

## 4. 변환 규칙 (Word 작성 요령)

| Word에서 | 사이트에서 |
|---|---|
| 파일 이름 `3.화물자동차_운수사업법_해설.docx` | 제목 "화물자동차 운수사업법 해설", 3번째 순서 |
| 파일 이름의 `260908` 같은 6자리/8자리 숫자 | 글 날짜 2026-09-08 (없으면 Word 파일의 수정 날짜) |
| 문서가 '제목' 스타일로 시작 (예: `1. 물류의 개념과 발전`) | 그 문장이 글 제목 |
| 제목 1·2·3 스타일 | 글 안의 소제목, 오른쪽 목차 |
| 형광펜 | 노란 밑줄 강조 |
| 칸이 하나뿐인 표 (첫 줄이 굵은 글씨면 상자 제목) | 강조 상자 |
| `flowchart LR` 로 시작하는 문단 | 흐름도 그림 |
| 그림 | 그대로 포함 |

- 파일 이름에서 `claude`, `최종`, `final`, `수정본` 같은 낱말은 제목에서 자동으로 빠집니다. 바꾸려면 `tools/convert.py` 위쪽의 `REMOVE_WORDS`.
- 제목을 직접 정하고 싶으면 `docx/titles.json` 파일을 만들어 적습니다:
  ```json
  { "Sample 1.docx": "물류의 개념과 발전" }
  ```

## 5. 사이트 이름·소개 문구 바꾸기

`hugo.toml`을 GitHub 웹에서 열고 연필(✎) 아이콘으로 고칩니다: `title`, `author`, `description`, `intro`.
색과 글꼴은 `static/css/style.css` 맨 위의 `:root { … }` 부분에서 바꿀 수 있습니다.

## 6. (선택) 내 PC에서 먼저 미리 보기

다음 세 가지를 한 번 설치합니다(윈도우: 명령 프롬프트에서).

```
winget install Python.Python.3.12
winget install JohnMacFarlane.Pandoc
winget install Hugo.Hugo.Extended
```

그다음 `preview.bat`을 더블클릭하면 브라우저에서 http://localhost:1313 으로 사이트가 열립니다.
맥: `brew install python pandoc hugo` 후 `python3 tools/convert.py && hugo server`.

## 7. (선택) 내 도메인 연결

도메인(예: `dhkim.kr`)을 구입했다면 Settings → Pages → **Custom domain** 에 입력하고,
도메인 업체 설정에서 안내대로 DNS를 연결하면 됩니다.
