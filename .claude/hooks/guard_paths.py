"""PreToolUse hook: bloqueia Edit/Write em arquivos que não deveriam ser
tocados por IA: cache gerado pela Editor Godot (.godot/), o preset de export
Android (export_presets.cfg, específico da máquina) e chaves de assinatura
Android (.keystore/.jks)."""

import json
import sys


def main() -> None:
    data = json.load(sys.stdin)
    file_path = data.get("tool_input", {}).get("file_path", "")
    normalized = file_path.replace("\\", "/")

    blocked = (
        "/.godot/" in normalized
        or normalized.startswith(".godot/")
        or normalized.endswith("/export_presets.cfg")
        or normalized == "export_presets.cfg"
        or normalized.endswith(".keystore")
        or normalized.endswith(".jks")
    )

    if not blocked:
        return

    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        f"Edição bloqueada por hook: {file_path} é cache/config "
                        "sensível (.godot/, export_presets.cfg ou keystore Android)."
                    ),
                }
            }
        )
    )


if __name__ == "__main__":
    main()
