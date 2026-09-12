import React, { useState, useEffect } from 'react';
import { DollarSign, AlertTriangle, CheckCircle2, TrendingDown, Users, ShieldAlert } from 'lucide-react';
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';
import { AdminApi } from '../services/api';
import StatCard from '../components/StatCard';
import Badge from '../components/Badge';
import LoadingSpinner from '../components/LoadingSpinner';
import Toast from '../components/Toast';

export default function AiCostDashboard() {
  const [costData, setCostData] = useState(null);
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState(null);

  const fetchCostReport = async () => {
    setLoading(true);
    try {
      const [cost, alertList] = await Promise.all([
        AdminApi.getAiCost({ period: '30d' }),
        AdminApi.getAiAlerts().catch(() => []),
      ]);
      setCostData(cost);
      setAlerts(alertList || []);
    } catch (err) {
      console.error('Failed to load AI cost report:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCostReport();
  }, []);

  const handleAcknowledgeAlert = async (id) => {
    try {
      await AdminApi.acknowledgeAiAlert(id);
      setToast({ type: 'success', message: 'ئاگادارییەکە ڕەتکرایەوە.' });
      fetchCostReport();
    } catch (err) {
      setToast({ type: 'error', message: 'هەڵە لە ڕەتکردنەوەی ئاگاداری.' });
    }
  };

  // Mock trend data for cost charts
  const dailyCostData = [
    { day: '01', cost: 0.8 },
    { day: '05', cost: 1.2 },
    { day: '10', cost: 1.9 },
    { day: '15', cost: 2.4 },
    { day: '20', cost: 2.1 },
    { day: '25', cost: 2.8 },
    { day: '30', cost: 3.1 },
  ];

  const topSpenders = [
    { name: 'ڕاوان ئەحمەد', email: 'rawan@zankoai.com', role: 'خوێندکار', cost: '$3.45', requests: 120 },
    { name: 'سۆران کەریم', email: 'soran@zankoai.com', role: 'خوێندکاری VIP', cost: '$2.80', requests: 95 },
    { name: 'دڵنیا عومەر', email: 'dlnya@zankoai.com', role: 'خوێندکار', cost: '$2.15', requests: 84 },
    { name: 'ئاری محەمەد', email: 'ari@zankoai.com', role: 'خوێندکار', cost: '$1.90', requests: 70 },
  ];

  return (
    <div className="space-y-8 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold text-white tracking-tight">داشبۆردی خەرجی هۆشی دەستکرد (AI Cost Guard)</h1>
        <p className="text-xs text-slate-400 mt-1">
          چاودێری خەرجی مانگانە بە دۆلاری ئەمریکی، ئاگادارییەکانی بودجە و بەرزترین بەکارهێنەران
        </p>
      </div>

      {/* ─── Metric Cards ─── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="خەرجی کۆتایی 30 ڕۆژ"
          value={`$${costData?.totalCostUsd || '14.28'}`}
          subtitle="تێکڕای خەرجی سیستەم"
          icon={DollarSign}
          color="emerald"
        />
        <StatCard
          title="خەرجی ڕۆژانەی تێکڕا"
          value={`$${((costData?.totalCostUsd || 14.28) / 30).toFixed(2)}`}
          subtitle="Average Daily Burn"
          icon={TrendingDown}
          color="brand"
        />
        <StatCard
          title="ئاگادارییەکانی تێپەڕاندنی بودجە"
          value={alerts.length.toString()}
          subtitle="Active Threshold Alerts"
          icon={AlertTriangle}
          color={alerts.length > 0 ? 'rose' : 'emerald'}
        />
        <StatCard
          title="تێکڕای نرخی هەر داواکارییەک"
          value="$0.008"
          subtitle="Cost per Request"
          icon={DollarSign}
          color="purple"
        />
      </div>

      {/* ─── Active Cost Alerts Strip ─── */}
      {alerts.length > 0 && (
        <div className="glass-card rounded-2xl p-5 border border-rose-800/60 bg-rose-950/20 space-y-3">
          <div className="flex items-center gap-2 text-rose-400 font-bold text-sm">
            <ShieldAlert className="w-5 h-5" />
            <span>ئاگاداری تێپەڕاندنی سنووری خەرجی دیاریکراو!</span>
          </div>

          <div className="space-y-2">
            {alerts.map((alt) => (
              <div
                key={alt.id}
                className="flex items-center justify-between p-3 rounded-xl bg-slate-900/80 border border-slate-800 text-xs"
              >
                <div>
                  <p className="font-semibold text-white">{alt.description || 'تێپەڕاندنی سنووری خەرجی'}</p>
                  <span className="text-slate-400 font-mono text-[11px]">بەروار: {new Date(alt.created_at).toLocaleString('ku-IQ')}</span>
                </div>
                <button
                  onClick={() => handleAcknowledgeAlert(alt.id)}
                  className="px-3 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-500 text-white font-medium text-xs transition-colors"
                >
                  پشتڕاستکردنەوە
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ─── Daily Cost Trend Chart ─── */}
      <div className="glass-card rounded-2xl p-6 border border-slate-800">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h3 className="text-base font-bold text-white">رەوتی خەرجی ڕۆژانە بە دۆلار ($)</h3>
            <p className="text-xs text-slate-400 mt-0.5">شیکاری خەرجی ڕاستەقینە لە تەواوی مۆدێلەکاندا</p>
          </div>
          <Badge variant="success">30 ڕۆژی ڕابردوو</Badge>
        </div>

        <div className="h-64 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={dailyCostData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="colorCost" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.4} />
                  <stop offset="95%" stopColor="#10b981" stopOpacity={0.0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
              <XAxis dataKey="day" stroke="#64748b" fontSize={11} tickLine={false} />
              <YAxis stroke="#64748b" fontSize={11} tickLine={false} />
              <Tooltip
                formatter={(val) => [`$${val}`, 'خەرجی']}
                contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '0.75rem', fontSize: '12px' }}
              />
              <Area type="monotone" dataKey="cost" stroke="#10b981" strokeWidth={2} fillOpacity={1} fill="url(#colorCost)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* ─── Top Spenders Table ─── */}
      <div className="glass-card rounded-2xl p-6 border border-slate-800">
        <h3 className="text-base font-bold text-white mb-4 flex items-center gap-2">
          <Users className="w-5 h-5 text-brand-400" />
          <span>بەرزترین بەکارهێنەرانی بودجەی AI</span>
        </h3>

        <div className="overflow-x-auto">
          <table className="w-full text-right text-xs">
            <thead className="text-slate-500 border-b border-slate-800 pb-2">
              <tr>
                <th className="py-2.5 px-3">بەکارهێنەر</th>
                <th className="py-2.5 px-3">ڕۆڵ</th>
                <th className="py-2.5 px-3">داواکارییەکان</th>
                <th className="py-2.5 px-3">کۆی خەرجی</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {topSpenders.map((u, idx) => (
                <tr key={idx} className="hover:bg-slate-800/30">
                  <td className="py-3 px-3">
                    <p className="font-semibold text-white">{u.name}</p>
                    <p className="text-[11px] text-slate-400 font-mono">{u.email}</p>
                  </td>
                  <td className="py-3 px-3">
                    <Badge variant={u.role.includes('VIP') ? 'primary' : 'default'}>{u.role}</Badge>
                  </td>
                  <td className="py-3 px-3 font-semibold text-slate-300">{u.requests} داواکاری</td>
                  <td className="py-3 px-3 font-bold text-emerald-400 font-mono text-sm">{u.cost}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
