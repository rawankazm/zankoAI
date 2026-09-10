import React, { useState, useEffect, useCallback } from 'react';
import { Receipt, Search, CheckCircle2, AlertCircle, Clock, XCircle, DollarSign } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import Toast from '../components/Toast';

export default function Payments() {
  const [payments, setPayments] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, limit: 20, total: 0, totalPages: 1 });
  const [loading, setLoading] = useState(true);

  const [statusFilter, setStatusFilter] = useState('');
  const [providerFilter, setProviderFilter] = useState('');
  const [search, setSearch] = useState('');
  const [toast, setToast] = useState(null);

  const fetchPayments = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const res = await AdminApi.listPayments({
        page,
        limit: pagination.limit,
        status: statusFilter || undefined,
        provider: providerFilter || undefined,
        q: search.trim() || undefined,
      });
      setPayments(res.payments || []);
      setPagination(res.pagination || { page: 1, limit: 20, total: 0, totalPages: 1 });
    } catch (err) {
      console.error('Failed to load payments:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی مامەڵە داراییەکان.' });
    } finally {
      setLoading(false);
    }
  }, [pagination.limit, statusFilter, providerFilter, search]);

  useEffect(() => {
    fetchPayments(1);
  }, [statusFilter, providerFilter]);

  const columns = [
    {
      key: 'order_id',
      label: 'ناسنامەی داواکاری (Order ID)',
      render: (orderId, p) => (
        <div>
          <span className="font-mono text-xs font-semibold text-slate-200">{orderId || p.id.substring(0, 8)}</span>
          {p.transaction_id && (
            <span className="block text-[10px] font-mono text-slate-500">TX: {p.transaction_id}</span>
          )}
        </div>
      ),
    },
    {
      key: 'user',
      label: 'بەکارهێنەر',
      render: (_, p) => (
        <div>
          <p className="font-semibold text-white">{p.profiles?.full_name || 'بێ ناو'}</p>
          <p className="text-xs text-slate-400 font-mono">{p.profiles?.email || '—'}</p>
        </div>
      ),
    },
    {
      key: 'provider',
      label: 'دەروازەی پارەدان',
      render: (provider) => {
        const provMap = {
          fib: 'FIB Bank',
          fastpay: 'FastPay',
          zaincash: 'ZainCash',
          qi_card: 'Qi Card',
        };
        return (
          <span className="text-xs uppercase font-mono font-semibold text-indigo-400">
            {provMap[provider] || provider}
          </span>
        );
      },
    },
    {
      key: 'amount',
      label: 'بڕی پارە',
      render: (amount, p) => (
        <span className="text-sm font-bold text-white">
          {Number(amount || 0).toLocaleString()} {p.currency || 'IQD'}
        </span>
      ),
    },
    {
      key: 'status',
      label: 'دۆخی مامەڵە',
      render: (status) => {
        const map = {
          completed: { label: 'سەرکەوتوو', variant: 'success' },
          paid: { label: 'دراوە', variant: 'success' },
          pending: { label: 'چاوەڕوان', variant: 'warning' },
          failed: { label: 'شکستخواردوو', variant: 'danger' },
          cancelled: { label: 'هەڵوەشاوە', variant: 'default' },
          refunded: { label: 'گەڕێنراوەتەوە', variant: 'purple' },
        };
        const s = map[status] || { label: status, variant: 'default' };
        return <Badge variant={s.variant}>{s.label}</Badge>;
      },
    },
    {
      key: 'created_at',
      label: 'بەروار و کات',
      render: (date) => (
        <span className="text-xs text-slate-400">
          {date ? new Date(date).toLocaleString('ku-IQ') : '—'}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی پارەدان (Payments)</h1>
          <p className="text-xs text-slate-400 mt-1">
            مێژووی مامەڵە سەرکەوتوو و شکستخواردووەکانی FIB, FastPay, ZainCash و Qi Card
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="relative">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && fetchPayments(1)}
            placeholder="گەڕان بەپێی Order ID یان ئیمەیڵ..."
            className="w-full pl-4 pr-10 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500"
          />
          <Search className="w-4 h-4 text-slate-400 absolute right-3.5 top-3" />
        </div>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو دۆخەکان</option>
          <option value="completed">سەرکەوتوو (Completed)</option>
          <option value="pending">چاوەڕوانکراو (Pending)</option>
          <option value="failed">شکستخواردوو (Failed)</option>
          <option value="refunded">گەڕێنراوە (Refunded)</option>
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
        </select>
      </div>

      <DataTable
        columns={columns}
        data={payments}
        loading={loading}
        pagination={pagination}
        onPageChange={(p) => fetchPayments(p)}
        emptyMessage="هیچ مامەڵەیەکی پارەدان نەدۆزرایەوە."
      />

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
