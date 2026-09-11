import { TTSProvider, TTSInput, TTSResult, TTSVoice } from '../tts.interface.js';
import { TTSTextCleaner } from '../tts_text_cleaner.js';

export class FallbackTTSProvider implements TTSProvider {
  readonly name = 'fallback';

  isLanguageSupported(_language: string): boolean {
    return true;
  }

  getAvailableVoices(language: string): TTSVoice[] {
    return [
      {
        id: 'system-default',
        name: `System Default (${language.toUpperCase()})`,
        language,
        provider: 'fallback',
        isDefault: true,
      },
    ];
  }

  async synthesizeSpeech(input: TTSInput): Promise<TTSResult> {
    const cleanedText = TTSTextCleaner.cleanForSpeech(input.text, input.language);
    throw new Error(
      `No external TTS provider configured (GOOGLE_TTS_API_KEY or ELEVENLABS_API_KEY). Text length: ${cleanedText.length}.`
    );
  }
}
