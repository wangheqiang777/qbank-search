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

// 强制所有 Android 模块(含插件如 file_picker)用 compileSdk=36。
// 插件自身按 flutter.compileSdkVersion 编译,但其依赖
// flutter_plugin_android_lifecycle 要求 >=35, 不强制会 checkAarMetadata 失败。
// AGP 9.0 默认 android.newDsl=true: 旧的 BaseExtension/compileSdkVersion 已废弃,
// 改用 com.android.build.api.dsl.LibraryExtension 的 compileSdk 属性。
// 用 gradle.projectsEvaluated 在所有工程配置完成后统一覆盖, 避免与
// 上方 evaluationDependsOn(":app") 冲突(Cannot run afterEvaluate when already evaluated)。
gradle.projectsEvaluated {
    rootProject.subprojects.forEach { sub ->
        sub.extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?.apply { compileSdk = 36 }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
