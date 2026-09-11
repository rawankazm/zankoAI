import crypto from 'node:crypto';
import { TTSInput, TTSResult, TTSVoice, TTSProvider } from './tts.interface.js';
import { TTSTextCleaner } from './tts_text_cleaner.js';
import { GoogleTTSProvider } from './providers/google_tts.provider.js';
import { ElevenLabsTTSProvider } from './providers/elevenlabs_tts.provider.js';
import { FallbackTTSProvider } from './providers/fallback_tts.provider.js';
import { env } from '../../../config/env.js';
import { logger } from '../../../config/logger.js';
import { redis } from '../../../config/redis.js';
import { supabaseAdmin } from '../../../config/supabase.js';
import { UsageService } from '../../../services/usage.service.js';
import { BadRequestError, QuotaExceededError, AppError } from '../../../utils/apiError.js';

export interface TTSOrchestratorResponse {
  audioBase64: string;
  audioUrl?: string;
  durationMs: number;
  format: string;
  provider: string;
  characterCount: number;
  cached: boolean;
}

export class TTSOrchestratorService {
  private static instance: TTSOrchestratorService;
  private providers: Map<string, TTSProvider> = new Map();

  private constructor() {
    const google = new GoogleTTSProvider();
    const elevenlabs = new ElevenLabsTTSProvider();
    const fallback = new FallbackTTSProvider();

    this.providers.set(google.name, google);
    this.providers.set(elevenlabs.name, elevenlabs);
    this.providers.set(fallback.name, fallback);
  }

  public static getInstance(): TTSOrchestratorService {
    if (!TTSOrchestratorService.instance) {
      TTSOrchestratorService.instance = new TTSOrchestratorService();
    }
    return TTSOrchestratorService.instance;
  }

  /**
   * Generates a stable cryptographic hash for caching audio synthesis
   */
  public generateHash(text: string, language: string, voice?: string, speed = 1.0): string {
    const normalizedText = text.trim();
    const normalizedLang = (language || 'ku').toLowerCase();
    const normalizedVoice = (voice || 'default').toLowerCase();
    const normalizedSpeed = Number(speed).toFixed(2);

    return crypto
      .createHash('sha256')
      .update(`${normalizedText}|${normalizedLang}|${normalizedVoice}|${normalizedSpeed}|v2`)
      .digest('hex');
  }

