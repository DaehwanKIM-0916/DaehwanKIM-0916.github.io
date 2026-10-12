@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo [1/2] Word 문서를 변환합니다...
python tools\convert.py || (echo 변환 실패: Python과 pandoc이 설치되어 있는지 확인하세요. & pause & exit /b)
echo [2/2] 사이트를 띄웁니다. 브라우저에서 http://localhost:1313 을 여세요. (끝내려면 Ctrl+C)
start "" http://localhost:1313
hugo server
