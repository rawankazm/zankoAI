import { redis } from '../config/redis.js';

export class UsageService {
  static async getUserUsageToday(userId: string): Promise<{ used: number; date: string }> {
    const today = new Date().toISOString().split('T')[0];
    const key = `usage:daily:${userId}:${today}`;
    try {
      const val = await redis.get(key);
      return { used: val ? parseInt(val, 10) : 0, date: today };
    } catch {
      return { used: 0, date: today };
    }
  }

  static async resetUserUsage(userId: string): Promise<boolean> {
    const today = new Date().toISOString().split('T')[0];
    const key = `usage:daily:${userId}:${today}`;
    try {
      await redis.del(key);
      return true;
    } catch {
      return false;
    }
  }
}
