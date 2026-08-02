import com.android.build.gradle.LibraryPlugin
import com.android.build.api.dsl.LibraryExtension

plugins {
    // 在根脚本引入 AGP 的 library 插件(apply false), 使其类型(LibraryPlugin/LibraryExtension)
    // 可被本文件 import 与引用. 版本由 settings.gradle.kts 统一声明, 这里不带 version,
    // 避免与 classpath 上已通过 com.android.application 引入的 AGP 包冲突.
    id("com.android.library") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 强制所有 Android 库/插件模块(library plugin)用 compileSdk=36。
// 仅 App 模块设 36 不够: file_picker 等插件模块自身用自己 build.gradle 里的低版本(34)编译,
// 其 checkReleaseAarMetadata 会因依赖 flutter_plugin_android_lifecycle 要求的 minCompileSdk 失败。
// Flutter 的 detectLowCompileSdkVersionOrNdkVersion 只打警告、不强制改插件 compileSdk, 故必须在此强制。
// 用 afterEvaluate 在模块自身 android { compileSdk = 34 } 执行之后再覆盖为 36, 确保生效。
// (finalizeDsl / AndroidComponentsExtension 在根脚本 classpath 无法解析, 故不采用该写法。)
subprojects {
    plugins.withType(LibraryPlugin::class.java).configureEach {
        afterEvaluate {
            extensions.getByType(LibraryExtension::class.java).compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
