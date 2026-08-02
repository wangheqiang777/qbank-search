import com.android.build.gradle.LibraryPlugin
import com.android.build.api.extension.AndroidComponentsExtension

plugins {
    // 在根脚本引入 AGP，使其类型(AndroidComponentsExtension/LibraryPlugin)可被本文件 import。
    // 注意: 仅 apply false，不应用到根工程本身(根工程不是 Android 工程)。
    id("com.android.library") version "9.0.1" apply false
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
// 仅 App 模块设 36 不够: file_picker 等插件模块自身也需 36，否则其
// checkReleaseAarMetadata 会因 flutter_plugin_android_lifecycle 要求的 minCompileSdk 失败。
// AGP 9.0 必须在 finalizeDsl(DSL 收尾、模型锁定前)注入，
// 在 afterEvaluate/projectsEvaluated 里设会报 "too late to set compileSdk"。
subprojects {
    plugins.withType(LibraryPlugin::class.java).configureEach {
        extensions
            .getByType(AndroidComponentsExtension::class.java)
            .finalizeDsl {
                compileSdk = 36
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
