// Set at build time with `--dart-define-from-file=env.json` (see
// env.example.json). The anon key is public by design; row-level security
// protects the data.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// The live CraftCebu site. Point it at `http://localhost:5173` to try site
/// changes in the app before they deploy.
const homeUrl = String.fromEnvironment('HOME_URL', defaultValue: 'https://craftcebu.vercel.app');
