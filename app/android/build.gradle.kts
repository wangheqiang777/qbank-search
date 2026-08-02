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

// 注：原“强制所有插件模块 compileSdk=36”的根脚本块已移除。
// 根工程未应用 Android 插件，无法 import AGP 类型(AndroidComponentsExtension/LibraryPlugin)，
// 导致 build.gradle.kts 编译报错。Flutter 插件的 aar 元数据检查由 App 模块的
// compileSdk(见 app/build.gradle.kts 的 compileSdk=36) 满足即可，无需在根脚本强制。

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
