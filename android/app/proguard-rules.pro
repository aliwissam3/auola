# google_mlkit_text_recognition references optional per-language
# recognizer classes (Chinese/Japanese/Korean/Devanagari) that this app
# never uses (and doesn't pull in the corresponding ML Kit language
# model dependency for) - R8 fails release minification outright unless
# told these are safe to leave unresolved.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
