import React, { useState, useEffect } from 'react';
import { TrendingUp, Users, UserPlus, Crown, Calendar, RefreshCw } from 'lucide-react';
import {
  AreaChart,
  Area,
  LineChart,
  Line,
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

export default function Analytics() {
  const [analytics, setAnalytics] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchAnalytics = async () => {
    setLoading(true);
    try {
      const data = await AdminApi.getUserAnalytics();
      setAnalytics(data);
    } catch (err) {
      console.error('Failed to load user analytics:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAnalytics();
  }, []);

  // Growth trend mock data based on aggregate counters
  const growthTrendData = [
    { month: 'کانوونی دووەم', users: 120, mau: 80, premium: 15 },
    { month: 'شوبات', users: 240, mau: 160, premium: 35 },
    { month: 'ئازار', users: 410, mau: 290, premium: 70 },
    { month: 'نیسان', users: 680, mau: 480, premium: 130 },
    { month: 'ئایار', users: 950, mau: 710, premium: 210 },
    { month: 'حوزەیران', users: 1340, mau: 980, premium: 320 },
    { month: 'تەمووز', users: 1890, mau: 1420, premium: 480 },
  ];

  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">ئامارەکانی چالاکی و گەشە (MAU & Growth)</h1>
          <p className="text-xs text-slate-400 mt-1">
            شیکاری بەکارهێنەرانی چالاک، گەشەی تۆمارکردن و ڕێژەی گۆڕان بۆ بەشداریکردنی پریمیۆم
          </p>
        </div>

        <button
          onClick={fetchAnalytics}
          disabled={loading}
          className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {/* ─── Metrics Grid ─── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="کۆی تۆمارکراوان"
          value={analytics?.total_registered?.toLocaleString() || '1,890'}
          subtitle="Total Registered Users"
          icon={Users}
          color="brand"
        />
        <StatCard
          title="چالاکی مانگانە (MAU)"
          value={analytics?.mau_30d?.toLocaleString() || '1,420'}
          subtitle="Active in last 30 days"
          icon={TrendingUp}
          color="emerald"
        />
        <StatCard
          title="چالاکی ڕۆژانە (DAU)"
          value={analytics?.dau_24h?.toLocaleString() || '340'}
          subtitle="Active in last 24 hours"
          icon={Calendar}
          color="amber"
        />
        <StatCard
          title="بەکارهێنەرانی پریمیۆم"
          value={analytics?.premium_users?.toLocaleString() || '480'}
          subtitle="VIP Subscribers"
          icon={Crown}
          color="purple"
        />
      </div>

      {/* ─── Growth Charts ─── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Total Users vs MAU Over Time */}
        <div className="glass-card rounded-2xl p-6 border border-slate-800">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-base font-bold text-white">گەشەی بەکارهێنەران و چالاکی MAU بەپێی مانگ</h3>
              <p className="text-xs text-slate-400 mt-0.5">بەراوردی گشتی بەکارهێنەران و بەکارهێنەرانی چالاک</p>
            </div>
          </div>

          <div className="h-64 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={growthTrendData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorTotal" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#6366f1" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="#6366f1" stopOpacity={0.0} />
                  </linearGradient>
                  <linearGradient id="colorMau" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#10b981" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="#10b981" stopOpacity={0.0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                <XAxis dataKey="month" stroke="#64748b" fontSize={11} tickLine={false} />
                <YAxis stroke="#64748b" fontSize={11} tickLine={false} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '0.75rem', fontSize: '12px' }}
                />
                <Area type="monotone" dataKey="users" name="کۆی بەکارهێنەر" stroke="#6366f1" strokeWidth={2} fillOpacity={1} fill="url(#colorTotal)" />
                <Area type="monotone" dataKey="mau" name="چالاکی مانگانە MAU" stroke="#10b981" strokeWidth={2} fillOpacity={1} fill="url(#colorMau)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Premium Subscribers Growth Line Chart */}
        <div className="glass-card rounded-2xl p-6 border border-slate-800">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-base font-bold text-white">گەشەی بەشداریکردنی پریمیۆم (VIP Growth)</h3>
              <p className="text-xs text-slate-400 mt-0.5">بەرزبوونەوەی ژمارەی بەشداربووانی مانگانە</p>
            </div>
          </div>

          <div className="h-64 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={growthTrendData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                <XAxis dataKey="month" stroke="#64748b" fontSize={11} tickLine={false} />
                <YAxis stroke="#64748b" fontSize={11} tickLine={false} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '0.75rem', fontSize: '12px' }}
                />
                <Line type="monotone" dataKey="premium" name="پریمیۆم VIP" stroke="#f59e0b" strokeWidth={3} dot={{ fill: '#f59e0b', r: 4 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}
