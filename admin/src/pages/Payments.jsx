import React, { useState, useEffect, useCallback } from 'react';
import {
  Receipt,
  Search,
  CheckCircle2,
  AlertCircle,
  Clock,
  XCircle,
  Crown,
  Eye,
  DollarSign,
  ShieldCheck,
} from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function Payments() {
  const [payments, setPayments] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, limit: 20, total: 0, totalPages: 1 });
  const [loading, setLoading] = useState(true);

  const [statusFilter, setStatusFilter] = useState('');
  const [providerFilter, setProviderFilter] = useState('');
  const [search, setSearch] = useState('');
  const [toast, setToast] = useState(null);

  // Modal states
  const [selectedPayment, setSelectedPayment] = useState(null);
  const [confirmModal, setConfirmModal] = useState(null); // { type: 'approve' | 'reject', payment }
  const [planDays, setPlanDays] = useState(30);
  const [processingId, setProcessingId] = useState(null);

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

  const handleApprove = async (payment) => {
    setProcessingId(payment.id);
    try {
      await AdminApi.approveVipPayment(payment.id, payment.user_id || payment.profiles?.id, planDays);
      setPayments((prev) =>
        prev.map((p) => (p.id === payment.id ? { ...p, status: 'COMPLETED' } : p))
      );
      setToast({
        type: 'success',
        message: `✅ هەژماری (${payment.profiles?.full_name || 'خوێندکار'}) بۆ ماوەی ${planDays} ڕۆژ بوو بە VIP!`,
      });
      setConfirmModal(null);
      setSelectedPayment(null);
    } catch (e) {
      setToast({ type: 'error', message: 'کێشەیەک لە پەسەندکردنی VIP ڕوویدا.' });
    } finally {
      setProcessingId(null);
    }
  };

  const handleReject = async (payment) => {
    setProcessingId(payment.id);
    try {
      await AdminApi.rejectVipPayment(payment.id);
      setPayments((prev) =>
        prev.map((p) => (p.id === payment.id ? { ...p, status: 'FAILED' } : p))
      );
      setToast({
        type: 'warning',
        message: `داواکاری پارەدانی (${payment.profiles?.full_name || 'خوێندکار'}) ڕەتکرایەوە.`,
      });
      setConfirmModal(null);
      setSelectedPayment(null);
    } catch (e) {
      setToast({ type: 'error', message: 'کێشەیەک لە ڕەتکردنەوەدا ڕوویدا.' });
    } finally {
      setProcessingId(null);
    }
  };

  const columns = [
    {
      key: 'order_id',
      label: 'ناسنامەی داواکاری (Order ID)',
      render: (orderId, p) => (
        <div>
          <span className="font-mono text-xs font-semibold text-slate-200">{orderId || p.id?.substring(0, 8)}</span>
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
        const s = (status || '').toLowerCase();
        const map = {
          completed: { label: 'سەرکەوتوو', variant: 'success' },
          paid: { label: 'دراوە', variant: 'success' },
          pending: { label: 'چاوەڕوانی پەسەندکردن', variant: 'warning' },
          failed: { label: 'شکستخواردوو', variant: 'danger' },
          cancelled: { label: 'هەڵوەشاوە', variant: 'default' },
          refunded: { label: 'گەڕێنراوەتەوە', variant: 'purple' },
        };
        const st = map[s] || { label: status || '—', variant: 'default' };
        return <Badge variant={st.variant}>{st.label}</Badge>;
      },
    },
    {
      key: 'created_at',
      label: 'بەروار و کات',
      render: (date) => (
        <span className="text-xs text-slate-400 font-mono">
          {date ? new Date(date).toLocaleString('ku-IQ') : '—'}
        </span>
      ),
    },
    {
      key: 'actions',
      label: 'کردارەکان',
      className: 'text-left',
      render: (_, p) => {
        const isPending = (p.status || '').toLowerCase() === 'pending';
        return (
          <div className="flex items-center gap-1.5 justify-end">
            {isPending && (
              <button
                onClick={() => setConfirmModal({ type: 'approve', payment: p })}
                className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-emerald-600/90 hover:bg-emerald-500 text-xs font-bold text-white transition-all shadow-sm"
                title="پەسەندکردنی VIP"
              >
                <Crown className="w-3.5 h-3.5 text-amber-300" />
                <span>پەسەندکردنی VIP</span>
              </button>
            )}

            <button
              onClick={() => setSelectedPayment(p)}
              className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
              title="بینینی وەسڵ و وردەکاری"
            >
              <Eye className="w-4 h-4 text-brand-400" />
            </button>
          </div>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی پارەدان (Payments)</h1>
          <p className="text-xs text-slate-400 mt-1">
            مێژووی مامەڵەکان، وەسڵی حەواڵەی خوێندکاران و پەسەندکردنی بەشداریکردنی VIP
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
          <option value="pending">چاوەڕوانی پەسەندکردن (Pending VIP)</option>
          <option value="completed">سەرکەوتوو (Completed)</option>
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

      {/* ─── Receipt & Details Modal ─── */}
      {selectedPayment && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-lg overflow-hidden shadow-2xl">
            <div className="p-6 border-b border-slate-800 flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Receipt className="w-5 h-5 text-brand-400" />
                <h3 className="text-base font-bold text-white">وردەکاری مامەڵەی پارەدان</h3>
              </div>
              <span className="text-xs font-mono text-slate-400">
                {selectedPayment.order_id || selectedPayment.id?.substring(0, 8)}
              </span>
            </div>

            <div className="p-6 space-y-4">
              <div className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/60 border border-slate-800">
                <span className="text-xs text-slate-400">بەکارهێنەر:</span>
                <span className="text-sm font-bold text-white">
                  {selectedPayment.profiles?.full_name || 'خوێندکار'}
                </span>
              </div>

              <div className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/60 border border-slate-800">
                <span className="text-xs text-slate-400">ئیمەیڵ:</span>
                <span className="text-xs font-mono text-slate-300">
                  {selectedPayment.profiles?.email || '—'}
                </span>
              </div>

              <div className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/60 border border-slate-800">
                <span className="text-xs text-slate-400">دەروازە و بڕی پارە:</span>
                <span className="text-sm font-bold text-emerald-400">
                  {Number(selectedPayment.amount || 0).toLocaleString()} {selectedPayment.currency || 'IQD'} ({selectedPayment.provider?.toUpperCase()})
                </span>
              </div>

              <div className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/60 border border-slate-800">
                <span className="text-xs text-slate-400">دۆخ:</span>
                <span className="text-xs font-semibold text-white">
                  {selectedPayment.status || 'PENDING'}
                </span>
              </div>

              {/* If pending, show plan selection */}
              {(selectedPayment.status || '').toLowerCase() === 'pending' && (
                <div className="p-4 rounded-xl bg-brand-950/30 border border-brand-800/40 space-y-2.5">
                  <label className="text-xs font-bold text-brand-300 flex items-center gap-1.5">
                    <Crown className="w-4 h-4 text-amber-400" />
                    <span>ماوەی پێدانی بەشداریکردنی VIP:</span>
                  </label>
                  <select
                    value={planDays}
                    onChange={(e) => setPlanDays(Number(e.target.value))}
                    className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm font-semibold text-white focus:outline-none focus:border-brand-500"
                  >
                    <option value={30}>١ مانگ (٣٠ ڕۆژ - 10,000 دینار)</option>
                    <option value={90}>٣ مانگ (٩٠ ڕۆژ - 25,000 دینار)</option>
                    <option value={270}>٩ مانگ / ساڵی خوێندن (٢٧٠ ڕۆژ - 35,000 دینار)</option>
                    <option value={365}>١ ساڵ (٣٦٥ ڕۆژ - VIP هەمیشەیی)</option>
                  </select>
                </div>
              )}
            </div>

            <div className="p-4 border-t border-slate-800 bg-slate-950/40 flex items-center justify-between">
              <button
                onClick={() => setSelectedPayment(null)}
                className="px-4 py-2 rounded-xl text-xs font-medium text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
              >
                داخستن
              </button>

              {(selectedPayment.status || '').toLowerCase() === 'pending' && (
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleReject(selectedPayment)}
                    className="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-red-900/60 text-xs font-semibold text-slate-300 hover:text-red-300 transition-colors border border-slate-700"
                  >
                    ڕەتکردنەوە
                  </button>
                  <button
                    onClick={() => handleApprove(selectedPayment)}
                    className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-xs font-bold text-white transition-colors shadow-sm"
                  >
                    <CheckCircle2 className="w-4 h-4" />
                    <span>پەسەندکردن و بەخشینی VIP</span>
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ─── Confirm Approval Modal ─── */}
      {confirmModal && (
        <ConfirmModal
          isOpen={true}
          title="پەسەندکردنی بەشداریکردنی VIP"
          message={`ئایا دڵنیایت دەتەوێت داواکاری پارەدانی "${confirmModal.payment.profiles?.full_name || 'خوێندکار'}" بە بڕی ${Number(confirmModal.payment.amount || 0).toLocaleString()} دینار پەسەند بکەیت؟ هەژمارەکەی ڕاستەوخۆ دەبێتە VIP و ئاگاداری پیرۆزبایی بۆ دەنێردرێت.`}
          confirmLabel="بەڵێ، پەسەندی بکە"
          cancelLabel="پاشگەزبوونەوە"
          variant="primary"
          onConfirm={() => handleApprove(confirmModal.payment)}
          onCancel={() => setConfirmModal(null)}
        />
      )}

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