  /**
   * Synthesizes speech for a single text chunk with Redis caching, quota enforcement, and multi-provider fallback.
   */
  public async synthesizeSpeech(
    userId: string,
    input: TTSInput,
    aiRequestId?: string
  ): Promise<TTSOrchestratorResponse> {
    if (!input.text || input.text.trim().length === 0) {
      throw new BadRequestError('Text is required for speech synthesis.');
    }

    const language = (input.language || 'ku').toLowerCase();
    const speed = Math.max(0.5, Math.min(2.0, input.speed || 1.0));
    const cleanedText = TTSTextCleaner.cleanForSpeech(input.text, language);

    if (cleanedText.length === 0) {
      throw new BadRequestError('Text contains no pronounceable content after cleaning.');
    }

    if (cleanedText.length > 5000) {
      throw new BadRequestError('Text exceeds maximum safe chunk limit (5000 characters). Please use chunking.');
    }

    const textHash = this.generateHash(cleanedText, language, input.voice, speed);
    const cacheKey = `tts:cache:${textHash}`;

    // 1. Check Redis Cache
    try {
      const cached = await redis.get(cacheKey);
      if (cached) {
        const parsed = JSON.parse(cached) as TTSOrchestratorResponse;
        logger.info(`[TTSOrchestrator] Cache HIT for hash ${textHash.slice(0, 10)} (lang: ${language})`);
        return {
          ...parsed,
          cached: true,
        };
      }
    } catch (redisErr) {
      logger.warn('[TTSOrchestrator] Redis cache read failed, continuing to synthesis:', redisErr);
    }

    // 2. Server-Authoritative Quota Check & Reservation
    const quotaResult = await UsageService.consumeQuota(userId, 'audio', 1, textHash);
    if (!quotaResult.allowed) {
      throw new QuotaExceededError(
        `Monthly audio synthesis quota exceeded (${quotaResult.current_usage}/${quotaResult.limit}). Upgrade to Premium for unlimited voice answers.`,
        quotaResult
      );
    }

    // 3. Provider Resolution & Fallback Cascade
    const preferredProvider = input.voice?.includes('Neural')
      ? 'google'
      : (env.DEFAULT_TTS_PROVIDER || 'google');

    const providerOrder = [
      preferredProvider,
      preferredProvider === 'google' ? 'elevenlabs' : 'google',
      'fallback',
    ];

    let result: TTSResult | null = null;
    let lastError: Error | null = null;
    let successfulProvider = preferredProvider;

    const startTime = Date.now();

    for (const providerName of providerOrder) {
      const provider = this.providers.get(providerName);
      if (!provider) continue;

      try {
        logger.info(`[TTSOrchestrator] Attempting synthesis with provider '${providerName}' (chars: ${cleanedText.length})`);
        result = await provider.synthesizeSpeech({
          text: cleanedText,
          language,
          voice: input.voice,
          speed,
        });
        successfulProvider = providerName;
        break; // Successfully synthesized
      } catch (err: any) {
        lastError = err;
        logger.warn(`[TTSOrchestrator] Provider '${providerName}' failed: ${err.message}. Trying next fallback...`);
      }
    }

    if (!result || !result.audioBase64) {
      // Record failure in tts_jobs for monitoring
      try {
        await supabaseAdmin.from('tts_jobs').insert({
          user_id: userId,
          ai_request_id: aiRequestId || null,
          text_hash: textHash,
          language,
          voice: input.voice || 'default',
          speed,
          status: 'failed',
          provider: successfulProvider,
          character_count: cleanedText.length,
          error_code: lastError?.message?.slice(0, 100) || 'ALL_PROVIDERS_FAILED',
          failed_at: new Date().toISOString(),
        });
      } catch (logErr) {
        logger.error('[TTSOrchestrator] Failed to log failed tts_job:', logErr);
      }

      throw new AppError(
        `Audio synthesis temporarily unavailable: ${lastError?.message || 'Provider failure'}. Written answer is intact.`,
        503,
        'TTS_UNAVAILABLE'
      );
    }

    const durationMs = result.durationMs || Math.round((cleanedText.length / 14) * 1000);
    const orchestratorResponse: TTSOrchestratorResponse = {
      audioBase64: result.audioBase64,
      audioUrl: result.audioUrl,
      durationMs,
      format: result.format || 'mp3',
      provider: successfulProvider,
      characterCount: result.characterCount || cleanedText.length,
      cached: false,
    };

    // 4. Save to Redis Cache (7 days TTL)
    try {
      await redis.setex(cacheKey, 604800, JSON.stringify(orchestratorResponse));
    } catch (redisErr) {
      logger.warn('[TTSOrchestrator] Redis cache write failed:', redisErr);
    }

    // 5. Audit Record in tts_jobs table
    try {
      await supabaseAdmin.from('tts_jobs').insert({
        user_id: userId,
        ai_request_id: aiRequestId || null,
        text_hash: textHash,
        language,
        voice: input.voice || 'default',
        speed,
        status: 'completed',
        provider: successfulProvider,
        audio_url: result.audioUrl || null,
        format: result.format || 'mp3',
        duration_ms: durationMs,
        character_count: cleanedText.length,
        estimated_cost: result.estimatedCost || 0,
        started_at: new Date(startTime).toISOString(),
        completed_at: new Date().toISOString(),
      });
    } catch (dbErr) {
      logger.error('[TTSOrchestrator] Failed to insert completed tts_job record:', dbErr);
    }

    return orchestratorResponse;
  }

  /**
   * Synthesizes multiple text chunks in controlled sequence for long responses.
   */
  public async synthesizeBatch(
    userId: string,
    texts: string[],
    language: string,
    voice?: string,
    speed = 1.0,
    aiRequestId?: string
  ): Promise<Array<TTSOrchestratorResponse & { chunkIndex: number; totalChunks: number }>> {
    if (!texts || texts.length === 0) {
      throw new BadRequestError('Batch synthesis requires at least one text chunk.');
    }

    const totalChunks = texts.length;
    const results: Array<TTSOrchestratorResponse & { chunkIndex: number; totalChunks: number }> = [];

    // Synthesize chunks in order with short pipeline
    for (let i = 0; i < totalChunks; i++) {
      const chunkText = texts[i];
      const res = await this.synthesizeSpeech(
        userId,
        { text: chunkText, language, voice, speed },
        aiRequestId
      );
      results.push({
        ...res,
        chunkIndex: i,
        totalChunks,
      });
    }

    return results;
  }

  /**
   * Returns available voices across supported providers
   */
  public getAvailableVoices(language: string): TTSVoice[] {
    const lang = (language || 'ku').toLowerCase();
    const voices: TTSVoice[] = [];

    for (const provider of this.providers.values()) {
      try {
        const providerVoices = provider.getAvailableVoices(lang);
        voices.push(...providerVoices);
      } catch {
        // Skip provider if voice enumeration fails
      }
    }

    return voices;
  }

  /**
   * Returns provider availability and operational health
   */
  public getVoiceStatus(): {
    googleConfigured: boolean;
    elevenLabsConfigured: boolean;
    defaultProvider: string;
    supportedLanguages: string[];
  } {
    const googleConfigured = Boolean(env.GOOGLE_TTS_API_KEY || env.GEMINI_API_KEY);
    const elevenLabsConfigured = Boolean(env.ELEVENLABS_API_KEY);

    return {
      googleConfigured,
      elevenLabsConfigured,
      defaultProvider: env.DEFAULT_TTS_PROVIDER || 'google',
      supportedLanguages: ['ku', 'ar', 'en'],
    };
  }
}
