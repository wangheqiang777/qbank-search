#!/usr/bin/env python3
"""
向 Flutter 生成的 iOS 工程注入一个 Broadcast Upload Extension 目标，
用于「录屏搜题 / 悬浮窗自动扫描」。

做法：纯文本补丁（镜像现有 Runner target 的结构），不使用 xcodeproj gem。
改完用 mod_pbxproj 重新 load 校验结构合法性。

运行：python tools/patch_pbxproj.py
（默认改 app/ios/Runner.xcodeproj/project.pbxproj，可传参指定路径）
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.join(HERE, "..", "app", "ios", "Runner.xcodeproj", "project.pbxproj")


def gen_ids(text, n):
    """生成 n 个 24 位大写十六进制、且与现有 ID 不重复的 UUID。"""
    existing = set(re.findall(r"[0-9A-F]{24}", text))
    out = []
    import random
    while len(out) < n:
        cand = "".join(random.choice("0123456789ABCDEF") for _ in range(24))
        if cand not in existing and cand not in out:
            out.append(cand)
            existing.add(cand)
    return out


def insert_before(text, section_marker, block):
    """在 `/* End <section> section */` 之前插入 block。"""
    end = text.rfind(section_marker)
    if end == -1:
        raise RuntimeError(f"找不到段落标记: {section_marker}")
    return text[:end] + block + text[end:]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    path = os.path.abspath(path)
    with open(path, "r", encoding="utf-8") as f:
        t = f.read()

    # 是否已经打过补丁（防止重复运行）
    if "BroadcastUploadExtension" in t and "Embed App Extensions" in t:
        print("看起来已经注入过扩展目标，跳过。")
        return

    (EXT_TGT, EXT_PROD, EXT_SRC_FR, EXT_PLIST_FR, EXT_ENT_FR, RUN_ENT_FR,
     EXT_GRP, EXT_SRC_BF, EXT_EMB_BF, EXT_SRC_PH, EXT_FW_PH, EXT_RES_PH,
     EXT_CFG_LIST, EXT_CFG_D, EXT_CFG_R, EXT_CFG_P, EMBED_PH) = gen_ids(t, 17)

    # ---- PBXBuildFile ----
    t = insert_before(t, "/* End PBXBuildFile section */", f"""\
\t\t{EXT_SRC_BF} /* BroadcastUploadExtension.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {EXT_SRC_FR} /* BroadcastUploadExtension.swift */; }};
\t\t{EXT_EMB_BF} /* BroadcastUploadExtension.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {EXT_PROD} /* BroadcastUploadExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
""")

    # ---- PBXFileReference ----
    t = insert_before(t, "/* End PBXFileReference section */", f"""\
\t\t{EXT_PROD} /* BroadcastUploadExtension.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = BroadcastUploadExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{EXT_SRC_FR} /* BroadcastUploadExtension.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = BroadcastUploadExtension.swift; sourceTree = "<group>"; }};
\t\t{EXT_PLIST_FR} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = Info.plist; path = BroadcastUploadExtension/Info.plist; sourceTree = "<group>"; }};
\t\t{EXT_ENT_FR} /* BroadcastUploadExtension.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; name = BroadcastUploadExtension.entitlements; path = BroadcastUploadExtension/BroadcastUploadExtension.entitlements; sourceTree = "<group>"; }};
\t\t{RUN_ENT_FR} /* Runner.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; name = Runner.entitlements; path = Runner/Runner.entitlements; sourceTree = "<group>"; }};
""")

    # ---- PBXFrameworksBuildPhase (extension) ----
    t = insert_before(t, "/* End PBXFrameworksBuildPhase section */", f"""\
