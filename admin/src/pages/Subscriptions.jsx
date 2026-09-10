import React, { useState, useEffect, useCallback } from 'react';
import { CreditCard, Search, Crown, CheckCircle2, XCircle, Clock, AlertCircle } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import Toast from '../components/Toast';

export default function Subscriptions() {
  const [subscriptions, setSubscriptions] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, limit: 20, total: 0, totalPages: 1 });
  const [loading, setLoading] = useState(true);

  const [statusFilter, setStatusFilter] = useState('');
  const [planFilter, setPlanFilter] = useState('');
  const [providerFilter, setProviderFilter] = useState('');
  const [toast, setToast] = useState(null);

  const fetchSubscriptions = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const res = await AdminApi.listSubscriptions({
        page,
        limit: pagination.limit,
        status: statusFilter || undefined,
        plan: planFilter || undefined,
        provider: providerFilter || undefined,
      });
      setSubscriptions(res.subscriptions || []);
      setPagination(res.pagination || { page: 1, limit: 20, total: 0, totalPages: 1 });
    } catch (err) {
      console.error('Failed to load subscriptions:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی بەشداریکردنەکان.' });
    } finally {
      setLoading(false);
    }
  }, [pagination.limit, statusFilter, planFilter, providerFilter]);

  useEffect(() => {
    fetchSubscriptions(1);
  }, [statusFilter, planFilter, providerFilter]);

  const columns = [
    {
      key: 'user',
      label: 'بەکارهێنەر',
      render: (_, s) => (
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl bg-slate-800 flex items-center justify-center font-bold text-xs text-slate-300">
            {s.profiles?.full_name?.[0] || s.profiles?.email?.[0]?.toUpperCase() || 'U'}
          </div>
          <div>
            <p className="font-semibold text-white">{s.profiles?.full_name || 'بێ ناو'}</p>
            <p className="text-xs text-slate-400 font-mono">{s.profiles?.email}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'plan',
      label: 'پلان',
      render: (plan) => (
        <Badge variant="success" className="gap-1">
          <Crown className="w-3 h-3 text-amber-400" />
          <span>{plan}</span>
        </Badge>
      ),
    },
    {
      key: 'provider',
      label: 'دەروازە',
      render: (provider) => (
        <span className="text-xs uppercase font-mono text-slate-300">
          {provider || 'FIB'}
        </span>
      ),
    },
    {
      key: 'status',
      label: 'دۆخ',
      render: (status) => (
        <Badge variant={status === 'active' ? 'success' : status === 'canceled' ? 'warning' : 'danger'}>
          {status === 'active' ? 'چالاکە' : status === 'canceled' ? 'هەڵوەشاوەتەوە' : 'بەسەرچووە'}
        </Badge>
      ),
    },
    {
      key: 'current_period_start',
      label: 'دەستپێک',
      render: (date) => (
        <span className="text-xs text-slate-400">
          {date ? new Date(date).toLocaleDateString('ku-IQ') : '—'}
        </span>
      ),
    },
    {
      key: 'current_period_end',
      label: 'کۆتایی / نوێبوونەوە',
      render: (date) => (
        <span className="text-xs text-slate-300 font-semibold">
          {date ? new Date(date).toLocaleDateString('ku-IQ') : '—'}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">بەشداریکردنەکان (Subscriptions)</h1>
          <p className="text-xs text-slate-400 mt-1">
            چاودێری پلانەکانی پریمیۆم، بەرواری بەسەرچوون و دەروازەکانی پارەدان
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو دۆخەکان</option>
          <option value="active">چالاک (Active)</option>
          <option value="expired">بەسەرچوو (Expired)</option>
          <option value="canceled">هەڵوەشاوەتەوە (Canceled)</option>
        </select>

        <select
          value={planFilter}
          onChange={(e) => setPlanFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو پلانەکان</option>
          <option value="PREMIUM_MONTHLY">مانگانە (Monthly)</option>
          <option value="PREMIUM_YEARLY">ساڵانە (Yearly)</option>
        </select>

        <select
          value={providerFilter}
          onChange={(e) => setProviderFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو دەروازەکان</option>
          <option value="fib">FIB Bank</option>
          <option value="fastpay">FastPay</option>
          <option value="zaincash">ZainCash</option>
          <option value="qi_card">Qi Card</option>
          <option value="admin_grant">دیاری ئەدمین</option>
        </select>
      </div>

      <DataTable
        columns={columns}
        data={subscriptions}
        loading={loading}
        pagination={pagination}
        onPageChange={(p) => fetchSubscriptions(p)}
        emptyMessage="هیچ بەشداریکردنێک نەدۆزرایەوە."
      />

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
