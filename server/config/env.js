/**
 * Environment validation, run once at boot.
 *
 * Everything here fails loudly at startup rather than quietly at request time.
 * The previous code wrote `process.env.JWT_SECRET || 'super_secret_...'` in
 * three places, which meant a server with no configuration came up happily and
 * signed tokens with a secret published in this repository.
 */

/** Secrets that have appeared in the repo and must never protect real data. */
const COMPROMISED_SECRETS = new Set([
  'super_secret_jwt_key_civic_connect_123',
  'changeme',
  'secret',
]);

const MIN_SECRET_LENGTH = 16;

function required(name) {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(
      `${name} is not set. Copy .env.example to .env and fill it in — ` +
        'the server will not start without it.'
    );
  }
  return value.trim();
}

function optional(name, fallback) {
  const value = process.env[name];
  return value && value.trim() ? value.trim() : fallback;
}

function loadConfig() {
  const jwtSecret = required('JWT_SECRET');
  const warnings = [];

  // Weak secrets warn rather than throw: refusing to boot would strand anyone
  // running the documented demo configuration. The warning is deliberately
  // impossible to miss in a terminal.
  if (COMPROMISED_SECRETS.has(jwtSecret)) {
    warnings.push(
      'JWT_SECRET is the placeholder value published in this repository. ' +
        'Anyone can forge a session token. Replace it before this server is ' +
        'reachable by anyone but you.'
    );
  } else if (jwtSecret.length < MIN_SECRET_LENGTH) {
    warnings.push(
      `JWT_SECRET is only ${jwtSecret.length} characters. Use at least ` +
        `${MIN_SECRET_LENGTH}, ideally from \`openssl rand -base64 32\`.`
    );
  }

  const corsOrigins = optional('CORS_ORIGINS', '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (corsOrigins.length === 0) {
    warnings.push(
      'CORS_ORIGINS is not set, so every origin is allowed. Fine for local ' +
        'development; set it to your web origins before deploying.'
    );
  }

  return {
    port: parseInt(optional('PORT', '5000'), 10),
    mongoUri: required('MONGO_URI'),
    jwtSecret,
    apiUrl: optional('API_URL', 'http://localhost:5000'),
    googleClientIds: optional('GOOGLE_CLIENT_IDS', optional('GOOGLE_CLIENT_ID', ''))
      .split(',')
      .map((id) => id.trim())
      .filter(Boolean),
    corsOrigins,
    isProduction: optional('NODE_ENV', 'development') === 'production',
    warnings,
  };
}

let config;
try {
  config = loadConfig();
} catch (error) {
  console.error(`\nConfiguration error: ${error.message}\n`);
  process.exit(1);
}

/** Prints accumulated warnings. Called once from the entrypoint. */
config.reportWarnings = function reportWarnings() {
  for (const warning of this.warnings) {
    console.warn(`  WARNING  ${warning}`);
  }
  if (this.warnings.length > 0) console.warn('');
};

module.exports = config;
