import com.android.build.api.dsl.LibraryExtension
import com.android.build.gradle.LibraryPlugin

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

// 强制所有 Flutter 插件(Library)模块用 compileSdk=36。
// 失败原因：编译依赖(如 flutter_plugin_android_lifecycle)要求 compileSdk>=36，
// 而插件默认按 flutter.compileSdkVersion(34) 编译，checkReleaseAarMetadata 会失败。
// AGP 9.0 在 evaluation 阶段即锁定 compileSdk，gradle.projectsEvaluated 已太晚
// (报错 "It is too late to set compileSdk")。正确位置是 androidComponents.finalizeDsl
// —— 在 DSL 正式收尾前修改，由 com.android.library 插件应用时注册。
subprojects {
    plugins.withType(LibraryPlugin::class.java).configureEach {
        val lib = extensions.getByType(LibraryExtension::class.java)
        lib.androidComponents {
            finalizeDsl {
                lib.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
