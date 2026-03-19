allprojects {
    repositories {
        google()
        mavenCentral() // Fix: Das 'e' hat gefehlt
    }
}

// Definiert das Build-Verzeichnis zentral
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Der Fix für den Bluetooth-Dino (Namespace-Injektion)
subprojects {
    project.plugins.configureEach {
        if (this is com.android.build.gradle.api.AndroidBasePlugin || 
            this.javaClass.name.contains("com.android.build.gradle.LibraryPlugin")) {
            
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.apply {
                if (namespace == null) {
                    namespace = project.group.toString().ifEmpty { "temp.namespace.${project.name}" }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}