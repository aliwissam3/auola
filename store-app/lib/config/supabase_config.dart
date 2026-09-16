/// Fill these in after creating your Supabase project and running
/// supabase/schema.sql in its SQL editor (see README.md). The anon key is
/// meant to be public — it's safe to ship inside the app; every table it can
/// reach is protected by the row-level-security policies in schema.sql.
///
/// You can also set these at build time instead of editing this file, e.g.:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT.supabase.co',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR-ANON-KEY',
  );

  static bool get isConfigured => !url.contains('YOUR-PROJECT') && !anonKey.contains('YOUR-ANON-KEY');
}
