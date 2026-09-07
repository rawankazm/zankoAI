// ==============================================================================
// ZankoAI Image Dimensions & Security Parser
// Zero-dependency binary reader for PNG, JPEG, and WebP dimensions.
// Defends against Decompression Bombs, Pixel Flood attacks, and truncated images.
// ==============================================================================

export interface ImageDimensions {
  width: number;
  height: number;
  format: 'image/jpeg' | 'image/png' | 'image/webp';
}

export interface DimensionValidationOptions {
  minWidth?: number;
  minHeight?: number;
  maxWidth?: number;
  maxHeight?: number;
}

const DEFAULT_MIN_WIDTH = 50;
const DEFAULT_MIN_HEIGHT = 50;
const DEFAULT_MAX_WIDTH = 10000;
const DEFAULT_MAX_HEIGHT = 10000;

/**
 * Extracts dimensions from an image buffer without decoding the entire image into memory.
 * Throws an Error if the image structure is invalid, unsupported, or corrupted.
 */
export function getImageDimensions(buffer: Buffer): ImageDimensions {
  if (!buffer || buffer.length < 16) {
    throw new Error('Image buffer is too short to determine dimensions.');
  }

  // ── 1. PNG ──────────────────────────────────────────────────────────────────
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    if (buffer.length < 24) {
      throw new Error('Corrupted PNG header.');
    }
    const width = buffer.readUInt32BE(16);
    const height = buffer.readUInt32BE(20);
    return { width, height, format: 'image/png' };
  }

  // ── 2. JPEG ─────────────────────────────────────────────────────────────────
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    let offset = 2;
    while (offset < buffer.length) {
      if (buffer[offset] !== 0xff) {
        // Skip padding
        offset++;
        continue;
      }

      const marker = buffer[offset + 1];

      // SOF0 (Baseline), SOF1 (Extended), SOF2 (Progressive)
      if (marker === 0xc0 || marker === 0xc1 || marker === 0xc2) {
        if (offset + 9 > buffer.length) {
          throw new Error('Corrupted JPEG: truncated SOF marker.');
        }
        const height = buffer.readUInt16BE(offset + 5);
        const width = buffer.readUInt16BE(offset + 7);
        return { width, height, format: 'image/jpeg' };
      }

      // Standalone markers without length: SOI (0xD8), EOI (0xD9), RST (0xD0..0xD7)
      if (marker === 0xd8 || marker === 0xd9 || (marker >= 0xd0 && marker <= 0xd7)) {
        offset += 2;
      } else {
        if (offset + 4 > buffer.length) {
          throw new Error('Corrupted JPEG: truncated marker length.');
        }
        const length = buffer.readUInt16BE(offset + 2);
        offset += 2 + length;
      }
    }

    throw new Error('Corrupted JPEG: no valid SOF segment found.');
  }

  // ── 3. WebP ─────────────────────────────────────────────────────────────────
  if (
    buffer.length >= 30 &&
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    const chunkType = buffer.toString('ascii', 12, 16);

    // Lossy VP8
    if (chunkType === 'VP8 ') {
      if (buffer.length < 30) throw new Error('Corrupted WebP VP8 chunk.');
      const width = buffer.readUInt16LE(26) & 0x3fff;
      const height = buffer.readUInt16LE(28) & 0x3fff;
      return { width, height, format: 'image/webp' };
    }

    // Lossless VP8L
    if (chunkType === 'VP8L') {
      if (buffer.length < 25) throw new Error('Corrupted WebP VP8L chunk.');
      const b1 = buffer[21];
      const b2 = buffer[22];
      const b3 = buffer[23];
      const b4 = buffer[24];
      const width = 1 + (((b2 & 0x3f) << 8) | b1);
      const height = 1 + (((b4 & 0x0f) << 10) | (b3 << 2) | ((b2 & 0xc0) >> 6));
      return { width, height, format: 'image/webp' };
    }

    // Extended VP8X
    if (chunkType === 'VP8X') {
      if (buffer.length < 30) throw new Error('Corrupted WebP VP8X chunk.');
      const width = 1 + buffer.readUIntLE(24, 3);
      const height = 1 + buffer.readUIntLE(27, 3);
      return { width, height, format: 'image/webp' };
    }

    throw new Error(`Unsupported WebP compression chunk: '${chunkType}'`);
  }

  throw new Error('Unsupported image format. Only JPEG, PNG, and WebP are allowed.');
}

/**
 * Validates image dimensions against anti-decompression bomb constraints.
 */
export function validateImageDimensions(
  dimensions: ImageDimensions,
  options: DimensionValidationOptions = {}
): void {
  const minW = options.minWidth ?? DEFAULT_MIN_WIDTH;
  const minH = options.minHeight ?? DEFAULT_MIN_HEIGHT;
  const maxW = options.maxWidth ?? DEFAULT_MAX_WIDTH;
  const maxH = options.maxHeight ?? DEFAULT_MAX_HEIGHT;

  if (dimensions.width < minW || dimensions.height < minH) {
    throw new Error(
      `Image dimensions are too small (${dimensions.width}x${dimensions.height}). Minimum allowed: ${minW}x${minH} px.`
    );
  }

  if (dimensions.width > maxW || dimensions.height > maxH) {
    throw new Error(
      `Image dimensions exceed maximum allowed limits (${dimensions.width}x${dimensions.height}). Maximum allowed: ${maxW}x${maxH} px.`
    );
  }
}
