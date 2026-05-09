import com.android.build.api.dsl.ApplicationExtension
import com.android.build.gradle.LibraryExtension

val enforcedCompileSdk = 35

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
    plugins.withId("com.android.application") {
        extensions.configure<ApplicationExtension> {
            if ((compileSdk ?: 0) < enforcedCompileSdk) {
                compileSdk = enforcedCompileSdk
            }
        }
    }

    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            if ((compileSdk ?: 0) < enforcedCompileSdk) {
                compileSdk = enforcedCompileSdk
            }
            if (namespace.isNullOrBlank()) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val packageMatch = Regex("""package\s*=\s*"([^"]+)"""")
                        .find(manifestFile.readText())
                    if (packageMatch != null) {
                        namespace = packageMatch.groupValues[1]
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
