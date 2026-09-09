// ==============================================================================
// ZankoAI High-Performance Cache Service
// Redis-backed caching with In-Memory L1 fallback and safe invalidation
// ==============================================================================

import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';

interface L1CacheEntry<T> {
  data: T;
  expiresAt: number;
}

export class CacheService {
  private static l1Cache = new Map<string, L1CacheEntry<any>>();
  private static readonly MAX_L1_ITEMS = 1000;

  /**
   * Retrieves an item from L1 memory or Redis.
   */
  static async get<T>(key: string): Promise<T | null> {
    const now = Date.now();

    // 1. Check L1 Memory Cache first (0ms latency)
    const l1Entry = this.l1Cache.get(key);
    if (l1Entry && l1Entry.expiresAt > now) {
      return l1Entry.data as T;
    } else if (l1Entry) {
      this.l1Cache.delete(key);
    }

    // 2. Check Redis
    try {
      const raw = await redis.get(key);
      if (!raw) return null;

      const parsed = JSON.parse(raw);

      // Populate L1 cache for fast subsequent hits
      this.setL1(key, parsed, 60); // 1 minute in L1

      return parsed as T;
    } catch (err: any) {
      logger.warn('[CacheService] Redis read failed for key ' + key + ': ' + err.message);
      return null;
    }
  }

  /**
   * Stores an item in Redis and L1 memory with a specified TTL in seconds.
   */
  static async set<T>(key: string, value: T, ttlSeconds = 600): Promise<void> {
    // Populate L1
    this.setL1(key, value, Math.min(ttlSeconds, 60));

    // Populate Redis
    try {
      const serialized = JSON.stringify(value);
      await redis.set(key, serialized, 'EX', ttlSeconds);
    } catch (err: any) {
      logger.warn('[CacheService] Redis write failed for key ' + key + ': ' + err.message);
    }
  }

  /**
   * Read-through cache pattern: returns cached data or fetches, stores, and returns.
   */
  static async getOrSet<T>(
    key: string,
    ttlSeconds: number,
    fetcher: () => Promise<T>
  ): Promise<T> {
    const cached = await this.get<T>(key);
    if (cached !== null && cached !== undefined) {
      return cached;
    }

    const fresh = await fetcher();
    if (fresh !== null && fresh !== undefined) {
      await this.set(key, fresh, ttlSeconds);
    }
    return fresh;
  }

  /**
   * Deletes a specific cache key.
   */
  static async delete(key: string): Promise<void> {
    this.l1Cache.delete(key);
    try {
      await redis.del(key);
    } catch (err: any) {
      logger.warn('[CacheService] Redis del failed for key ' + key + ': ' + err.message);
    }
  }

  /**
   * Invalidates all cache keys matching a glob pattern (e.g. 'cache:academic:*').
   */
  static async deletePattern(pattern: string): Promise<void> {
    // Clear L1 entries matching prefix
    const prefix = pattern.replace(/\*$/, '');
    for (const key of this.l1Cache.keys()) {
      if (key.startsWith(prefix)) {
        this.l1Cache.delete(key);
      }
    }

    try {
      const keys = await redis.keys(pattern);
      if (keys.length > 0) {
        await redis.del(...keys);
      }
    } catch (err: any) {
      logger.warn('[CacheService] Redis deletePattern failed for ' + pattern + ': ' + err.message);
    }
  }

  private static setL1<T>(key: string, data: T, ttlSeconds: number): void {
    if (this.l1Cache.size >= this.MAX_L1_ITEMS) {
      // Evict oldest 100 items if threshold reached
      const keysToDelete = Array.from(this.l1Cache.keys()).slice(0, 100);
      for (const k of keysToDelete) {
        this.l1Cache.delete(k);
      }
    }

    this.l1Cache.set(key, {
      data,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }
}
