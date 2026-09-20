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
    project.evaluationDependsOn(":app")

    if (project.path == ":app") {
        project.layout.buildDirectory.value(newBuildDir.dir(project.name))
    }

    if (project.path != ":app") {
        tasks.withType<org.gradle.api.tasks.testing.Test>().configureEach {
            enabled = false
        }
        tasks.matching { it.name.startsWith("lint") }.configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
