#!/usr/bin/env python3
"""
给 Runner 主 App 添加对 BroadcastUploadExtension 的 PBXTargetDependency，
这样 Xcode 构建 Runner 时会连带编译并嵌入扩展（buildImplicitDependencies=YES）。

幂等：已加过则跳过。
"""
import os
import re
import sys
import random

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.join(HERE, "..", "app", "ios", "Runner.xcodeproj", "project.pbxproj")


def gen_ids(text, n):
    existing = set(re.findall(r"[0-9A-F]{24}", text))
    out = []
    while len(out) < n:
        cand = "".join(random.choice("0123456789ABCDEF") for _ in range(24))
        if cand not in existing and cand not in out:
            out.append(cand)
            existing.add(cand)
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    path = os.path.abspath(path)
    with open(path, "r", encoding="utf-8") as f:
        t = f.read()

    if "BroadcastUploadExtensionDependency" in t:
        print("依赖已存在，跳过。")
        return

    # 找到扩展 target 的 ID：匹配  /* BroadcastUploadExtension */ = { ... PBXNativeTarget
    m = re.search(r"([0-9A-F]{24})\s*/\*\s*BroadcastUploadExtension\s*\*/\s*=\s*\{[^}]*productType = \"com\.apple\.product-type\.app-extension\"", t, re.S)
    if not m:
        raise RuntimeError("找不到 BroadcastUploadExtension target")
    ext_tgt = m.group(1)
    runner_tgt = "97C146ED1CF9000F007C117D"  # Runner target（已知）

    proxy_id, dep_id = gen_ids(t, 2)
    proj_obj = "97C146E61CF9000F007C117D"  # Project object（已知）

    # ---- PBXContainerItemProxy ----
    t = t.replace(
        "/* End PBXContainerItemProxy section */",
        f"""\t\t{proxy_id} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {proj_obj} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ext_tgt};
\t\t\tremoteInfo = BroadcastUploadExtension;
\t\t}};
/* End PBXContainerItemProxy section */""",
        1,
    )

    # ---- PBXTargetDependency ----
    t = t.replace(
        "/* End PBXTargetDependency section */",
        f"""\t\t{dep_id} /* BroadcastUploadExtensionDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ext_tgt} /* BroadcastUploadExtension */;
\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */""",
        1,
    )

    # ---- Runner dependencies 列表加入 ----
    t = t.replace(
        f"\t\t\t{runner_tgt} /* Runner */ = {{\n\t\t\tisa = PBXNativeTarget;",
        f"\t\t\t{runner_tgt} /* Runner */ = {{\n\t\t\tisa = PBXNativeTarget;\n\t\t\t// BroadcastUploadExtensionDependency anchor",
        1,
    )
    # 在 Runner 的 dependencies = ( 之后插入
    t = t.replace(
        "\t\t\t\tdependencies = (\n\t\t\t\t);",
        f"\t\t\t\tdependencies = (\n\t\t\t\t\t{dep_id} /* BroadcastUploadExtensionDependency */,\n\t\t\t\t);",
        1,
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(t)
    print("依赖补丁写入完成。")


if __name__ == "__main__":
    main()
