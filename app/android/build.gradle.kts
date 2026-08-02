import com.android.build.gradle.LibraryPlugin
import com.android.build.api.dsl.LibraryExtension
import com.android.build.api.extension.AndroidComponentsExtension

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
// 必须在 finalizeDsl(android 块执行后、DSL 模型锁定前)注入: 直接写在配置期会被插件自身的
// android { compileSdk = 34 } 覆盖; AGP 9.0 方法名是小写 finalizeDsl (老 finalizeDSl 已移除)。
// AGP 9.0 中 androidComponents 不是 LibraryExtension 的可解析成员属性, 需通过
// extensions.getByType(AndroidComponentsExtension) 取出后调用 finalizeDsl。
subprojects {
    plugins.withType(LibraryPlugin::class.java).configureEach {
        val lib = extensions.getByType(LibraryExtension::class.java)
        extensions.getByType(AndroidComponentsExtension::class.java).finalizeDsl {
            lib.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
