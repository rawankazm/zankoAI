/**
 * TTS Provider Abstraction & Types for ZankoAI Multilingual AI Teacher Voice Engine
 */

export interface TTSInput {
  text: string;
  language: 'ku' | 'ar' | 'en' | string;
  voice?: string;
  speed?: number; // 0.5 to 2.0 (default 1.0)
}

export interface TTSResult {
  audioBuffer?: Buffer;
  audioBase64?: string;
  audioUrl?: string;
  durationMs?: number;
  format: 'mp3' | 'wav';
  provider: string;
  characterCount: number;
  estimatedCost: number; // in USD
}

export interface TTSVoice {
  id: string;
  name: string;
  language: string;
  gender?: 'MALE' | 'FEMALE' | 'NEUTRAL';
  provider: string;
  isDefault?: boolean;
}

export interface TTSProvider {
  readonly name: string;
  isLanguageSupported(language: string): boolean;
  synthesizeSpeech(input: TTSInput): Promise<TTSResult>;
  getAvailableVoices(language: string): Promise<TTSVoice[]> | TTSVoice[];
}
