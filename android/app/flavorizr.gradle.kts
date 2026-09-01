import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("dev") {
            dimension = "flavor-type"
            applicationId = "com.example.my_diary.dev"
            resValue(type = "string", name = "app_name", value = "My Diary Dev")
        }
        create("prod") {
            dimension = "flavor-type"
            applicationId = "com.example.my_diary"
            resValue(type = "string", name = "app_name", value = "My Diary Prod")
        }
    }
}