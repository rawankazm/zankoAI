import React, { useState, useEffect, useCallback } from 'react';
import {
  ShieldAlert,
  CheckCircle2,
  XCircle,
  Clock,
  Search,
  RefreshCw,
  UserCheck,
  Ban,
  ExternalLink,
} from 'lucide-react';
import { AdminApi } from '../services/api';
import { supabase } from '../services/supabase';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function SecurityAppeals() {
  const [appeals, setAppeals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState(null);

  // Filters
  const [statusFilter, setStatusFilter] = useState('all');
  const [search, setSearch] = useState('');

  // Processing state
  const [processingId, setProcessingId] = useState(null);
  const [selectedAppeal, setSelectedAppeal] = useState(null);
  const [confirmAction, setConfirmAction] = useState(null); // { type: 'approve' | 'reject', appeal }

  const fetchAppeals = useCallback(async () => {
    setLoading(true);
    try {
      const list = await AdminApi.listSecurityAppeals({
        status: statusFilter,
      });
      setAppeals(list || []);
    } catch (err) {
      console.error('Failed to load security appeals:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی داواکارییەکان.' });
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => {
    fetchAppeals();

    const channel = supabase
      .channel('admin_appeals_realtime_sync')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'notifications' },
        () => {
          fetchAppeals();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetchAppeals]);

  const handleApprove = async (appeal) => {
    setProcessingId(appeal.id);
    try {
      await AdminApi.approveIpAppeal(appeal.id, appeal.email, appeal.user_id);
      setAppeals((prev) =>
        prev.map((a) => (a.id === appeal.id ? { ...a, status: 'approved' } : a))
      );
      setToast({
        type: 'success',
        message: `✅ ناونیشانی IPی (${appeal.name}) بە سەرکەوتوویی نوێکرایەوە و ڕێگەی پێدرا بچێتە ژوورەوە.`,
      });
      setConfirmAction(null);
    } catch (e) {
      setToast({ type: 'error', message: 'کێشەیەک ڕوویدا لە پەسەندکردن.' });
    } finally {
      setProcessingId(null);
    }
  };

  const handleReject = async (appeal) => {
    setProcessingId(appeal.id);
    try {
      await AdminApi.rejectIpAppeal(appeal.id);
      setAppeals((prev) =>
        prev.map((a) => (a.id === appeal.id ? { ...a, status: 'rejected' } : a))
      );
      setToast({
        type: 'warning',
        message: `داواکاریی (${appeal.name}) ڕەتکرایەوە.`,
      });
      setConfirmAction(null);
    } catch (e) {
      setToast({ type: 'error', message: 'کێشەیەک ڕوویدا لە ڕەتکردنەوە.' });
    } finally {
      setProcessingId(null);
    }
  };

  const filteredAppeals = appeals.filter((a) => {
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    return (
      a.name.toLowerCase().includes(q) ||
      a.email.toLowerCase().includes(q) ||
      a.userNote.toLowerCase().includes(q)
    );
  });

  const stats = {
    total: appeals.length,
    pending: appeals.filter((a) => a.status === 'pending').length,
    approved: appeals.filter((a) => a.status === 'approved').length,
  };

  const columns = [
    {
      key: 'user',
      label: 'خوێندکار',
      render: (_, a) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-amber-600 to-rose-600 flex items-center justify-center font-bold text-sm text-white shadow-sm">
            {a.name?.[0] || 'U'}
          </div>
          <div>
            <p className="font-semibold text-white text-sm">{a.name}</p>
            <p className="text-xs text-slate-400 font-mono">{a.email}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'userNote',
      label: 'هۆکار و تێبینی خوێندکار',
      render: (note, a) => (
        <div className="max-w-md">
          <p className="text-xs text-slate-200 line-clamp-2 leading-relaxed font-medium">
            {note || a.reason || 'داواکاری گۆڕینی ئایپی'}
          </p>
          <span className="text-[11px] text-amber-400/90 mt-0.5 block">
            هۆکار: تێپەڕاندنی سنووری ٣ ئایپی جیاواز
          </span>
        </div>
      ),
    },
    {
      key: 'status',
      label: 'دۆخی داواکاری',
      render: (status) => {
        switch (status) {
          case 'approved':
            return <Badge variant="success">پەسەندکراو (چالاکە)</Badge>;
          case 'rejected':
            return <Badge variant="danger">ڕەتکراوەتەوە</Badge>;
          default:
            return <Badge variant="warning">چاوەڕوانی پێداچوونەوە</Badge>;
        }
      },
    },
    {
      key: 'created_at',
      label: 'کات و بەروار',
      render: (date) => (
        <span className="text-xs text-slate-400 font-mono">
          {date ? new Date(date).toLocaleString('ku-IQ', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—'}
        </span>
      ),
    },
    {
      key: 'actions',
      label: 'کرداری بەپەلە',
      className: 'text-left',
      render: (_, a) => {
        const isProcessing = processingId === a.id;
        const isPending = a.status === 'pending';
        return (
          <div className="flex items-center gap-2 justify-end">
            {isPending && (
              <>
                <button
                  onClick={() => setConfirmAction({ type: 'approve', appeal: a })}
                  disabled={isProcessing}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600/90 hover:bg-emerald-500 text-xs font-bold text-white transition-all shadow-sm"
                  title="پەسەندکردنی نوێکردنەوەی IP"
                >
                  <CheckCircle2 className="w-3.5 h-3.5" />
                  <span>پەسەندکردن</span>
                </button>

                <button
                  onClick={() => setConfirmAction({ type: 'reject', appeal: a })}
                  disabled={isProcessing}
                  className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-red-900/60 text-xs font-medium text-slate-300 hover:text-red-300 transition-all border border-slate-700"
                  title="ڕەتکردنەوە"
                >
                  <XCircle className="w-3.5 h-3.5" />
                  <span>ڕەتکردنەوە</span>
                </button>
              </>
            )}

            {!isPending && (
              <span className="text-xs text-slate-500 font-mono">
                {a.status === 'approved' ? 'پەسەندکراوە' : 'ڕەتکراوە'}
              </span>
            )}
          </div>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      {/* ─── Header ─── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-amber-500/10 text-amber-400 border border-amber-500/20">
              <ShieldAlert className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white tracking-tight">
                داواکارییەکانی نوێکردنەوەی IP و ئاسایش (Security Appeals)
              </h1>
              <p className="text-xs text-slate-400 mt-0.5">
                چاودێری و پەسەندکردنی داواکاریی ئەو قوتابیانەی لە لۆگیندا بەهۆی سنووری ٣ ئایپی بلۆک کراون
              </p>
            </div>
          </div>
        </div>

        <button
          onClick={fetchAppeals}
          disabled={loading}
          className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-800 text-sm font-medium text-slate-300 hover:text-white hover:bg-slate-800 transition-all self-start sm:self-auto"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-amber-400' : ''}`} />
          <span>نوێکردنەوە</span>
        </button>
      </div>

      {/* ─── Stat Cards ─── */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5">
        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800/80 shadow-sm flex items-center gap-3.5">
          <div className="p-3 rounded-xl bg-amber-500/15 text-amber-400 border border-amber-500/20">
            <Clock className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400 font-medium">داواکاریی چاوەڕوانکراو (Pending)</p>
            <p className="text-2xl font-bold text-amber-400 mt-0.5">{stats.pending}</p>
          </div>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800/80 shadow-sm flex items-center gap-3.5">
          <div className="p-3 rounded-xl bg-emerald-500/15 text-emerald-400 border border-emerald-500/20">
            <CheckCircle2 className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400 font-medium">پەسەندکراوەکان (Approved)</p>
            <p className="text-2xl font-bold text-white mt-0.5">{stats.approved}</p>
          </div>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800/80 shadow-sm flex items-center gap-3.5">
          <div className="p-3 rounded-xl bg-brand-500/15 text-brand-400 border border-brand-500/20">
            <ShieldAlert className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400 font-medium">کۆی گشتی داواکارییەکان</p>
            <p className="text-2xl font-bold text-white mt-0.5">{stats.total}</p>
          </div>
        </div>
      </div>

      {/* ─── Search & Filters ─── */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="relative sm:col-span-2">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="گەڕان بەپێی ناوی خوێندکار، ئیمەیڵ یان تێبینی..."
            className="w-full pl-4 pr-10 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-amber-500"
          />
          <Search className="w-4 h-4 text-slate-400 absolute right-3.5 top-3" />
        </div>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-amber-500"
        >
          <option value="all">هەموو دۆخەکان</option>
          <option value="pending">تەنها چاوەڕوانکراوەکان (Pending)</option>
          <option value="approved">پەسەندکراوەکان (Approved)</option>
          <option value="rejected">ڕەتکراوەکان (Rejected)</option>
        </select>
      </div>

      {/* ─── DataTable ─── */}
      <DataTable
        columns={columns}
        data={filteredAppeals}
        loading={loading}
        emptyMessage="هیچ داواکارییەکی نوێکردنەوەی IP لەم دۆخەدا نییە."
      />

      {/* ─── Confirmation Modal ─── */}
      {confirmAction && (
        <ConfirmModal
          isOpen={true}
          title={
            confirmAction.type === 'approve'
              ? 'پەسەندکردنی نوێکردنەوەی IP'
              : 'ڕەتکردنەوەی داواکاری'
          }
          message={
            confirmAction.type === 'approve'
              ? `ئایا دڵنیایت دەتەوێت داواکاریی خوێندکار "${confirmAction.appeal.name}" (${confirmAction.appeal.email}) پەسەند بکەیت؟ هەژمارەکەی دەستبەجێ چالاک دەبێتەوە و لەسەر مۆبایل ئاگاداری بۆ دەڕوات.`
              : `ئایا دڵنیایت دەتەوێت داواکاریی خوێندکار "${confirmAction.appeal.name}" ڕەت بکەیتەوە؟`
          }
          confirmLabel={
            confirmAction.type === 'approve'
              ? 'بەڵێ، پەسەندی بکە'
              : 'بەڵێ، ڕەتی بکەرەوە'
          }
          cancelLabel="پاشگەزبوونەوە"
          variant={confirmAction.type === 'approve' ? 'primary' : 'danger'}
          onConfirm={() =>
            confirmAction.type === 'approve'
              ? handleApprove(confirmAction.appeal)
              : handleReject(confirmAction.appeal)
          }
          onCancel={() => setConfirmAction(null)}
        />
      )}

      {/* ─── Toast Feedback ─── */}
      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