\t\t{EXT_FW_PH} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")

    # ---- PBXGroup: 扩展 group + 产品进 Products + entitlements 进 Runner + 主组引用 ----
    t = insert_before(t, "/* End PBXGroup section */", f"""\
\t\t{EXT_GRP} /* BroadcastUploadExtension */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{EXT_SRC_FR} /* BroadcastUploadExtension.swift */,
\t\t\t\t{EXT_PLIST_FR} /* Info.plist */,
\t\t\t\t{EXT_ENT_FR} /* BroadcastUploadExtension.entitlements */,
\t\t\t);
\t\t\tpath = BroadcastUploadExtension;
\t\t\tsourceTree = "<group>";
\t\t}};
""")
    # Products 组加入扩展产品
    t = t.replace(
        """\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,
\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,""",
        f"""\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,
\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,
\t\t\t{EXT_PROD} /* BroadcastUploadExtension.appex */,""",
    )
    # Runner 组加入 entitlements
    t = t.replace(
        """\t\t\t74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,
\t\t);
\t\tpath = Runner;""",
        f"""\t\t\t74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,
\t\t\t{RUN_ENT_FR} /* Runner.entitlements */,
\t\t);
\t\tpath = Runner;""",
    )
    # 主组加入扩展 group
    t = t.replace(
        """\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,
\t\t);""",
        f"""\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,
\t\t\t{EXT_GRP} /* BroadcastUploadExtension */,
\t\t);""",
    )

    # ---- PBXNativeTarget ----
    t = insert_before(t, "/* End PBXNativeTarget section */", f"""\
\t\t{EXT_TGT} /* BroadcastUploadExtension */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {EXT_CFG_LIST} /* Build configuration list for PBXNativeTarget "BroadcastUploadExtension" */;
\t\t\tbuildPhases = (
\t\t\t\t{EXT_SRC_PH} /* Sources */,
\t\t\t\t{EXT_FW_PH} /* Frameworks */,
\t\t\t\t{EXT_RES_PH} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = BroadcastUploadExtension;
\t\t\tproductName = BroadcastUploadExtension;
\t\t\tproductReference = {EXT_PROD} /* BroadcastUploadExtension.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
""")

    # ---- PBXResourcesBuildPhase (extension) ----
    t = insert_before(t, "/* End PBXResourcesBuildPhase section */", f"""\
\t\t{EXT_RES_PH} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")

    # ---- PBXSourcesBuildPhase (extension) ----
    t = insert_before(t, "/* End PBXSourcesBuildPhase section */", f"""\
\t\t{EXT_SRC_PH} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{EXT_SRC_BF} /* BroadcastUploadExtension.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")

    # ---- PBXCopyFilesBuildPhase: Embed App Extensions (加入主 App) ----
    t = insert_before(t, "/* End PBXCopyFilesBuildPhase section */", f"""\
\t\t{EMBED_PH} /* Embed App Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{EXT_EMB_BF} /* BroadcastUploadExtension.appex in Embed App Extensions */,
\t\t\t);
\t\t\tname = "Embed App Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")
    # 主 App 的 buildPhases 加入 Embed App Extensions
    t = t.replace(
        """\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,
\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,""",
        f"""\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,
\t\t\t{EMBED_PH} /* Embed App Extensions */,
\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,""",
    )

    # ---- XCBuildConfiguration (extension Debug/Release/Profile) ----
    # 用模板生成三个配置
    def cfg_block(cid, name):
        return f"""\
\t\t{cid} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "BroadcastUploadExtension/BroadcastUploadExtension.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";
\t\t\t\tENABLE_BITCODE = NO;
\t\t\t\tINFOPLIST_FILE = "BroadcastUploadExtension/Info.plist";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.example.qbankSearch.broadcast";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tVERSIONING_SYSTEM = "apple-generic";
\t\t\t}};
\t\t\tname = {name};
\t\t}};
"""
    t = insert_before(t, "/* End XCBuildConfiguration section */",
                      cfg_block(EXT_CFG_D, "Debug") + cfg_block(EXT_CFG_R, "Release") + cfg_block(EXT_CFG_P, "Profile"))

    # ---- XCConfigurationList (extension) ----
    t = insert_before(t, "/* End XCConfigurationList section */", f"""\
\t\t{EXT_CFG_LIST} /* Build configuration list for PBXNativeTarget "BroadcastUploadExtension" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{EXT_CFG_D} /* Debug */,
\t\t\t\t{EXT_CFG_R} /* Release */,
\t\t\t\t{EXT_CFG_P} /* Profile */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
""")

    # ---- PBXProject targets 加入扩展 ----
    t = t.replace(
        """\t\t\ttargets = (
\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,
\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,
\t\t\t);""",
        f"""\t\t\ttargets = (
\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,
\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,
\t\t\t\t{EXT_TGT} /* BroadcastUploadExtension */,
\t\t\t);""",
    )

    # ---- 主 App 三个配置加 CODE_SIGN_ENTITLEMENTS ----
    t = t.replace(
        """\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.qbankSearch;
\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";""",
        """\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.qbankSearch;
\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\tCODE_SIGN_ENTITLEMENTS = "Runner/Runner.entitlements";""",
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(t)

    print("pbxproj 补丁写入完成。")


if __name__ == "__main__":
    main()
