/// App-wide public endpoints (not secrets). Single source of truth.
library;

/// Cloudflare Worker video API (`workers/video`): `/createVideoUpload`,
/// `/finalizeVideoUpload`. Same URL on Android and iOS; no build-time
/// variables are needed.
const kVideoApiBaseUrl = 'https://myfit-video.myfit-app.workers.dev';
