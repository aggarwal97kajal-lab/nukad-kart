/// Keys that ship inside the app (they are visible to anyone who opens the APK,
/// so each must be restricted / monitored in its own dashboard).
/// Never put server secrets here (MSG91 AuthKey, Cloudflare tokens, etc.).
const olaMapsApiKey = 'MP1g7XbAgVKrnCf6reh5yJyXPDWfPLM7RIJbx2YH';
const olaMapsProjectId = '2786de8f-21d0-4944-96bc-b1cbfccb0e93';

/// Google "Web client" ID from Firebase (client_type 3 in google-services.json).
/// The app asks Google for an ID token meant for this client; the server checks it.
const googleWebClientId = '173237735756-8p39j4pk1ekmtuvepo32enp4beqtst9g.apps.googleusercontent.com';

/// Nukad Kart API (Cloudflare Worker).
const apiBase = 'https://nukad-kart-api.aggarwal97kajal.workers.dev';
