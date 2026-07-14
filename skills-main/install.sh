#!/bin/bash
# TurboMesh Skills 安装脚本
#
# 用法：
#   curl -sL https://raw.githubusercontent.com/gaowenrong/skills/main/install.sh | bash
#   curl -sL https://raw.githubusercontent.com/gaowenrong/skills/main/install.sh | bash -s -- https://raw.githubusercontent.com/your-org/repo/main
#
set -e

REPO="${1:-https://raw.githubusercontent.com/gaowenrong/skills/main}"

echo "TurboMesh Skills Installer"
echo "=========================="
echo "Repository: $REPO"
echo ""

# 1. 检测 AI 工具目录
TARGET_DIR=""
TOOL_NAME=""

if [ -d ".claude" ]; then
    TARGET_DIR=".claude/commands"
    TOOL_NAME="Claude Code"
elif [ -d ".cursor" ]; then
    TARGET_DIR=".cursor/rules"
    TOOL_NAME="Cursor"
else
    echo "Error: No .claude/ or .cursor/ directory found in current path."
    echo "Please run this script from your project root, or initialize your AI tool first."
    exit 1
fi

echo "Detected tool: $TOOL_NAME"
echo "Install path:  $TARGET_DIR/"
echo ""

# 2. 读取 manifest
echo "Fetching manifest..."
MANIFEST=$(curl -sL "$REPO/manifest.json")

if [ -z "$MANIFEST" ] || echo "$MANIFEST" | grep -q "404"; then
    echo "Error: Failed to fetch manifest from $REPO"
    exit 1
fi

# 3. 解析技能列表
SKILLS=$(echo "$MANIFEST" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for s in data['skills']:
        print(s['id'])
except Exception as e:
    print(f'Error parsing manifest: {e}', file=sys.stderr)
    sys.exit(1)
")

if [ -z "$SKILLS" ]; then
    echo "Error: No skills found in manifest"
    exit 1
fi

# 4. 创建目录
mkdir -p "$TARGET_DIR"

# 5. 下载每个 SKILL.md
echo ""
INSTALLED=0
for SKILL in $SKILLS; do
    echo -n "  Installing $SKILL... "
    if curl -sL "$REPO/skills/$SKILL/SKILL.md" -o "$TARGET_DIR/$SKILL.md" 2>/dev/null; then
        if [ -s "$TARGET_DIR/$SKILL.md" ]; then
            echo "OK"
            INSTALLED=$((INSTALLED + 1))
        else
            echo "FAILED (empty file)"
            rm -f "$TARGET_DIR/$SKILL.md"
        fi
    else
        echo "FAILED (download error)"
    fi
done

echo ""
echo "=========================="
echo "Installed $INSTALLED skill(s) to $TARGET_DIR/"
echo ""
echo "Next steps:"
echo "  1. Open your project in $TOOL_NAME"
echo "  2. Ask your AI assistant to help you manage TurboMesh resources"
echo "  3. The assistant will prompt you to log in on first use"
echo ""
echo "Example: 'Help me list all my VMs on TurboMesh'"
