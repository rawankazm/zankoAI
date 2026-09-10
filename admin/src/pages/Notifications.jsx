import React, { useState, useEffect } from 'react';
import { Bell, Send, AlertTriangle, Users, BookOpen, Wrench, ShieldAlert } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';
import LoadingSpinner from '../components/LoadingSpinner';

export default function Notifications() {
  const [notifications, setNotifications] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, limit: 20, total: 0, totalPages: 1 });
  const [loading, setLoading] = useState(true);

  // Form State
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [type, setType] = useState('system_announcement');
  const [target, setTarget] = useState('all');
  const [sendModal, setSendModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const fetchNotifications = async (page = 1) => {
    setLoading(true);
    try {
      const res = await AdminApi.listNotifications(page, pagination.limit);
      setNotifications(res.notifications || []);
      setPagination(res.pagination || { page: 1, limit: 20, total: 0, totalPages: 1 });
    } catch (err) {
      console.error('Failed to load notifications:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchNotifications(1);
  }, []);

  const handleBroadcast = async () => {
    if (!title.trim() || !body.trim()) {
      setToast({ type: 'error', message: 'تکایە ناونیشان و دەقی ئاگادارکردنەوە پڕبکەرەوە.' });
      return;
    }

    setActionLoading(true);
    try {
      const res = await AdminApi.broadcastNotification({
        title: title.trim(),
        body: body.trim(),
        type,
        target,
      });

      setToast({
        type: 'success',
        message: `ئاگادارکردنەوە بە سەرکەوتوویی نێردرا بۆ ${res.recipientsCount || 'تەواوی'} بەکارهێنەر.`,
      });

      setSendModal(false);
      setTitle('');
      setBody('');
      fetchNotifications(1);
    } catch (err) {
      setToast({ type: 'error', message: err.response?.data?.message || 'هەڵە لە ناردنی ئاگادارکردنەوە.' });
    } finally {
      setActionLoading(false);
    }
  };

  const columns = [
    {
      key: 'title',
      label: 'ناونیشان و دەق',
      render: (t, n) => (
        <div>
          <p className="font-semibold text-white">{t}</p>
          <p className="text-xs text-slate-400 line-clamp-1">{n.body}</p>
        </div>
      ),
    },
    {
      key: 'type',
      label: 'جۆر',
      render: (t) => {
        const map = {
          system_announcement: { label: 'ئاگاداری سیستەم', variant: 'primary' },
          maintenance: { label: 'چاکسازی سیستەم', variant: 'warning' },
          educational: { label: 'پەیامی پەروەردەیی', variant: 'success' },
          announcements: { label: 'ئاگاداری گشتی', variant: 'default' },
        };
        const item = map[t] || { label: t, variant: 'default' };
        return <Badge variant={item.variant}>{item.label}</Badge>;
      },
    },
    {
      key: 'created_at',
      label: 'بەرواری ناردن',
      render: (date) => (
        <span className="text-xs text-slate-400">
          {date ? new Date(date).toLocaleString('ku-IQ') : '—'}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-8 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی ئاگادارکردنەوەکان (Announcements)</h1>
        <p className="text-xs text-slate-400 mt-1">
          ناردنی ئاگاداری گشتی بۆ هەموو خوێندکاران، مامۆستایان یان بەشداربووانی پریمیۆم لە ڕێگەی سێرڤەرەوە
        </p>
      </div>

      {/* ─── Create Announcement Card ─── */}
      <div className="glass-card rounded-2xl p-6 border border-slate-800 space-y-4">
        <h3 className="text-base font-bold text-white flex items-center gap-2">
          <Send className="w-5 h-5 text-brand-400" />
          <span>دروستکردنی ئاگادارکردنەوەی نوێ</span>
        </h3>

        <div className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">ناونیشانی ئاگاداری:</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="بۆ نموونە: تاقیکردنەوەکانی کۆتایی وەرزی یەکەم"
                className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">جۆری پەیام:</label>
                <select
                  value={type}
                  onChange={(e) => setType(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
                >
                  <option value="system_announcement">ئاگاداری سیستەم</option>
                  <option value="maintenance">چاکسازی سیستەم</option>
                  <option value="educational">ڕێنمایی پەروەردەیی</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">ئامانجی ناردن:</label>
                <select
                  value={target}
                  onChange={(e) => setTarget(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
                >
                  <option value="all">هەموو بەکارهێنەران</option>
                  <option value="students">تەنها خوێندکاران</option>
                  <option value="teachers">تەنها مامۆستایان</option>
                  <option value="premium">تەنها پریمیۆم (VIP)</option>
                </select>
              </div>
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">دەقی پەیام:</label>
            <textarea
              rows={3}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="دەقی تەواوی ئاگادارییەکە لێرەدا بنووسە..."
              className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500 resize-none"
            />
          </div>

          <div className="flex justify-end pt-2">
            <button
              onClick={() => setSendModal(true)}
              disabled={!title.trim() || !body.trim()}
              className="px-6 py-2.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-semibold text-xs flex items-center gap-2 shadow-lg shadow-brand-900/30 transition-all disabled:opacity-50"
            >
              <Send className="w-4 h-4" />
              <span>پێداچوونەوە و ناردن</span>
            </button>
          </div>
        </div>
      </div>

      {/* ─── Recent Broadcasts History Table ─── */}
      <div>
        <h3 className="text-base font-bold text-white mb-3">مێژووی ئاگادارییە نێردراوەکان</h3>
        <DataTable
          columns={columns}
          data={notifications}
          loading={loading}
          pagination={pagination}
          onPageChange={(p) => fetchNotifications(p)}
          emptyMessage="هیچ ئاگادارییەک نەنێردراوە لەم دواییەدا."
        />
      </div>

      {/* ─── Broadcast Confirmation Modal ─── */}
      <ConfirmModal
        isOpen={sendModal}
        title="دڵنیابوونەوە لە پەخشی ئاگادارکردنەوە"
        message={`ئایا دڵنیایت لە پەخشکردنی ئەم ئاگادارییە بۆ '${target === 'all' ? 'هەموو بەکارهێنەران' : target}'؟ ئەم کردارە ڕاستەوخۆ دەچێتە نۆرەی Background Worker بۆ گەیشتن بە مۆبایلی بەکارهێنەران.`}
        confirmText="پەخشکردن ئێستا"
        danger={false}
        loading={actionLoading}
        onConfirm={handleBroadcast}
        onCancel={() => setSendModal(false)}
      />

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
