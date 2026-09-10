import React, { useState, useEffect, useCallback } from 'react';
import { ShieldCheck, Search, Filter, Eye, Code } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';

export default function AuditLogs() {
  const [logs, setLogs] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, limit: 20, total: 0, totalPages: 1 });
  const [loading, setLoading] = useState(true);

  // Filters
  const [actionFilter, setActionFilter] = useState('');
  const [resourceFilter, setResourceFilter] = useState('');
  const [viewLog, setViewLog] = useState(null);

  const fetchLogs = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const res = await AdminApi.listAuditLogs({
        page,
        limit: pagination.limit,
        action: actionFilter || undefined,
        resource_type: resourceFilter || undefined,
      });
      setLogs(res.logs || []);
      setPagination(res.pagination || { page: 1, limit: 20, total: 0, totalPages: 1 });
    } catch (err) {
      console.error('Failed to load audit logs:', err);
    } finally {
      setLoading(false);
    }
  }, [pagination.limit, actionFilter, resourceFilter]);

  useEffect(() => {
    fetchLogs(1);
  }, [actionFilter, resourceFilter]);

  const columns = [
    {
      key: 'action',
      label: 'کردار (Action)',
      render: (action) => {
        const map = {
          user_suspended: { label: 'سڕکردنی بەکارهێنەر', variant: 'danger' },
          user_activated: { label: 'چالاککردنی بەکارهێنەر', variant: 'success' },
          role_changed: { label: 'گۆڕینی ڕۆڵ', variant: 'warning' },
          plan_changed: { label: 'گۆڕینی پلان / VIP', variant: 'primary' },
          limit_changed: { label: 'دەستکاری سنوور', variant: 'purple' },
          limit_created: { label: 'دروستکردنی سنوور', variant: 'purple' },
          university_created: { label: 'دروستکردنی زانکۆ', variant: 'primary' },
          university_deleted: { label: 'سڕینەوەی زانکۆ', variant: 'danger' },
          course_created: { label: 'دروستکردنی کۆرس', variant: 'primary' },
          course_archived: { label: 'ئەرشیڤکردنی کۆرس', variant: 'warning' },
          notification_broadcast: { label: 'پەخشی ئاگاداری', variant: 'success' },
        };
        const a = map[action] || { label: action, variant: 'default' };
        return <Badge variant={a.variant}>{a.label}</Badge>;
      },
    },
    {
      key: 'actor_id',
      label: 'ناسنامەی ئەدمین (Actor ID)',
      render: (actorId) => (
        <span className="font-mono text-xs text-slate-300">{actorId ? actorId.substring(0, 10) + '...' : 'سیستەم'}</span>
      ),
    },
    {
      key: 'resource_type',
      label: 'جۆری سەرچاوە',
      render: (type, log) => (
        <div>
          <span className="text-xs uppercase font-semibold text-slate-300">{type}</span>
          {log.resource_id && (
            <span className="block font-mono text-[10px] text-slate-500">{log.resource_id.substring(0, 12)}</span>
          )}
        </div>
      ),
    },
    {
      key: 'ip_address',
      label: 'ناونیشانی IP',
      render: (ip) => (
        <span className="font-mono text-xs text-slate-400">{ip || '127.0.0.1'}</span>
      ),
    },
    {
      key: 'created_at',
      label: 'کات و بەروار',
      render: (date) => (
        <span className="text-xs text-slate-400">
          {date ? new Date(date).toLocaleString('ku-IQ') : '—'}
        </span>
      ),
    },
    {
      key: 'actions',
      label: 'وردەکاری',
      className: 'text-left',
      render: (_, log) => (
        <button
          onClick={() => setViewLog(log)}
          className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
          title="بینینی گۆڕانکارییەکان (JSON Diff)"
        >
          <Code className="w-4 h-4" />
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold text-white tracking-tight">تۆماری دەستکارینەکراوی ئاسایش (Immutable Audit Logs)</h1>
        <p className="text-xs text-slate-400 mt-1">
          تۆماری تەواوی هەموو کردەوە کارگێڕییەکان، گۆڕینی ڕۆڵ، سڕکردن و بەخشینی مۆڵەتەکان بە بێ هیچ دزەکردنێکی نهێنی
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <select
          value={actionFilter}
          onChange={(e) => setActionFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو کردارەکان</option>
          <option value="user_suspended">سڕکردنی بەکارهێنەر (user_suspended)</option>
          <option value="user_activated">چالاککردنی بەکارهێنەر (user_activated)</option>
          <option value="role_changed">گۆڕینی ڕۆڵ (role_changed)</option>
          <option value="plan_changed">گۆڕینی پلان (plan_changed)</option>
          <option value="limit_changed">گۆڕینی سنوور (limit_changed)</option>
          <option value="notification_broadcast">پەخشی ئاگاداری (notification_broadcast)</option>
        </select>

        <select
          value={resourceFilter}
          onChange={(e) => setResourceFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو سەرچاوەکان</option>
          <option value="user">بەکارهێنەر (user)</option>
          <option value="plan_limit">سنووری پلان (plan_limit)</option>
          <option value="university">زانکۆ (university)</option>
          <option value="course">کۆرس (course)</option>
          <option value="notification">ئاگاداری (notification)</option>
        </select>
      </div>

      <DataTable
        columns={columns}
        data={logs}
        loading={loading}
        pagination={pagination}
        onPageChange={(p) => fetchLogs(p)}
        emptyMessage="هیچ تۆمارێکی ئاسایش نەدۆزرایەوە."
      />

      {/* ─── JSON Diff View Modal ─── */}
      <ConfirmModal
        isOpen={Boolean(viewLog)}
        title={`تۆماری ئاسایش: ${viewLog?.action || ''}`}
        confirmText="داخستن"
        cancelText=""
        danger={false}
        onConfirm={() => setViewLog(null)}
        onCancel={() => setViewLog(null)}
      >
        <div className="space-y-3 text-xs">
          <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-1">
            <p className="text-slate-400">ئەنجامدەر (Actor): <span className="font-mono text-white">{viewLog?.actor_id || 'سێرڤەر'}</span></p>
            <p className="text-slate-400">ئامانج (Resource): <span className="font-mono text-white">{viewLog?.resource_type} ({viewLog?.resource_id || 'N/A'})</span></p>
            <p className="text-slate-400">ناونیشانی IP: <span className="font-mono text-white">{viewLog?.ip_address || '127.0.0.1'}</span></p>
          </div>

          <div>
            <label className="block text-slate-300 font-semibold mb-1">وردەکاری گۆڕانکارییەکان (Metadata / Changes):</label>
            <pre className="p-3 rounded-xl bg-black/80 border border-slate-800 text-emerald-400 font-mono text-[11px] overflow-x-auto max-h-56">
              {JSON.stringify(viewLog?.changes || {}, null, 2)}
            </pre>
          </div>
        </div>
      </ConfirmModal>
    </div>
  );
}
