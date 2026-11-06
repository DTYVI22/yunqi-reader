# Rhino: 脚本引擎全部走反射与动态类，禁止混淆/裁剪
-keep class org.mozilla.javascript.** { *; }
-keep class com.script.** { *; }
-dontwarn org.mozilla.javascript.**

# 书源实体与规则：Gson 反射按字段名读写
-keep class io.legado.app.data.entities.** { *; }
-keep class io.legado.app.data.entities.rule.** { *; }

# Jsoup / JsonPath
-keep class org.jsoup.** { *; }
-dontwarn org.jsoup.**
-keep class com.jayway.jsonpath.** { *; }
-dontwarn com.jayway.jsonpath.**
