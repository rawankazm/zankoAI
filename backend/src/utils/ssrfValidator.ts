import { URL } from 'url';
import { BadRequestError } from './apiError.js';
import { SecurityLogger } from './securityLogger.js';

// Private IP range patterns
const PRIVATE_IP_REGEX = /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|169\.254\.|::1|0:0:0:0:0:0:0:1)/;

/**
 * Validates external URLs against SSRF (Server-Side Request Forgery) attacks.
 * Blocks requests targeting internal services, cloud metadata (169.254.169.254), or localhost.
 */
export function validateExternalUrl(urlString: string, allowedHostnames?: string[]): URL {
  let parsedUrl: URL;

  try {
    parsedUrl = new URL(urlString);
  } catch {
    throw new BadRequestError('Invalid URL provided');
  }

  // Enforce HTTP / HTTPS protocol only
  if (parsedUrl.protocol !== 'http:' && parsedUrl.protocol !== 'https:') {
    SecurityLogger.log({
      eventType: 'SSRF_ATTEMPT_BLOCKED',
      severity: 'CRITICAL',
      ip: 'server-internal',
      status: 'BLOCKED',
      details: { url: urlString, reason: `Disallowed protocol: ${parsedUrl.protocol}` },
    });
    throw new BadRequestError(`Protocol '${parsedUrl.protocol}' is not allowed`);
  }

  const hostname = parsedUrl.hostname.toLowerCase().trim();

  // Block localhost and loopback names
  if (
    hostname === 'localhost' ||
    hostname.endsWith('.localhost') ||
    hostname === '127.0.0.1' ||
    hostname === '0.0.0.0' ||
    hostname === '[::1]'
  ) {
    SecurityLogger.log({
      eventType: 'SSRF_ATTEMPT_BLOCKED',
      severity: 'CRITICAL',
      ip: 'server-internal',
      status: 'BLOCKED',
      details: { url: urlString, reason: 'Targeting localhost/loopback' },
    });
    throw new BadRequestError('Access to local/loopback network addresses is prohibited');
  }

  // Block private and cloud metadata IPs
  if (PRIVATE_IP_REGEX.test(hostname)) {
    SecurityLogger.log({
      eventType: 'SSRF_ATTEMPT_BLOCKED',
      severity: 'CRITICAL',
      ip: 'server-internal',
      status: 'BLOCKED',
      details: { url: urlString, reason: 'Targeting private or link-local network' },
    });
    throw new BadRequestError('Access to private or internal network addresses is prohibited');
  }

  // If specific allowed hostnames are required, verify against whitelist
  if (allowedHostnames && allowedHostnames.length > 0) {
    const isAllowed = allowedHostnames.some(
      (allowed) => hostname === allowed.toLowerCase() || hostname.endsWith(`.${allowed.toLowerCase()}`)
    );

    if (!isAllowed) {
      SecurityLogger.log({
        eventType: 'SSRF_ATTEMPT_BLOCKED',
        severity: 'WARN',
        ip: 'server-internal',
        status: 'BLOCKED',
        details: { url: urlString, reason: 'Hostname not in allowed list' },
      });
      throw new BadRequestError(`Domain '${hostname}' is not authorized for external fetching`);
    }
  }

  return parsedUrl;
}
