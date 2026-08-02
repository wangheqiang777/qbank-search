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
// afterEvaluate 设 compileSdk 会触发 AGP "It is too late to set compileSdk"(配置期已读取), 必须改用
// finalizeDsl 在 DSL 锁定前注入。但 AndroidComponentsExtension 类型不在根脚本 classpath
// (plugins { id("com.android.library") apply false } 只把 AGP 实现 jar 带上, 不带 gradle-api),
// 故用反射按扩展名 "androidComponents" 取出该扩展, 再反射调 finalizeDsl: 仅依赖已可用的
// LibraryExtension(用于强制 compileSdk=36) 与 org.gradle.api.Action。
subprojects {
    plugins.withType(LibraryPlugin::class.java).configureEach {
        // afterEvaluate 时 androidComponents 扩展一定已注册; 此时注册 finalizeDsl 动作仍会在
        // DSL 锁定前的 finalize 阶段执行(AGP 设计如此, 不算 "too late"), 从而把 compileSdk 强制为 36。
        afterEvaluate {
            val components = extensions.findByName("androidComponents") ?: return@afterEvaluate
            val finalizeDsl = components.javaClass.getMethod(
                "finalizeDsl",
                org.gradle.api.Action::class.java
            )
            finalizeDsl.invoke(
                components,
                org.gradle.api.Action<Any> {
                    val lib = this as com.android.build.api.dsl.LibraryExtension
                    lib.compileSdk = 36
                }
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
