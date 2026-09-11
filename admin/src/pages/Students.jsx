import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Eye, Crown, UserX, UserCheck, Trash2 } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function Students() {
  const navigate = useNavigate();
  const [students, setStudents] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, limit: 20, total: 0, totalPages: 1 });
  const [loading, setLoading] = useState(true);

  const [search, setSearch] = useState('');
  const [planFilter, setPlanFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  // Modals & Action States
  const [actionTarget, setActionTarget] = useState(null);
  const [actionType, setActionType] = useState(null); // 'suspend' | 'activate' | 'delete'
  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const fetchStudents = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const res = await AdminApi.listStudents({
        page,
        limit: pagination.limit,
        q: search.trim() || undefined,
        plan: planFilter || undefined,
        status: statusFilter || undefined,
      });
      setStudents(res.students || []);
      setPagination(res.pagination || { page: 1, limit: 20, total: 0, totalPages: 1 });
    } catch (err) {
      console.error('Failed to list students:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی خوێندکاران.' });
    } finally {
      setLoading(false);
    }
  }, [pagination.limit, search, planFilter, statusFilter]);

  useEffect(() => {
    fetchStudents(1);
  }, [planFilter, statusFilter]);

  const handleToggleStatus = async () => {
    if (!actionTarget) return;
    setActionLoading(true);
    const targetId = actionTarget.id;
    const targetName = actionTarget.full_name || actionTarget.email;

    try {
      if (actionType === 'delete') {
        setStudents(prev => prev.filter(s => s.id !== targetId));
        await AdminApi.deleteUser(targetId);
        setToast({ type: 'success', message: `هەژماری خوێندکار ${targetName} سڕایەوە.` });
      } else {
        const newStatus = actionType === 'suspend' ? 'suspended' : 'active';
        setStudents(prev => prev.map(s => s.id === targetId ? { ...s, status: newStatus } : s));
        await AdminApi.updateUserStatus(targetId, newStatus, 'خوێندکار لەلایەن ئەدمینەوە گۆڕدرا');
        setToast({
          type: 'success',
          message: `دۆخی هەژماری ${targetName} گۆڕدرا بۆ ${newStatus === 'active' ? 'چالاک' : 'سڕکراو'}.`,
        });
      }
      setActionTarget(null);
      setActionType(null);
      fetchStudents(pagination.page);
    } catch (err) {
      setToast({ type: 'error', message: err.response?.data?.message || 'هەڵە لە ئەنجامدانی کردار.' });
    } finally {
      setActionLoading(false);
    }
  };

  const columns = [
    {
      key: 'name',
      label: 'خوێندکار',
      render: (_, s) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-slate-800 border border-slate-700 flex items-center justify-center font-bold text-xs text-slate-200 shrink-0">
            {s.full_name?.[0] || s.email?.[0]?.toUpperCase() || 'S'}
          </div>
          <div>
            <p className="font-semibold text-white">{s.full_name || 'بێ ناو'}</p>
            <p className="text-xs text-slate-400 font-mono">{s.email}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'plan',
      label: 'پلان',
      render: (plan, s) => (
        <Badge variant={plan === 'premium' || s.is_vip ? 'success' : 'default'} className="gap-1">
          {plan === 'premium' || s.is_vip ? (
            <>
              <Crown className="w-3 h-3 text-amber-400" />
              <span>پریمیۆم</span>
            </>
          ) : (
            <span>بەخۆڕایی</span>
          )}
        </Badge>
      ),
    },
    {
      key: 'status',
      label: 'دۆخی هەژمار',
      render: (status) => (
        <Badge variant={status === 'active' ? 'success' : 'danger'}>
          {status === 'active' ? 'چالاک' : 'سڕکراو'}
        </Badge>
      ),
    },
    {
      key: 'created_at',
      label: 'بەرواری دروستکردن',
      render: (date) => (
        <span className="text-xs text-slate-400">
          {date ? new Date(date).toLocaleDateString('ku-IQ') : '—'}
        </span>
      ),
    },
    {
      key: 'actions',
      label: 'کردارەکان',
      className: 'text-left',
      render: (_, s) => (
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={() => navigate(`/users/${s.id}`)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
            title="بینینی پرۆفایل و پێشکەوتن"
          >
            <Eye className="w-4 h-4" />
          </button>
          {s.status === 'active' ? (
            <button
              onClick={() => {
                setActionTarget(s);
                setActionType('suspend');
              }}
              className="p-1.5 rounded-lg bg-rose-950/60 hover:bg-rose-900 text-rose-400 border border-rose-800/40 transition-colors"
              title="سڕکردن"
            >
              <UserX className="w-4 h-4" />
            </button>
          ) : (
            <button
              onClick={() => {
                setActionTarget(s);
                setActionType('activate');
              }}
              className="p-1.5 rounded-lg bg-emerald-950/60 hover:bg-emerald-900 text-emerald-400 border border-emerald-800/40 transition-colors"
              title="چالاککردنەوە"
            >
              <UserCheck className="w-4 h-4" />
            </button>
          )}
          <button
            onClick={() => {
              setActionTarget(s);
              setActionType('delete');
            }}
            className="p-1.5 rounded-lg bg-rose-950/40 hover:bg-rose-900/80 text-rose-400/80 hover:text-rose-300 border border-rose-800/30 transition-colors"
            title="سڕینەوەی خوێندکار"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی خوێندکاران</h1>
          <p className="text-xs text-slate-400 mt-1">
            چاودێری خوێندکاران، بەشداریکردنەکان و کۆرسە ئەکادیمییەکان
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="relative">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && fetchStudents(1)}
            placeholder="گەڕان بەپێی ناوی خوێندکار یان ئیمەیڵ..."
            className="w-full pl-4 pr-10 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500"
          />
          <Search className="w-4 h-4 text-slate-400 absolute right-3.5 top-3" />
        </div>

        <select
          value={planFilter}
          onChange={(e) => setPlanFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو پلانەکان</option>
          <option value="free">بەخۆڕایی (Free)</option>
          <option value="premium">پریمیۆم (VIP)</option>
        </select>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو دۆخەکان</option>
          <option value="active">چالاک (Active)</option>
          <option value="suspended">سڕکراو (Suspended)</option>
        </select>
      </div>

      <DataTable
        columns={columns}
        data={students}
        loading={loading}
        pagination={pagination}
        onPageChange={(p) => fetchStudents(p)}
        emptyMessage="هیچ خوێندکارێک نەدۆزرایەوە."
      />

      <ConfirmModal
        isOpen={Boolean(actionTarget)}
        title={
          actionType === 'delete'
            ? 'سڕینەوەی هەژماری خوێندکار'
            : actionType === 'suspend'
            ? 'سڕکردنی هەژماری خوێندکار'
            : 'چالاککردنەوەی هەژماری خوێندکار'
        }
        message={
          actionType === 'delete'
            ? `ئایا دڵنیایت لە سڕینەوەی تەواوەتی هەژماری خوێندکار ${actionTarget?.full_name || actionTarget?.email}؟`
            : `ئایا دڵنیایت لە گۆڕینی دۆخی ${actionTarget?.full_name || actionTarget?.email}؟`
        }
        confirmText={actionType === 'delete' ? 'سڕینەوە' : actionType === 'suspend' ? 'سڕکردن' : 'چالاککردنەوە'}
        danger={actionType === 'suspend' || actionType === 'delete'}
        loading={actionLoading}
        onConfirm={handleToggleStatus}
        onCancel={() => {
          setActionTarget(null);
          setActionType(null);
        }}
      />

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
