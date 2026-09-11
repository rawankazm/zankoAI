import { TTSProvider, TTSInput, TTSResult, TTSVoice } from '../tts.interface.js';
import { TTSTextCleaner } from '../tts_text_cleaner.js';
import { env } from '../../../../config/env.js';
import { logger } from '../../../../config/logger.js';

export class ElevenLabsTTSProvider implements TTSProvider {
  readonly name = 'elevenlabs';

  private get apiKey(): string | undefined {
    return env.ELEVENLABS_API_KEY;
  }

  private get defaultVoiceId(): string {
    return env.ELEVENLABS_VOICE_ID || 'CwhRBWXzGAHq8TQ4Fs17'; // Multilingual natural voice (Roger/Academic)
  }

  isLanguageSupported(_language: string): boolean {
    return true; // eleven_multilingual_v2 natively supports 29+ languages including Arabic, English, and phonetic Kurdish
  }

  getAvailableVoices(language: string): TTSVoice[] {
    const lang = language.toLowerCase();

    if (lang === 'en') {
      return [
        {
          id: '21m00Tcm4TlvDq8ikWAM',
          name: 'Rachel (Clear Academic English)',
          language: 'en',
          gender: 'FEMALE',
          provider: 'elevenlabs',
          isDefault: true,
        },
        {
          id: 'pNInz6obpgDQGcFmaJgB',
          name: 'Adam (Expressive Male)',
          language: 'en',
          gender: 'MALE',
          provider: 'elevenlabs',
        },
      ];
    }

    if (lang === 'ar') {
      return [
        {
          id: this.defaultVoiceId,
          name: 'Roger (Multilingual Academic Tutor)',
          language: 'ar',
          gender: 'MALE',
          provider: 'elevenlabs',
          isDefault: true,
        },
      ];
    }

    // Kurdish (Sorani)
    return [
      {
        id: this.defaultVoiceId,
        name: 'Roger (Multilingual Academic Tutor)',
        language: 'ku',
        gender: 'MALE',
        provider: 'elevenlabs',
        isDefault: true,
      },
    ];
  }

  async synthesizeSpeech(input: TTSInput): Promise<TTSResult> {
    const key = this.apiKey;
    if (!key) {
      throw new Error('ElevenLabs API Key is not configured on the server.');
    }

    const { text, language, voice, speed = 1.0 } = input;
    const cleanedText = TTSTextCleaner.cleanForSpeech(text, language);

    const voiceId = voice || this.defaultVoiceId;
    const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

    const body = {
      text: cleanedText,
      model_id: 'eleven_multilingual_v2',
      voice_settings: {
        stability: 0.55,
        similarity_boost: 0.8,
        style: 0.0,
        use_speaker_boost: true,
      },
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'xi-api-key': key,
        Accept: 'audio/mpeg',
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const errorText = await res.text();
      logger.error(`[ElevenLabsTTSProvider] API Error (${res.status}): ${errorText}`);
      throw new Error(`ElevenLabs TTS failed with status ${res.status}: ${errorText.slice(0, 100)}`);
    }

    const arrayBuffer = await res.arrayBuffer();
    const audioBuffer = Buffer.from(arrayBuffer);
    const audioBase64 = audioBuffer.toString('base64');

    // Approximate duration
    const estimatedDurationMs = Math.round(((cleanedText.length / 14) * 1000) / speed);
    const estimatedCost = (cleanedText.length / 1000) * 0.03; // ~$0.03 per 1k chars

    return {
      audioBuffer,
      audioBase64,
      durationMs: estimatedDurationMs,
      format: 'mp3',
      provider: 'elevenlabs',
      characterCount: cleanedText.length,
      estimatedCost,
    };
  }
}
