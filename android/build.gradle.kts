import com.android.build.gradle.LibraryExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

subprojects {
    // --- Fix 1: Force Kotlin to use Java 1.8 (Using Text Arguments) ---
    // We use freeCompilerArgs because your script cannot 'see' the JvmTarget Enum class.
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            freeCompilerArgs.add("-jvm-target=1.8")
        }
    }

    // --- Fix 2: Auto-generate Namespace (For AGP 8.0+) ---
    fun fixNamespace(proj: Project) {
        if (proj.plugins.hasPlugin("com.android.library")) {
            proj.extensions.configure<LibraryExtension> {
                // Only set the namespace if it's missing
                if (namespace == null) {
                    namespace = proj.group.toString()
                }
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }

    // Apply the namespace fix safely
    if (state.executed) {
        fixNamespace(this)
    } else {
        afterEvaluate {
            fixNamespace(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
