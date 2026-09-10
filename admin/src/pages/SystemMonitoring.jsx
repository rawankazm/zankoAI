import React, { useState, useEffect } from 'react';
import { Activity, Server, Database, Layers, Bot, CreditCard, RefreshCw, CheckCircle2, XCircle, AlertCircle } from 'lucide-react';
import { AdminApi } from '../services/api';
import Badge from '../components/Badge';
import LoadingSpinner from '../components/LoadingSpinner';

export default function SystemMonitoring() {
  const [health, setHealth] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchHealth = async () => {
    setLoading(true);
    try {
      const data = await AdminApi.getSystemHealth();
      setHealth(data);
    } catch (err) {
      console.error('Failed to load system health:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHealth();
    const interval = setInterval(fetchHealth, 15000); // Poll every 15s
    return () => clearInterval(interval);
  }, []);

  const indicators = [
    {
      title: 'سێرڤەری سەرەکی (API Server)',
      status: health?.services?.api?.status || 'healthy',
      icon: Server,
      details: `ماوەی کارکردن: ${health?.system?.uptimeFormatted || '0s'}`,
    },
    {
      title: 'داتابەیس (PostgreSQL DB)',
      status: health?.services?.database?.status || 'healthy',
      icon: Database,
      details: 'پەیوەندی RLS چالاکە لەگەڵ Supabase',
    },
    {
      title: 'کاش و پردی پەیوەندی (Redis)',
      status: health?.services?.redis?.status || 'healthy',
      icon: Layers,
      details: 'Redis Standalone / Memory Guard',
    },
    {
      title: 'نۆرەی کارەکان (BullMQ Worker)',
      status: health?.services?.worker?.status || 'healthy',
      icon: Activity,
      details: `${health?.services?.worker?.queueStats?.waiting || 0} کار چاوەڕوانە، ${health?.services?.worker?.queueStats?.failed || 0} شکستی هێناوە`,
    },
    {
      title: 'خزمەتگوزاری هۆشی دەستکرد (AI)',
      status: health?.services?.ai?.status || 'healthy',
      icon: Bot,
      details: 'Google Gemini 2.5 Flash + GPT-4o-mini',
    },
    {
      title: 'دەروازەکانی پارەدان (Payments)',
      status: health?.services?.payment?.status || 'healthy',
      icon: CreditCard,
      details: 'FIB, FastPay, ZainCash, Qi Card',
    },
  ];

  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">تەندروستی و چاودێری سیستەم (System Health)</h1>
          <p className="text-xs text-slate-400 mt-1">
            چاودێری ڕاستەوخۆی ژێرخانی DigitalOcean، داتابەیس، کاش، نۆرەکانی BullMQ و دەروازەکان
          </p>
        </div>

        <button
          onClick={fetchHealth}
          disabled={loading}
          className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium flex items-center gap-2 border border-slate-700 transition-all disabled:opacity-50"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          <span>نوێکردنەوەی دۆخ</span>
        </button>
      </div>

      {/* ─── Health Indicators Grid ─── */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {indicators.map((ind, idx) => {
          const Icon = ind.icon;
          const isHealthy = ind.status === 'healthy';

          return (
            <div key={idx} className="glass-card rounded-2xl p-5 border border-slate-800 flex items-start gap-4">
              <div className={`p-3 rounded-xl shrink-0 ${isHealthy ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'}`}>
                <Icon className="w-6 h-6" />
              </div>

              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2 mb-1">
                  <h4 className="text-sm font-bold text-white truncate">{ind.title}</h4>
                  <Badge variant={isHealthy ? 'success' : 'danger'}>
                    {isHealthy ? 'چالاکە' : 'تێکچووە'}
                  </Badge>
                </div>
                <p className="text-xs text-slate-400">{ind.details}</p>
              </div>
            </div>
          );
        })}
      </div>

      {/* ─── Telemetry Summary Card ─── */}
      <div className="glass-card rounded-2xl p-6 border border-slate-800 space-y-4">
        <h3 className="text-base font-bold text-white">زانیاری ژینگەی ڕاژەکار (Server Environment)</h3>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs">
          <div className="p-4 rounded-xl bg-slate-900/60 border border-slate-800 space-y-1">
            <span className="text-slate-500">دۆخی ژینگە (Node Environment):</span>
            <p className="font-mono text-sm font-bold text-white">{health?.system?.nodeEnv || 'production'}</p>
          </div>

          <div className="p-4 rounded-xl bg-slate-900/60 border border-slate-800 space-y-1">
            <span className="text-slate-500">بەکارهێنانی ڕام (Heap Memory):</span>
            <p className="font-mono text-sm font-bold text-indigo-400">
              {health?.system?.memory?.heapUsedMb || 0} MB / {health?.system?.memory?.heapTotalMb || 0} MB
            </p>
          </div>

          <div className="p-4 rounded-xl bg-slate-900/60 border border-slate-800 space-y-1">
            <span className="text-slate-500">کۆی ماوەی کارکردنی بەردەوام:</span>
            <p className="font-mono text-sm font-bold text-emerald-400">
              {health?.system?.uptimeFormatted || '0s'}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
