import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Search,
  Filter,
  UserCheck,
  UserX,
  Eye,
  Crown,
  Shield,
  Clock,
  CheckCircle2,
  AlertCircle,
} from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function Users() {
  const navigate = useNavigate();

  const [users, setUsers] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, limit: 20, total: 0, totalPages: 1 });
  const [loading, setLoading] = useState(true);

  // Filters
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [planFilter, setPlanFilter] = useState('');

  // Modals & Action States
  const [actionTarget, setActionTarget] = useState(null);
  const [actionType, setActionType] = useState(null); // 'suspend' | 'activate' | 'vip' | 'role'
  const [actionReason, setActionReason] = useState('');
  const [selectedRole, setSelectedRole] = useState('student');
  const [vipDays, setVipDays] = useState(30);
  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const fetchUsers = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const res = await AdminApi.listUsers({
        page,
        limit: pagination.limit,
        q: search.trim() || undefined,
        role: roleFilter || undefined,
        status: statusFilter || undefined,
        plan: planFilter || undefined,
      });

      setUsers(res.users || []);
      setPagination(res.pagination || { page: 1, limit: 20, total: 0, totalPages: 1 });
    } catch (err) {
      console.error('Failed to list users:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی لیستی بەکارهێنەران.' });
    } finally {
      setLoading(false);
    }
  }, [pagination.limit, search, roleFilter, statusFilter, planFilter]);

  useEffect(() => {
    fetchUsers(1);
  }, [roleFilter, statusFilter, planFilter]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    fetchUsers(1);
  };

  const handleActionConfirm = async () => {
    if (!actionTarget) return;
    setActionLoading(true);

    try {
      if (actionType === 'suspend') {
        await AdminApi.updateUserStatus(actionTarget.id, 'suspended', actionReason || 'کارگێڕی ئەدمین');
        setToast({ type: 'success', message: `هەژماری ${actionTarget.full_name || actionTarget.email} سڕکرا.` });
      } else if (actionType === 'activate') {
        await AdminApi.updateUserStatus(actionTarget.id, 'active', 'چالاککردنەوەی ئەدمین');
        setToast({ type: 'success', message: `هەژماری ${actionTarget.full_name || actionTarget.email} چالاککرایەوە.` });
      } else if (actionType === 'vip') {
        await AdminApi.updateUserPlan(actionTarget.id, 'premium', Number(vipDays) || 30, actionReason || 'پێدانی VIP');
        setToast({ type: 'success', message: `پلانی بەکارهێنەر بەرزکرایەوە بۆ VIP بۆ ماوەی ${vipDays} ڕۆژ.` });
      } else if (actionType === 'role') {
        await AdminApi.updateUserRole(actionTarget.id, selectedRole, actionReason || 'گۆڕینی پلە');
        setToast({ type: 'success', message: `ڕۆڵی بەکارهێنەر گۆڕدرا بۆ ${selectedRole}.` });
      }

      setActionTarget(null);
      setActionType(null);
      setActionReason('');
      fetchUsers(pagination.page);
    } catch (err) {
      console.error('User action error:', err);
      setToast({
        type: 'error',
        message: err.response?.data?.message || 'کردارەکە ئەنجام نەدرا بەهۆی هەڵەیەکەوە.',
      });
    } finally {
      setActionLoading(false);
    }
  };

  const columns = [
    {
      key: 'user',
      label: 'بەکارهێنەر',
      render: (_, u) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-slate-800 border border-slate-700 flex items-center justify-center font-bold text-xs text-slate-200 shrink-0">
            {u.full_name?.[0] || u.email?.[0]?.toUpperCase() || 'U'}
          </div>
          <div className="min-w-0">
            <p className="font-semibold text-white truncate">{u.full_name || 'بێ ناو'}</p>
            <p className="text-xs text-slate-400 font-mono truncate">{u.email}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'role',
      label: 'ڕۆڵ',
      render: (role) => {
        const map = {
          student: { label: 'خوێندکار', variant: 'default' },
          teacher: { label: 'مامۆستا', variant: 'primary' },
          admin: { label: 'ئەدمین', variant: 'warning' },
        };
        const r = map[role] || { label: role, variant: 'default' };
        return <Badge variant={r.variant}>{r.label}</Badge>;
      },
    },
    {
      key: 'plan',
      label: 'پلان',
      render: (plan, u) => (
        <div className="flex items-center gap-1.5">
          {plan === 'premium' || u.is_vip ? (
            <Badge variant="success" className="gap-1">
              <Crown className="w-3 h-3 text-amber-400" />
              <span>پریمیۆم</span>
            </Badge>
          ) : (
            <Badge variant="default">بەخۆڕایی</Badge>
          )}
        </div>
      ),
    },
    {
      key: 'status',
      label: 'دۆخ',
      render: (status) => (
        <Badge variant={status === 'active' ? 'success' : 'danger'}>
          {status === 'active' ? 'چالاکە' : 'سڕکراوە'}
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
      render: (_, u) => (
        <div className="flex items-center justify-end gap-1.5">
          <button
            onClick={() => navigate(`/users/${u.id}`)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
            title="بینینی وردەکاری"
          >
            <Eye className="w-4 h-4" />
          </button>

          <button
            onClick={() => {
              setActionTarget(u);
              setActionType('vip');
            }}
            className="p-1.5 rounded-lg bg-emerald-950/60 hover:bg-emerald-900 text-emerald-400 border border-emerald-800/40 transition-colors"
            title="بەخشینی VIP"
          >
            <Crown className="w-4 h-4" />
          </button>

          <button
            onClick={() => {
              setActionTarget(u);
              setSelectedRole(u.role || 'student');
              setActionType('role');
            }}
            className="p-1.5 rounded-lg bg-indigo-950/60 hover:bg-indigo-900 text-indigo-400 border border-indigo-800/40 transition-colors"
            title="گۆڕینی ڕۆڵ"
          >
            <Shield className="w-4 h-4" />
          </button>

          {u.status === 'active' ? (
            <button
              onClick={() => {
                setActionTarget(u);
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
                setActionTarget(u);
                setActionType('activate');
              }}
              className="p-1.5 rounded-lg bg-emerald-950/60 hover:bg-emerald-900 text-emerald-400 border border-emerald-800/40 transition-colors"
              title="چالاککردنەوەی هەژمار"
            >
              <UserCheck className="w-4 h-4" />
            </button>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      {/* ─── Header ─── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی بەکارهێنەران</h1>
          <p className="text-xs text-slate-400 mt-1">
            گەڕان، فلتەرکردن، سڕکردن، پێدانی VIP و چاودێری مۆڵەتەکانی بەکارهێنەران
          </p>
        </div>
      </div>

      {/* ─── Filter Bar ─── */}
      <form onSubmit={handleSearchSubmit} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
        <div className="lg:col-span-2 relative">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="گەڕان بەپێی ناو، ئیمەیڵ یان ناسنامە..."
            className="w-full pl-4 pr-10 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500 transition-all"
          />
          <Search className="w-4 h-4 text-slate-400 absolute right-3.5 top-3" />
        </div>

        <select
          value={roleFilter}
          onChange={(e) => setRoleFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو ڕۆڵەکان</option>
          <option value="student">خوێندکار (Student)</option>
          <option value="teacher">مامۆستا (Teacher)</option>
          <option value="admin">ئەدمین (Admin)</option>
        </select>

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
      </form>

      {/* ─── Main Users Table ─── */}
      <DataTable
        columns={columns}
        data={users}
        loading={loading}
        pagination={pagination}
        onPageChange={(p) => fetchUsers(p)}
        emptyMessage="هیچ بەکارهێنەرێک نەدۆزرایەوە بەپێی ئەم فلتەرانە."
      />

      {/* ─── Suspend/Activate Modal ─── */}
      <ConfirmModal
        isOpen={actionType === 'suspend' || actionType === 'activate'}
        title={actionType === 'suspend' ? 'سڕکردنی هەژماری بەکارهێنەر' : 'چالاککردنەوەی هەژمار'}
        message={`ئایا دڵنیایت لە ${actionType === 'suspend' ? 'سڕکردنی' : 'چالاککردنەوەی'} هەژماری ${actionTarget?.full_name || actionTarget?.email}؟ هەموو کردەوەیەک لە یۆمەنەی ئاسایشدا تۆمار دەکرێت.`}
        confirmText={actionType === 'suspend' ? 'سڕکردنی هەژمار' : 'چالاککردنەوە'}
        danger={actionType === 'suspend'}
        loading={actionLoading}
        onConfirm={handleActionConfirm}
        onCancel={() => {
          setActionTarget(null);
          setActionType(null);
        }}
      >
        {actionType === 'suspend' && (
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              هۆکاری سڕکردن (دەچێتە ناو تۆماری ئاسایش):
            </label>
            <input
              type="text"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              placeholder="بۆ نموونە: پێشێلکردنی یاساکانی بەکارهێنان یان هێرشی ئەمنی"
              className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-rose-500"
            />
          </div>
        )}
      </ConfirmModal>

      {/* ─── VIP Grant Modal ─── */}
      <ConfirmModal
        isOpen={actionType === 'vip'}
        title="بەخشینی پلانی VIP بە بەکارهێنەر"
        message={`دیاریکردنی ماوەی بەشداریکردنی پریمیۆم بۆ ${actionTarget?.full_name || actionTarget?.email}`}
        confirmText="بەخشینی VIP"
        danger={false}
        loading={actionLoading}
        onConfirm={handleActionConfirm}
        onCancel={() => {
          setActionTarget(null);
          setActionType(null);
        }}
      >
        <div className="space-y-3">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              ماوەی بەشداریکردن (ڕۆژ):
            </label>
            <select
              value={vipDays}
              onChange={(e) => setVipDays(Number(e.target.value))}
              className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
            >
              <option value={7}>7 ڕۆژ (تاقیکاری)</option>
              <option value={30}>30 ڕۆژ (1 مانگ)</option>
              <option value={90}>90 ڕۆژ (3 مانگ)</option>
              <option value={365}>365 ڕۆژ (1 ساڵ)</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              تێبینی یان هۆکار:
            </label>
            <input
              type="text"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              placeholder="بۆ نموونە: دیاری سەرکەوتن یان بەشداریکردنی دەستی"
              className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500"
            />
          </div>
        </div>
      </ConfirmModal>

      {/* ─── Role Change Modal ─── */}
      <ConfirmModal
        isOpen={actionType === 'role'}
        title="گۆڕینی ڕۆڵی بەکارهێنەر"
        message={`هۆشیاربە لە بەخشینی پلەی ئەدمین بۆ هەژمارەکان. کردارەکان ڕاستەوخۆ کار لە دەسەڵاتەکان دەکەن.`}
        confirmText="گۆڕینی ڕۆڵ"
        danger={selectedRole === 'admin'}
        loading={actionLoading}
        onConfirm={handleActionConfirm}
        onCancel={() => {
          setActionTarget(null);
          setActionType(null);
        }}
      >
        <div className="space-y-3">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              ڕۆڵی نوێ:
            </label>
            <select
              value={selectedRole}
              onChange={(e) => setSelectedRole(e.target.value)}
              className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
            >
              <option value="student">خوێندکار (Student)</option>
              <option value="teacher">مامۆستا (Teacher)</option>
              <option value="admin">بەڕێوەبەر (Admin)</option>
            </select>
          </div>
        </div>
      </ConfirmModal>

      {/* ─── Feedback Toast ─── */}
      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
