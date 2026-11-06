plugins {
    id("com.android.library")
    id("kotlin-android")
    id("kotlin-parcelize")
}

android {
    namespace = "io.legado.app"
    compileSdk = 36

    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-rules.pro")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        freeCompilerArgs += listOf("-Xjvm-default=all")
    }

    lint {
        abortOnError = false
    }

    buildFeatures {
        buildConfig = true
    }

    // 引擎的规则求值是纯逻辑，单测在 JVM 上跑；Android 框架方法（TextUtils 等）
    // 返回默认值即可，避免为一句 isEmpty 引入 Robolectric。
    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    // hutool 系 jar 各自带 META-INF/INDEX.LIST，合并 test APK 时同样会冲突
    packaging {
        resources {
            excludes += setOf(
                "META-INF/INDEX.LIST",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
            )
        }
    }
}

dependencies {
    api(project(":legado-rhino"))

    implementation("org.jsoup:jsoup:1.16.2")
    implementation("com.google.code.gson:gson:2.13.2")
    implementation("com.squareup.okhttp3:okhttp:5.3.2")
    implementation("cn.hutool:hutool-crypto:5.8.22")
    implementation("cn.hutool:hutool-core:5.8.22")
    implementation("org.apache.commons:commons-text:1.13.1")
    implementation("com.jayway.jsonpath:json-path:2.10.0")
    implementation("cn.wanghaomiao:JsoupXpath:2.5.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("androidx.annotation:annotation:1.9.1")
    implementation("androidx.collection:collection:1.5.0")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.room:room-runtime:2.7.1")
    implementation("com.google.android.flexbox:flexbox:3.0.0")
    // 封面请求头与音频播放地址：AnalyzeUrl 的类型签名依赖这两个库（P4 会换成 Flutter 侧实现）
    implementation("com.github.bumptech.glide:glide:4.16.0")
    implementation("androidx.media3:media3-common:1.4.1")

    testImplementation("junit:junit:4.13.2")

    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")
}
