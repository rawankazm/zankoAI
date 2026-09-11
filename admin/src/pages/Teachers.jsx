import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, UserCheck, UserX, Eye, BookOpen, AlertCircle, Trash2 } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function Teachers() {
  const navigate = useNavigate();
  const [teachers, setTeachers] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, limit: 20, total: 0, totalPages: 1 });
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  // Modals & Action States
  const [actionTarget, setActionTarget] = useState(null);
  const [actionType, setActionType] = useState(null); // 'suspend' | 'activate' | 'delete'
  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const fetchTeachers = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const res = await AdminApi.listTeachers({
        page,
        limit: pagination.limit,
        q: search.trim() || undefined,
        status: statusFilter || undefined,
      });
      setTeachers(res.teachers || []);
      setPagination(res.pagination || { page: 1, limit: 20, total: 0, totalPages: 1 });
    } catch (err) {
      console.error('Failed to list teachers:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی مامۆستایان.' });
    } finally {
      setLoading(false);
    }
  }, [pagination.limit, search, statusFilter]);

  useEffect(() => {
    fetchTeachers(1);
  }, [statusFilter]);

  const handleToggleStatus = async () => {
    if (!actionTarget) return;
    setActionLoading(true);
    const targetId = actionTarget.id;
    const targetName = actionTarget.full_name || actionTarget.email;

    try {
      if (actionType === 'delete') {
        setTeachers(prev => prev.filter(t => t.id !== targetId));
        await AdminApi.deleteUser(targetId);
        setToast({ type: 'success', message: `هەژماری مامۆستا ${targetName} سڕایەوە.` });
      } else {
        const newStatus = actionType === 'suspend' ? 'suspended' : 'active';
        setTeachers(prev => prev.map(t => t.id === targetId ? { ...t, status: newStatus } : t));
        await AdminApi.updateUserStatus(targetId, newStatus, 'مامۆستا لەلایەن ئەدمینەوە گۆڕدرا');
        setToast({
          type: 'success',
          message: `دۆخی مامۆستا ${targetName} گۆڕدرا بۆ ${newStatus === 'active' ? 'چالاک' : 'سڕکراو'}.`,
        });
      }
      setActionTarget(null);
      setActionType(null);
      fetchTeachers(pagination.page);
    } catch (err) {
      setToast({ type: 'error', message: err.response?.data?.message || 'هەڵە لە ئەنجامدانی کردار.' });
    } finally {
      setActionLoading(false);
    }
  };

  const columns = [
    {
      key: 'name',
      label: 'مامۆستا',
      render: (_, t) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-indigo-950/70 border border-indigo-800/60 flex items-center justify-center font-bold text-xs text-indigo-300 shrink-0">
            {t.full_name?.[0] || t.email?.[0]?.toUpperCase() || 'T'}
          </div>
          <div>
            <p className="font-semibold text-white">{t.full_name || 'بێ ناو'}</p>
            <p className="text-xs text-slate-400 font-mono">{t.email}</p>
          </div>
        </div>
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
      label: 'بەرواری پەیوەندیکردن',
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
      render: (_, t) => (
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={() => navigate(`/users/${t.id}`)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
            title="بینینی پرۆفایل و کۆرسەکان"
          >
            <Eye className="w-4 h-4" />
          </button>
          {t.status === 'active' ? (
            <button
              onClick={() => {
                setActionTarget(t);
                setActionType('suspend');
              }}
              className="p-1.5 rounded-lg bg-rose-950/60 hover:bg-rose-900 text-rose-400 border border-rose-800/40 transition-colors"
              title="سڕکردنی هەژمار"
            >
              <UserX className="w-4 h-4" />
            </button>
          ) : (
            <button
              onClick={() => {
                setActionTarget(t);
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
              setActionTarget(t);
              setActionType('delete');
            }}
            className="p-1.5 rounded-lg bg-rose-950/40 hover:bg-rose-900/80 text-rose-400/80 hover:text-rose-300 border border-rose-800/30 transition-colors"
            title="سڕینەوەی مامۆستا"
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
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی مامۆستایان</h1>
          <p className="text-xs text-slate-400 mt-1">
            چاودێری مامۆستایانی زانکۆ، کۆرسە وانەوتراوەکان و مۆڵەتی چالاکی
          </p>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row items-center gap-3">
        <div className="relative flex-1 w-full">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && fetchTeachers(1)}
            placeholder="گەڕان بەپێی ناوی مامۆستا یان ئیمەیڵ..."
            className="w-full pl-4 pr-10 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500"
          />
          <Search className="w-4 h-4 text-slate-400 absolute right-3.5 top-3" />
        </div>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="w-full sm:w-48 px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو دۆخەکان</option>
          <option value="active">چالاک (Active)</option>
          <option value="suspended">سڕکراو (Suspended)</option>
        </select>
      </div>

      <DataTable
        columns={columns}
        data={teachers}
        loading={loading}
        pagination={pagination}
        onPageChange={(p) => fetchTeachers(p)}
        emptyMessage="هیچ مامۆستایەک نەدۆزرایەوە."
      />

      <ConfirmModal
        isOpen={Boolean(actionTarget)}
        title={
          actionType === 'delete'
            ? 'سڕینەوەی هەژماری مامۆستا'
            : actionType === 'suspend'
            ? 'سڕکردنی هەژماری مامۆستا'
            : 'چالاککردنەوەی هەژماری مامۆستا'
        }
        message={
          actionType === 'delete'
            ? `ئایا دڵنیایت لە سڕینەوەی تەواوەتی هەژماری مامۆستا ${actionTarget?.full_name || actionTarget?.email}؟`
            : `ئایا دڵنیایت لە گۆڕینی دۆخی مامۆستا ${actionTarget?.full_name || actionTarget?.email}؟`
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
