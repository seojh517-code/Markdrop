#!/bin/bash
# Markdrop — 클립보드의 텍스트를 현재 Finder 폴더에 .md 파일로 저장합니다.
#
# 동작:
#   1) 맨 앞에 열려 있는 Finder 창의 폴더를 대상으로 합니다.
#      (열린 창이 없으면 데스크탑에 저장)
#   2) 클립보드(pbpaste) 내용을 읽습니다.
#   3) 첫 줄을 기반으로 파일명을 만들어 .md 파일로 저장합니다.

# UTF-8 로케일 강제: 이게 없으면 빠른 동작에서 실행될 때 로케일이 C로 잡혀
# pbpaste가 한글을 EUC-KR로 출력 → 파일/파일명이 깨집니다.
export LANG="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

# 1) 대상 폴더 결정: 맨 앞 Finder 창의 폴더
target_dir="$(osascript 2>/dev/null <<'AS'
tell application "Finder"
	if (count of windows) > 0 then
		try
			return POSIX path of (target of front window as alias)
		end try
	end if
end tell
AS
)"

# 열린 창이 없거나 폴더가 아니면 데스크탑으로 폴백
if [ -z "$target_dir" ] || [ ! -d "$target_dir" ]; then
	target_dir="$HOME/Desktop"
fi

# 2) 클립보드 내용 읽기
content="$(pbpaste)"

if [ -z "$content" ]; then
	osascript -e 'display notification "클립보드가 비어 있습니다." with title "Markdrop"' >/dev/null 2>&1
	exit 0
fi

# 3) 첫 줄을 기반으로 파일명 생성
#    - 앞쪽의 공백/# 기호 제거, / 와 : 는 공백으로 치환, 최대 50자 (한글 안전)
first_line="$(printf '%s' "$content" | sed -n '1p')"
base="$(printf '%s' "$first_line" | perl -CS -ne 'chomp; s{[/:]}{ }g; s/^[\s#]+//; s/\s+$//; print substr($_,0,50)')"

# 첫 줄이 비면 기본값을 "클립보드"로
if [ -z "$base" ]; then
	base="클립보드"
fi

# 파일명 입력 창을 항상 띄운다. 기본값(첫 줄에서 만든 이름 또는 "클립보드")이
# 전체 선택된 상태로 떠서:
#   • 그냥 Enter → 기본값 그대로 저장
#   • 바로 타이핑 → 선택돼 있던 기본값이 지워지고 새 이름이 입력됨
# default answer에 base를 안전하게 넣기 위해 \ 와 " 를 이스케이프
esc_base="$(printf '%s' "$base" | sed 's/\\/\\\\/g; s/"/\\"/g')"
answer="$(osascript 2>/dev/null <<AS
tell application "Finder"
	activate
	set theResult to display dialog "저장할 파일 이름을 입력하세요." default answer "$esc_base" with title "Markdrop" buttons {"취소", "저장"} default button "저장"
end tell
return text returned of theResult
AS
)"
# 취소를 누르면 osascript가 0이 아닌 코드로 끝남 → 저장하지 않고 종료
if [ $? -ne 0 ]; then
	exit 0
fi
# 빈 채로 저장을 누르면 "클립보드"로 폴백
base="$answer"
if [ -z "$base" ]; then
	base="클립보드"
fi

# 같은 이름이 있으면 시각(HHMMSS)을 덧붙여 충돌 방지
filepath="$target_dir/$base.md"
if [ -e "$filepath" ]; then
	filepath="$target_dir/$base $(date +%H%M%S).md"
fi

# 4) 저장 (끝에 줄바꿈 보장)
printf '%s\n' "$content" > "$filepath"

# 완료 알림
osascript -e "display notification \"$(basename "$filepath")\" with title \"Markdrop ✓ 저장됨\"" >/dev/null 2>&1

exit 0
