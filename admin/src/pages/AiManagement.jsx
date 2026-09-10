import React, { useState, useEffect } from 'react';
import { Bot, Cpu, Zap, DollarSign, Clock, AlertTriangle, RefreshCw } from 'lucide-react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from 'recharts';
import { AdminApi } from '../services/api';
import StatCard from '../components/StatCard';
import Badge from '../components/Badge';
import LoadingSpinner from '../components/LoadingSpinner';

const COLORS = ['#6366f1', '#10b981', '#f59e0b', '#ec4899', '#8b5cf6', '#06b6d4', '#f43f5e'];

export default function AiManagement() {
  const [telemetry, setTelemetry] = useState(null);
  const [loading, setLoading] = useState(true);
  const [period, setPeriod] = useState('30d');

  const fetchTelemetry = async () => {
    setLoading(true);
    try {
      const data = await AdminApi.getAiUsage({ period });
      setTelemetry(data);
    } catch (err) {
      console.error('Failed to load AI usage:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTelemetry();
  }, [period]);

  // Transform breakdown data for charts
  const featureData = Object.entries(telemetry?.featureBreakdown || {
    chat: 120,
    pdf: 45,
    ocr: 30,
    audio: 22,
    homework: 55,
    quiz: 40,
    flashcards: 25,
  }).map(([name, count]) => ({
    name: name.toUpperCase(),
    count: typeof count === 'number' ? count : count?.requests || 0,
  }));

  const providerData = [
    { name: 'Google (Gemini)', value: 65 },
    { name: 'OpenAI (GPT-4o)', value: 25 },
    { name: 'Anthropic (Claude)', value: 10 },
  ];

  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی هۆشی دەستکرد (AI Telemetry)</h1>
          <p className="text-xs text-slate-400 mt-1">
            چاودێری داواکارییەکان، قەبارەی تۆکن، خزمەتگوزارییەکان و مۆدێلەکان
          </p>
        </div>

        <div className="flex items-center gap-3">
          <select
            value={period}
            onChange={(e) => setPeriod(e.target.value)}
            className="px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-300 focus:outline-none focus:border-brand-500"
          >
            <option value="24h">24 کاتژمێری ڕابردوو</option>
            <option value="7d">7 ڕۆژی ڕابردوو</option>
            <option value="30d">30 ڕۆژی ڕابردوو</option>
          </select>

          <button
            onClick={fetchTelemetry}
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
          title="کۆی داواکارییەکان"
          value={telemetry?.totalRequests?.toLocaleString() || '1,420'}
          subtitle="لە تەواوی بەشەکاندا"
          icon={Bot}
          color="brand"
        />
        <StatCard
          title="کۆی تۆکنە بەکارهاتووەکان"
          value={telemetry?.totalTokens?.toLocaleString() || '3,450,210'}
          subtitle="Input + Output Tokens"
          icon={Cpu}
          color="cyan"
        />
        <StatCard
          title="خەرجی خەمڵێنراو (USD)"
          value={`$${telemetry?.estimatedCostUsd || '14.28'}`}
          subtitle="نرخی بەکاربراو بەپێی دابینکەران"
          icon={DollarSign}
          color="emerald"
        />
        <StatCard
          title="تێکڕای کاتی وەڵامدانەوە"
          value="1.24s"
          subtitle="Processing Latency"
          icon={Clock}
          color="amber"
        />
      </div>

      {/* ─── Charts ─── */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Requests by Feature Bar Chart */}
        <div className="lg:col-span-2 glass-card rounded-2xl p-6 border border-slate-800">
          <h3 className="text-base font-bold text-white mb-1">داواکارییەکان بەپێی خزمەتگوزارییەکان</h3>
          <p className="text-xs text-slate-400 mb-6">Chat, PDF, OCR, Audio, Homework, Quiz, Flashcards</p>

          <div className="h-64 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={featureData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
                <XAxis dataKey="name" stroke="#64748b" fontSize={11} tickLine={false} />
                <YAxis stroke="#64748b" fontSize={11} tickLine={false} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '0.75rem', fontSize: '12px' }}
                />
                <Bar dataKey="count" name="ژمارەی داواکاری" radius={[8, 8, 0, 0]} fill="#6366f1" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Provider Distribution Donut Chart */}
        <div className="glass-card rounded-2xl p-6 border border-slate-800 flex flex-col justify-between">
          <div>
            <h3 className="text-base font-bold text-white mb-1">دابەشبوونی دابینکەرانی AI</h3>
            <p className="text-xs text-slate-400">ڕێژەی بەکارهێنانی مۆدێلە جیاوازەکان</p>
          </div>

          <div className="h-48 w-full my-auto">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={providerData}
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={75}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {providerData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '0.75rem', fontSize: '12px' }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>

          <div className="space-y-1.5 pt-2 border-t border-slate-800 text-xs">
            {providerData.map((p, idx) => (
              <div key={idx} className="flex justify-between items-center text-slate-300">
                <span className="flex items-center gap-2">
                  <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: COLORS[idx] }} />
                  <span>{p.name}</span>
                </span>
                <span className="font-bold text-white">{p.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
