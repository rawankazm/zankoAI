import { TTSProvider, TTSInput, TTSResult, TTSVoice } from '../tts.interface.js';
import { TTSTextCleaner } from '../tts_text_cleaner.js';
import { env } from '../../../../config/env.js';
import { logger } from '../../../../config/logger.js';

export class GoogleTTSProvider implements TTSProvider {
  readonly name = 'google';

  private get apiKey(): string | undefined {
    return env.GOOGLE_TTS_API_KEY || env.GEMINI_API_KEY;
  }

  isLanguageSupported(_language: string): boolean {
    return true; // Kurdish, Arabic, English all supported with neural voice mappings
  }

  getAvailableVoices(language: string): TTSVoice[] {
    const lang = language.toLowerCase();

    if (lang === 'en') {
      return [
        {
          id: 'en-US-Neural2-D',
          name: 'English Natural Male (Neural2)',
          language: 'en',
          gender: 'MALE',
          provider: 'google',
          isDefault: true,
        },
        {
          id: 'en-US-Neural2-F',
          name: 'English Natural Female (Neural2)',
          language: 'en',
          gender: 'FEMALE',
          provider: 'google',
        },
      ];
    }

    if (lang === 'ar') {
      return [
        {
          id: 'ar-XA-Wavenet-B',
          name: 'Arabic Male (Wavenet)',
          language: 'ar',
          gender: 'MALE',
          provider: 'google',
          isDefault: true,
        },
        {
          id: 'ar-XA-Wavenet-A',
          name: 'Arabic Female (Wavenet)',
          language: 'ar',
          gender: 'FEMALE',
          provider: 'google',
        },
      ];
    }

    // Kurdish (Sorani) default neural voice mapping
    return [
      {
        id: 'ar-XA-Wavenet-B',
        name: 'Kurdish Sorani Academic (Enhanced)',
        language: 'ku',
        gender: 'MALE',
        provider: 'google',
        isDefault: true,
      },
    ];
  }

  async synthesizeSpeech(input: TTSInput): Promise<TTSResult> {
    const key = this.apiKey;
    if (!key) {
      throw new Error('Google TTS API Key is not configured on the server.');
    }

    const { text, language, voice, speed = 1.0 } = input;
    const cleanedText = TTSTextCleaner.cleanForSpeech(text, language);

    const isEn = language.toLowerCase() === 'en';
    const isAr = language.toLowerCase() === 'ar';

    const selectedVoice =
      voice ||
      (isEn ? 'en-US-Neural2-D' : isAr ? 'ar-XA-Wavenet-B' : 'ar-XA-Wavenet-B');

    const languageCode = isEn ? 'en-US' : 'ar-XA';
    const speakingRate = Math.max(0.5, Math.min(2.0, (isEn ? 1.0 : 0.92) * speed));

    const body = {
      input: { text: cleanedText },
      voice: {
        languageCode,
        name: selectedVoice,
        ssmlGender: 'MALE',
      },
      audioConfig: {
        audioEncoding: 'MP3',
        speakingRate,
        pitch: -0.5,
      },
    };

    const url = `https://texttospeech.googleapis.com/v1/text:synthesize?key=${key}`;

    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const errorText = await res.text();
      logger.error(`[GoogleTTSProvider] API Error (${res.status}): ${errorText}`);
      throw new Error(`Google TTS API failed with status ${res.status}`);
    }

    const data = (await res.json()) as { audioContent?: string };
    if (!data.audioContent) {
      throw new Error('Google TTS API returned empty audio content.');
    }

    const audioBuffer = Buffer.from(data.audioContent, 'base64');
    // Approximate duration: ~150 words/min or 12 chars per second
    const estimatedDurationMs = Math.round((cleanedText.length / 14) * 1000 / speed);
    const estimatedCost = (cleanedText.length / 1000) * 0.016; // $0.016 per 1k characters (WaveNet)

    return {
      audioBuffer,
      audioBase64: data.audioContent,
      durationMs: estimatedDurationMs,
      format: 'mp3',
      provider: 'google',
      characterCount: cleanedText.length,
      estimatedCost,
    };
  }
}
