import org.gradle.plugins.ide.idea.model.IdeaModel

plugins {
    // this is necessary to avoid the plugins to be loaded multiple times
    // in each subproject's classloader
    alias(libs.plugins.androidApplication) apply false
    alias(libs.plugins.androidLibrary) apply false
    alias(libs.plugins.composeMultiplatform) apply false
    alias(libs.plugins.composeCompiler) apply false
    alias(libs.plugins.kotlinMultiplatform) apply false
    id("idea")
}

configure<IdeaModel> {
    module {
        excludeDirs.add(file("ios_build"))
    }
}