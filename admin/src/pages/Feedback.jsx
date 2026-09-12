import React, { useState, useEffect, useCallback } from 'react';
import {
  MessageSquareHeart,
  Star,
  Bug,
  Sparkles,
  Search,
  Filter,
  Eye,
  Send,
  Trash2,
  CheckCircle2,
  Clock,
  Palette,
  MessageCircle,
  RefreshCw,
} from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function Feedback() {
  const [feedbacks, setFeedbacks] = useState([]);
  const [stats, setStats] = useState({ total: 0, averageRating: '5.0', bugsCount: 0, featuresCount: 0 });
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState(null);

  // Filters
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [ratingFilter, setRatingFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');

  // Modals & Action states
  const [selectedFeedback, setSelectedFeedback] = useState(null);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [replyText, setReplyText] = useState('');
  const [isSendingReply, setIsSendingReply] = useState(false);

  const fetchFeedback = useCallback(async () => {
    setLoading(true);
    try {
      const res = await AdminApi.listUserFeedback({
        category: categoryFilter,
        rating: ratingFilter,
        status: statusFilter,
        q: search.trim() || undefined,
      });
      setFeedbacks(res.feedback || []);
      setStats(res.stats || { total: 0, averageRating: '5.0', bugsCount: 0, featuresCount: 0 });
    } catch (err) {
      console.error('Failed to load feedback:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی ڕا و پێشنیارەکان.' });
    } finally {
      setLoading(false);
    }
  }, [categoryFilter, ratingFilter, statusFilter, search]);

  useEffect(() => {
    fetchFeedback();
  }, [fetchFeedback]);

  const handleStatusChange = async (id, newStatus) => {
    try {
      await AdminApi.updateFeedbackStatus(id, newStatus);
      setFeedbacks((prev) =>
        prev.map((f) => (f.id === id ? { ...f, status: newStatus } : f))
      );
      if (selectedFeedback && selectedFeedback.id === id) {
        setSelectedFeedback((prev) => ({ ...prev, status: newStatus }));
      }
      setToast({ type: 'success', message: 'دۆخی پێشنیارەکە بە سەرکەوتوویی نوێکرایەوە.' });
    } catch (e) {
      setToast({ type: 'error', message: 'کێشەیەک ڕوویدا لە نوێکردنەوەی دۆخ.' });
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    try {
      await AdminApi.deleteFeedback(deleteTarget.id);
      setFeedbacks((prev) => prev.filter((f) => f.id !== deleteTarget.id));
      setDeleteTarget(null);
      if (selectedFeedback?.id === deleteTarget.id) {
        setSelectedFeedback(null);
      }
      setToast({ type: 'success', message: 'پێشنیارەکە بە سەرکەوتوویی سڕایەوە.' });
    } catch (e) {
      setToast({ type: 'error', message: 'کێشەیەک ڕوویدا لە سڕینەوە.' });
    }
  };

  const handleSendReply = async () => {
    if (!replyText.trim() || !selectedFeedback) return;
    setIsSendingReply(true);
    try {
      if (selectedFeedback.user_id) {
        await AdminApi.createNotification({
          user_id: selectedFeedback.user_id,
          title: '📬 وەڵامی پێشنیارەکەت لە تیمی ZankoAI',
          body: replyText.trim(),
          type: 'announcement',
        });
      }
      // Auto mark as reviewed
      await handleStatusChange(selectedFeedback.id, 'reviewed');
      setToast({
        type: 'success',
        message: `وەڵام بە سەرکەوتوویی بۆ قوتابی (${selectedFeedback.userName}) نێردرا.`,
      });
      setReplyText('');
      setSelectedFeedback(null);
    } catch (e) {
      setToast({ type: 'error', message: 'کێشەیەک لە ناردنی وەڵام ڕوویدا.' });
    } finally {
      setIsSendingReply(false);
    }
  };

  const getCategoryBadge = (category) => {
    switch (category) {
      case 'داواکاری تایبەتمەندی':
        return (
          <Badge variant="purple" className="gap-1">
            <Sparkles className="w-3 h-3 text-purple-300" />
            <span>تایبەتمەندی نوێ</span>
          </Badge>
        );
      case 'ڕاپۆرتی کێشە':
        return (
          <Badge variant="danger" className="gap-1">
            <Bug className="w-3 h-3 text-red-300" />
            <span>ڕاپۆرتی کێشە</span>
          </Badge>
        );
      case 'پێشنیاری دیزاین':
        return (
          <Badge variant="warning" className="gap-1">
            <Palette className="w-3 h-3 text-amber-300" />
            <span>دیزاین و شێواز</span>
          </Badge>
        );
      default:
        return (
          <Badge variant="primary" className="gap-1">
            <MessageCircle className="w-3 h-3 text-blue-300" />
            <span>{category || 'ڕای گشتی'}</span>
          </Badge>
        );
    }
  };

  const getStatusBadge = (status) => {
    switch (status) {
      case 'resolved':
        return <Badge variant="success">چارەسەرکراو</Badge>;
      case 'reviewed':
        return <Badge variant="primary">پێداچوونەوەکراو</Badge>;
      default:
        return <Badge variant="purple">نوێ</Badge>;
    }
  };

  const renderStars = (rating) => {
    return (
      <div className="flex items-center gap-0.5 text-amber-400">
        {[1, 2, 3, 4, 5].map((s) => (
          <Star
            key={s}
            className={`w-3.5 h-3.5 ${
              s <= rating ? 'fill-amber-400 text-amber-400' : 'text-slate-600'
            }`}
          />
        ))}
      </div>
    );
  };

  const columns = [
    {
      key: 'user',
      label: 'خوێندکار / بەکارهێنەر',
      render: (_, f) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-brand-600 to-indigo-600 flex items-center justify-center font-bold text-sm text-white shadow-sm">
            {f.userName?.[0] || 'U'}
          </div>
          <div>
            <p className="font-semibold text-white text-sm">{f.userName || 'بێ ناو'}</p>
            <p className="text-xs text-slate-400 font-mono">{f.userEmail || '—'}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'category',
      label: 'جۆری پێشنیار',
      render: (cat) => getCategoryBadge(cat),
    },
    {
      key: 'rating',
      label: 'هەڵسەنگاندن',
      render: (r) => renderStars(r),
    },
    {
      key: 'message',
      label: 'ناوەڕۆکی پێشنیار',
      render: (msg) => (
        <p className="text-xs text-slate-300 max-w-xs md:max-w-md line-clamp-2 leading-relaxed">
          {msg || '—'}
        </p>
      ),
    },
    {
      key: 'status',
      label: 'دۆخ',
      render: (s) => getStatusBadge(s),
    },
    {
      key: 'created_at',
      label: 'بەروار و کات',
      render: (date) => (
        <span className="text-xs text-slate-400 font-mono">
          {date ? new Date(date).toLocaleDateString('ku-IQ', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—'}
        </span>
      ),
    },
    {
      key: 'actions',
      label: 'کردارەکان',
      className: 'text-left',
      render: (_, f) => (
        <div className="flex items-center gap-1.5 justify-end">
          <button
            onClick={() => setSelectedFeedback(f)}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            title="بینینی وردەکاری و وەڵامدانەوە"
          >
            <Eye className="w-4 h-4 text-brand-400" />
          </button>
          <button
            onClick={() => setDeleteTarget(f)}
            className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-800 transition-colors"
            title="سڕینەوە"
          >
            <Trash2 className="w-4 h-4 text-red-400" />
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      {/* ─── Header & Live Metrics ─── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-brand-500/10 text-brand-400 border border-brand-500/20">
              <MessageSquareHeart className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white tracking-tight">
                ڕا و پێشنیارەکانی قوتابیان (User Feedback)
              </h1>
              <p className="text-xs text-slate-400 mt-0.5">
                تەواوی ئەو ڕا، پێشنیار، و هەڵسەنگاندنانەی قوتابیان لە ناو مۆبایلەوە دەیپێشنێرن بۆ تیمی گەشەپێدەر
              </p>
            </div>
          </div>
        </div>
        <button
          onClick={fetchFeedback}
          disabled={loading}
          className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-800 text-sm font-medium text-slate-300 hover:text-white hover:bg-slate-800 transition-all self-start sm:self-auto"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-brand-400' : ''}`} />
          <span>نوێکردنەوەی لیست</span>
        </button>
      </div>

      {/* ─── Metric Cards ─── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3.5">
        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800/80 shadow-sm flex items-center gap-3.5">
          <div className="p-3 rounded-xl bg-brand-500/15 text-brand-400 border border-brand-500/20">
            <MessageSquareHeart className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400 font-medium">کۆی پێشنیارەکان</p>
            <p className="text-xl font-bold text-white mt-0.5">{stats.total}</p>
          </div>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800/80 shadow-sm flex items-center gap-3.5">
          <div className="p-3 rounded-xl bg-amber-500/15 text-amber-400 border border-amber-500/20">
            <Star className="w-5 h-5 fill-amber-400" />
          </div>
          <div>
            <p className="text-xs text-slate-400 font-medium">تێکڕای هەڵسەنگاندن</p>
            <p className="text-xl font-bold text-white mt-0.5 flex items-center gap-1">
              <span>{stats.averageRating}</span>
              <span className="text-xs font-normal text-slate-500">/ 5.0</span>
            </p>
          </div>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800/80 shadow-sm flex items-center gap-3.5">
          <div className="p-3 rounded-xl bg-red-500/15 text-red-400 border border-red-500/20">
            <Bug className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400 font-medium">ڕاپۆرتی کێشە</p>
            <p className="text-xl font-bold text-white mt-0.5">{stats.bugsCount}</p>
          </div>
        </div>

        <div className="p-4 rounded-2xl bg-slate-900/90 border border-slate-800/80 shadow-sm flex items-center gap-3.5">
          <div className="p-3 rounded-xl bg-purple-500/15 text-purple-400 border border-purple-500/20">
            <Sparkles className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400 font-medium">داواکاری تایبەتمەندی</p>
            <p className="text-xl font-bold text-white mt-0.5">{stats.featuresCount}</p>
          </div>
        </div>
      </div>

      {/* ─── Filters & Search ─── */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-3">
        <div className="relative sm:col-span-1">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="گەڕان بەپێی خوێندکار یان دەق..."
            className="w-full pl-4 pr-10 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500"
          />
          <Search className="w-4 h-4 text-slate-400 absolute right-3.5 top-3" />
        </div>

        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="all">هەموو جۆرەکان</option>
          <option value="داواکاری تایبەتمەندی">داواکاری تایبەتمەندی</option>
          <option value="ڕاپۆرتی کێشە">ڕاپۆرتی کێشە</option>
          <option value="پێشنیاری دیزاین">پێشنیاری دیزاین</option>
          <option value="ڕای گشتی">ڕای گشتی</option>
        </select>

        <select
          value={ratingFilter}
          onChange={(e) => setRatingFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="all">هەموو ئەستێرەکان</option>
          <option value="5">⭐⭐⭐⭐⭐ (٥ ئەستێرە)</option>
          <option value="4">⭐⭐⭐⭐ (٤ ئەستێرە)</option>
          <option value="3">⭐⭐⭐ (٣ ئەستێرە)</option>
          <option value="2">⭐⭐ (٢ ئەستێرە)</option>
          <option value="1">⭐ (١ ئەستێرە)</option>
        </select>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="all">هەموو دۆخەکان</option>
          <option value="new">نوێ (New)</option>
          <option value="reviewed">پێداچوونەوەکراو (Reviewed)</option>
          <option value="resolved">چارەسەرکراو (Resolved)</option>
        </select>
      </div>

      {/* ─── DataTable ─── */}
      <DataTable
        columns={columns}
        data={feedbacks}
        loading={loading}
        emptyMessage="هیچ ڕا و پێشنیارێک بەپێی ئەم فلتەرانە نەدۆزرایەوە."
      />

      {/* ─── View & Reply Modal ─── */}
      {selectedFeedback && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-xl overflow-hidden shadow-2xl">
            <div className="p-6 border-b border-slate-800 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-brand-600/20 text-brand-400 border border-brand-500/30 flex items-center justify-center font-bold">
                  {selectedFeedback.userName?.[0] || 'U'}
                </div>
                <div>
                  <h3 className="text-base font-bold text-white">{selectedFeedback.userName}</h3>
                  <p className="text-xs text-slate-400 font-mono">{selectedFeedback.userEmail || 'بێ ئیمەیڵ'}</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {getCategoryBadge(selectedFeedback.category)}
              </div>
            </div>

            <div className="p-6 space-y-5">
              {/* Star Rating & Status Row */}
              <div className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/60 border border-slate-800/80">
                <div>
                  <span className="text-xs text-slate-400 block mb-1">هەڵسەنگاندنی قوتابی:</span>
                  <div className="flex items-center gap-2">
                    {renderStars(selectedFeedback.rating)}
                    <span className="text-xs font-bold text-amber-400">({selectedFeedback.rating} لە ٥)</span>
                  </div>
                </div>

                <div>
                  <span className="text-xs text-slate-400 block mb-1">دۆخی پێشنیار:</span>
                  <select
                    value={selectedFeedback.status || 'new'}
                    onChange={(e) => handleStatusChange(selectedFeedback.id, e.target.value)}
                    className="px-2.5 py-1 rounded-lg bg-slate-900 border border-slate-700 text-xs font-semibold text-white focus:outline-none focus:border-brand-500"
                  >
                    <option value="new">نوێ</option>
                    <option value="reviewed">پێداچوونەوەکراو</option>
                    <option value="resolved">چارەسەرکراو</option>
                  </select>
                </div>
              </div>

              {/* Message Content */}
              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-2">
                  دەقی پەیام و پێشنیاری نێردراو:
                </label>
                <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 text-sm text-slate-200 leading-relaxed">
                  {selectedFeedback.message}
                </div>
                <span className="text-[11px] text-slate-500 font-mono mt-1.5 block text-left">
                  نێردراوە لە: {new Date(selectedFeedback.created_at).toLocaleString('ku-IQ')}
                </span>
              </div>

              {/* Direct Reply Section */}
              <div className="pt-2 border-t border-slate-800">
                <label className="text-xs font-semibold text-brand-300 flex items-center gap-1.5 mb-2">
                  <Send className="w-3.5 h-3.5" />
                  <span>وەڵامدانەوەی ڕاستەوخۆ (ناردنی ئاگاداری بۆ ناو مۆبایلی قوتابیەکە):</span>
                </label>
                <textarea
                  rows={3}
                  value={replyText}
                  onChange={(e) => setReplyText(e.target.value)}
                  placeholder="سوپاس بۆ پێشنیارەکەت، داواکارییەکەت خرایە بەردەست تیمی پەرەپێدان..."
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500"
                />
              </div>
            </div>

            {/* Modal Actions */}
            <div className="p-4 border-t border-slate-800 bg-slate-950/40 flex items-center justify-between">
              <button
                onClick={() => setSelectedFeedback(null)}
                className="px-4 py-2 rounded-xl text-xs font-medium text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
              >
                داخستن
              </button>

              <div className="flex items-center gap-2">
                <button
                  onClick={handleSendReply}
                  disabled={!replyText.trim() || isSendingReply}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-brand-600 hover:bg-brand-500 text-xs font-bold text-white transition-colors disabled:opacity-50"
                >
                  <Send className="w-3.5 h-3.5" />
                  <span>{isSendingReply ? 'دەخرێتە ناردن...' : 'ناردنی وەڵام'}</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ─── Delete Confirmation Modal ─── */}
      {deleteTarget && (
        <ConfirmModal
          isOpen={true}
          title="سڕینەوەی پێشنیار"
          message={`ئایا دڵنیایت دەتەوێت پێشنیاری نێردراوی "${deleteTarget.userName}" بسڕیتەوە؟ ئەم کردارە ناگەڕێتەوە.`}
          confirmLabel="بەڵێ، بسڕەوە"
          cancelLabel="پاشگەزبوونەوە"
          variant="danger"
          onConfirm={handleDelete}
          onCancel={() => setDeleteTarget(null)}
        />
      )}

      {/* ─── Toast Feedback ─── */}
      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
