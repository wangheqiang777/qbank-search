import com.android.build.gradle.LibraryPlugin
import com.android.build.api.dsl.LibraryExtension
import com.android.build.api.extension.AndroidComponentsExtension

buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    dependencies {
        // 暴露 AndroidComponentsExtension 到根脚本 classpath: apply false 只把 gradle 实现 jar 带上,
        // 其 extension 包(com.android.build.api.extension)在 gradle-api 里(transitive 不暴露给脚本编译),
        // 故显式引入, 以便类型化调用 finalizeDsl 强制库模块 compileSdk=36.
        classpath("com.android.tools.build:gradle-api:9.0.1")
    }
}

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
// afterEvaluate 直接设 compileSdk 会触发 AGP "It is too late to set compileSdk"(配置期已读取),
// 必须用 finalizeDsl 在 DSL 锁定前注入。AndroidComponentsExtension 已通过 buildscript 的 gradle-api 暴露到 classpath。
subprojects {
    plugins.withType(LibraryPlugin::class.java).configureEach {
        // afterEvaluate 时 androidComponents 扩展一定已注册; 在此注册 finalizeDsl 动作,
        // 该动作会在 DSL 锁定前的 finalize 阶段执行, 把 compileSdk 强制为 36(不算 too late)。
        afterEvaluate {
            extensions.getByType(AndroidComponentsExtension::class.java).finalizeDsl { extension ->
                extension.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
