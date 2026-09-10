import React, { useState, useEffect } from 'react';
import { Gauge, Clock, RefreshCw, BarChart2, Shield } from 'lucide-react';
import { AdminApi } from '../services/api';
import StatCard from '../components/StatCard';
import Badge from '../components/Badge';
import LoadingSpinner from '../components/LoadingSpinner';

export default function Usage() {
  const [usage, setUsage] = useState(null);
  const [period, setPeriod] = useState('month');
  const [loading, setLoading] = useState(true);

  const fetchUsage = async () => {
    setLoading(true);
    try {
      const data = await AdminApi.getSystemUsage(period);
      setUsage(data);
    } catch (err) {
      console.error('Failed to load system usage:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsage();
  }, [period]);

  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی بەکارهێنان و کوۆتا (Usage Telemetry)</h1>
          <p className="text-xs text-slate-400 mt-1">
            چاودێری کوۆتای بەخۆڕایی، پریمیۆم، تێپەڕاندنی سنوور و بەرواری نوێبوونەوە
          </p>
        </div>

        <div className="flex items-center gap-3">
          <select
            value={period}
            onChange={(e) => setPeriod(e.target.value)}
            className="px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-brand-500"
          >
            <option value="day">ڕۆژانە (Day)</option>
            <option value="week">هەفتانە (Week)</option>
            <option value="month">مانگانە (Month)</option>
            <option value="year">ساڵانە (Year)</option>
          </select>

          <button
            onClick={fetchUsage}
            disabled={loading}
            className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* ─── Metric Cards ─── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="بەکارهێنەرانی چالاکی ڕۆژانە"
          value={usage?.activeUsers?.dau?.toString() || '0'}
          subtitle="DAU لەم ماوەیەدا"
          icon={Gauge}
          color="brand"
        />
        <StatCard
          title="چالاکی گشتی (MAU)"
          value={usage?.activeUsers?.mau?.toString() || '0'}
          subtitle="بەکارهێنەری مانگانە"
          icon={BarChart2}
          color="emerald"
        />
        <StatCard
          title="کۆی داواکارییەکانی AI"
          value={usage?.aiUsage?.totalRequests?.toLocaleString() || '0'}
          subtitle={`${((usage?.aiUsage?.totalTokens || 0) / 1000).toFixed(0)}k تۆکن`}
          icon={Clock}
          color="purple"
        />
        <StatCard
          title="خەرجی خەمڵێنراو (USD)"
          value={`$${usage?.aiUsage?.estimatedCostUsd || '0.00'}`}
          subtitle="لە تەواوی دابینکەراندا"
          icon={Shield}
          color="amber"
        />
      </div>

      {/* ─── Quota Meters ─── */}
      <div className="glass-card rounded-2xl p-6 border border-slate-800 space-y-6">
        <h3 className="text-base font-bold text-white">ڕێژەی بەکارهێنانی کوۆتاکانی سیستەم</h3>

        <div className="space-y-4">
          <div>
            <div className="flex justify-between text-xs mb-1.5">
              <span className="font-semibold text-slate-300">هۆشی دەستکرد (چات و شیكردنەوە)</span>
              <span className="text-slate-400">72% بەکارهاتووە</span>
            </div>
            <div className="w-full h-2.5 rounded-full bg-slate-800 overflow-hidden">
              <div className="h-full rounded-full bg-brand-500" style={{ width: '72%' }} />
            </div>
          </div>

          <div>
            <div className="flex justify-between text-xs mb-1.5">
              <span className="font-semibold text-slate-300">خوێندنەوەی دەق و وێنە (OCR & Vision)</span>
              <span className="text-slate-400">45% بەکارهاتووە</span>
            </div>
            <div className="w-full h-2.5 rounded-full bg-slate-800 overflow-hidden">
              <div className="h-full rounded-full bg-emerald-500" style={{ width: '45%' }} />
            </div>
          </div>

          <div>
            <div className="flex justify-between text-xs mb-1.5">
              <span className="font-semibold text-slate-300">دەنگی وانەکان و کورتەکردنەوە (Audio Transcription)</span>
              <span className="text-slate-400">38% بەکارهاتووە</span>
            </div>
            <div className="w-full h-2.5 rounded-full bg-slate-800 overflow-hidden">
              <div className="h-full rounded-full bg-amber-500" style={{ width: '38%' }} />
            </div>
          </div>

          <div>
            <div className="flex justify-between text-xs mb-1.5">
              <span className="font-semibold text-slate-300">بیرگەی پەڕگەکان (Storage Bandwidth)</span>
              <span className="text-slate-400">22% بەکارهاتووە</span>
            </div>
            <div className="w-full h-2.5 rounded-full bg-slate-800 overflow-hidden">
              <div className="h-full rounded-full bg-cyan-500" style={{ width: '22%' }} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
