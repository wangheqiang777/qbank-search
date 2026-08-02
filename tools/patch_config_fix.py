#!/usr/bin/env python3
"""
修复 BroadcastUploadExtension 的 XCBuildConfiguration：
- 加入 baseConfigurationReference 指向 Flutter 的 Release.xcconfig，
  使 $(FLUTTER_BUILD_NAME)/$(FLUTTER_BUILD_NUMBER) 能解析；
- 把 CURRENT_PROJECT_VERSION 的 $(FLUTTER_BUILD_NUMBER) 改成字面值 "1"。

只作用于含 com.example.qbankSearch.broadcast 的配置块。幂等。
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.join(HERE, "..", "app", "ios", "Runner.xcodeproj", "project.pbxproj")

XCCONFIG_REF = "7AFA3C8E1D35360C0083082E /* Release.xcconfig */"


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    path = os.path.abspath(path)
    with open(path, "r", encoding="utf-8") as f:
        t = f.read()

    if "EXT_BASECONFIG_PATCHED" in t:
        print("配置修复已存在，跳过。")
        return

    pat = re.compile(
        r"(/\* (?:Debug|Release|Profile) \*/ = \{\n\s*isa = XCBuildConfiguration;\n)"
        r"(?P<body>.*?com\.example\.qbankSearch\.broadcast.*?)\n\t\t\};",
        re.S,
    )

    def repl(m):
        start = m.group(1)
        body = m.group("body")
        # 加 base config 引用
        if "baseConfigurationReference" not in body:
            start += f"\t\t\tbaseConfigurationReference = {XCCONFIG_REF};\n"
        # CURRENT_PROJECT_VERSION 改字面值
        body = body.replace(
            'CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";',
            'CURRENT_PROJECT_VERSION = "1";',
        )
        return start + body + "\n\t\t};"

    new_t, n = pat.subn(repl, t)
    if n == 0:
        raise RuntimeError("未找到扩展配置块")
    # 打标记，避免重复
    new_t = new_t.replace(
        'productType = "com.apple.product-type.app-extension";',
        'productType = "com.apple.product-type.app-extension"; // EXT_BASECONFIG_PATCHED',
        1,
    )
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_t)
    print(f"配置修复完成，命中 {n} 个扩展配置。")


if __name__ == "__main__":
    main()
