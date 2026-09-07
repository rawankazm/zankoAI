// ==============================================================================
// ZankoAI Audio Magic Bytes & Integrity Validator
// Checks binary signatures for MP3, WAV, M4A, AAC, OGG, WebM, and FLAC.
// ==============================================================================

export interface AudioValidationResult {
  isValid: boolean;
  detectedMime?: string;
  detectedFormat?: string;
}

export function validateAudioMagicBytes(buffer: Buffer): AudioValidationResult {
  if (!buffer || buffer.length < 8) {
    return { isValid: false };
  }

  // 1. MP3 with ID3v2 container (starts with 'ID3')
  if (buffer[0] === 0x49 && buffer[1] === 0x44 && buffer[2] === 0x33) {
    return { isValid: true, detectedMime: 'audio/mpeg', detectedFormat: 'mp3' };
  }

  // 2. MP3 sync frame (0xFF followed by 0xFB, 0xF3, or 0xF2)
  if (
    buffer[0] === 0xff &&
    (buffer[1] === 0xfb || buffer[1] === 0xf3 || buffer[1] === 0xf2)
  ) {
    return { isValid: true, detectedMime: 'audio/mpeg', detectedFormat: 'mp3' };
  }

  // 3. WAV (RIFF....WAVE)
  if (
    buffer.length >= 12 &&
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WAVE'
  ) {
    return { isValid: true, detectedMime: 'audio/wav', detectedFormat: 'wav' };
  }

  // 4. M4A / MP4 Audio ('....ftypM4A ' or '....ftypisom' or '....ftypmp42')
  if (buffer.length >= 12 && buffer.toString('ascii', 4, 8) === 'ftyp') {
    const brand = buffer.toString('ascii', 8, 12);
    if (
      brand.startsWith('M4A') ||
      brand.startsWith('mp4') ||
      brand.startsWith('isom') ||
      brand.startsWith('dash')
    ) {
      return { isValid: true, detectedMime: 'audio/mp4', detectedFormat: 'm4a' };
    }
  }

  // 5. AAC ADTS (0xFF followed by 0xF1 or 0xF9)
  if (buffer[0] === 0xff && (buffer[1] === 0xf1 || buffer[1] === 0xf9)) {
    return { isValid: true, detectedMime: 'audio/aac', detectedFormat: 'aac' };
  }

  // 6. OGG (starts with 'OggS')
  if (
    buffer[0] === 0x4f &&
    buffer[1] === 0x67 &&
    buffer[2] === 0x67 &&
    buffer[3] === 0x53
  ) {
    return { isValid: true, detectedMime: 'audio/ogg', detectedFormat: 'ogg' };
  }

  // 7. WebM (EBML header: 0x1A 0x45 0xDF 0xA3)
  if (
    buffer[0] === 0x1a &&
    buffer[1] === 0x45 &&
    buffer[2] === 0xdf &&
    buffer[3] === 0xa3
  ) {
    return { isValid: true, detectedMime: 'audio/webm', detectedFormat: 'webm' };
  }

  // 8. FLAC (starts with 'fLaC')
  if (
    buffer[0] === 0x66 &&
    buffer[1] === 0x4c &&
    buffer[2] === 0x61 &&
    buffer[3] === 0x43
  ) {
    return { isValid: true, detectedMime: 'audio/flac', detectedFormat: 'flac' };
  }

  return { isValid: false };
}
