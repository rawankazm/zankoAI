// ==============================================================================
// ZankoAI Native Response Compression Middleware
// Uses node:zlib built-in compression with 1KB threshold
// ==============================================================================

import { Request, Response, NextFunction } from 'express';
import zlib from 'node:zlib';

const MIN_COMPRESSION_SIZE = 1024; // 1 KB threshold

const COMPRESSIBLE_TYPES = [
  'application/json',
  'text/plain',
  'text/html',
  'text/css',
  'application/javascript',
  'application/xml',
  'text/xml',
];

export const compressionMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  const acceptEncoding = (req.headers['accept-encoding'] as string) || '';

  const supportsGzip = acceptEncoding.includes('gzip');
  const supportsDeflate = acceptEncoding.includes('deflate');

  if (!supportsGzip && !supportsDeflate) {
    return next();
  }

  // Intercept res.send
  const originalSend = res.send.bind(res);

  res.send = (body: any): Response => {
    // If headers already sent or content-encoding already configured, pass through
    if (res.headersSent || res.getHeader('Content-Encoding')) {
      return originalSend(body);
    }

    // Always signal caches that response varies by Accept-Encoding
    res.setHeader('Vary', 'Accept-Encoding');

    // Convert body to Buffer for size inspection
    let buffer: Buffer;
    if (Buffer.isBuffer(body)) {
      buffer = body;
    } else if (typeof body === 'string') {
      buffer = Buffer.from(body, 'utf-8');
    } else if (typeof body === 'object' && body !== null) {
      try {
        const jsonStr = JSON.stringify(body);
        buffer = Buffer.from(jsonStr, 'utf-8');
        if (!res.getHeader('Content-Type')) {
          res.setHeader('Content-Type', 'application/json; charset=utf-8');
        }
      } catch {
        return originalSend(body);
      }
    } else {
      return originalSend(body);
    }

    // Skip compression if payload is smaller than threshold
    if (buffer.length < MIN_COMPRESSION_SIZE) {
      return originalSend(buffer);
    }

    // Check if Content-Type is compressible
    const contentType = (res.getHeader('Content-Type') as string) || '';
    const isCompressible = COMPRESSIBLE_TYPES.some(type => contentType.toLowerCase().includes(type));

    if (!isCompressible && contentType) {
      return originalSend(buffer);
    }

    try {
      if (supportsGzip) {
        const compressed = zlib.gzipSync(buffer, { level: 6 });
        res.setHeader('Content-Encoding', 'gzip');
        res.setHeader('Content-Length', compressed.length);
        return originalSend(compressed);
      } else if (supportsDeflate) {
        const compressed = zlib.deflateSync(buffer, { level: 6 });
        res.setHeader('Content-Encoding', 'deflate');
        res.setHeader('Content-Length', compressed.length);
        return originalSend(compressed);
      }
    } catch {
      // If compression fails unexpectedly, fallback safely to uncompressed buffer
      return originalSend(buffer);
    }

    return originalSend(buffer);
  };

  next();
};

export default compressionMiddleware;
