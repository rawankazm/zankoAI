import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  User,
  Mail,
  Calendar,
  Building2,
  Library,
  Layers,
  Crown,
  CreditCard,
  BookOpen,
  Bot,
  ArrowRight,
  Shield,
  Clock,
  UserCheck,
  UserX,
  AlertCircle,
} from 'lucide-react';
import { AdminApi } from '../services/api';
import Badge from '../components/Badge';
import LoadingSpinner from '../components/LoadingSpinner';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function UserDetail() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [toast, setToast] = useState(null);

  // Modals
  const [suspendModal, setSuspendModal] = useState(false);
  const [suspendReason, setSuspendReason] = useState('');
  const [actionLoading, setActionLoading] = useState(false);

  const fetchDetail = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await AdminApi.getUserDetail(id);
      setData(res);
    } catch (err) {
      console.error('Failed to load user detail:', err);
      setError('هەڵە لە بارکردنی زانیارییەکانی بەکارهێنەر.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDetail();
  }, [id]);

  const handleToggleStatus = async () => {
    if (!data?.profile) return;
    setActionLoading(true);
    const newStatus = data.profile.status === 'active' ? 'suspended' : 'active';
    setData(prev => ({
      ...prev,
      profile: { ...prev.profile, status: newStatus },
      status: newStatus,
    }));
    try {
      await AdminApi.updateUserStatus(id, newStatus, suspendReason || 'گۆڕینی دۆخ لە پەڕەی وردەکاری');
      setToast({
        type: 'success',
        message: `دۆخی هەژمارەکە گۆڕدرا بۆ ${newStatus === 'active' ? 'چالاک' : 'سڕکراو'}.`,
      });
      setSuspendModal(false);
      setSuspendReason('');
      fetchDetail();
    } catch (err) {
      setToast({ type: 'error', message: err.response?.data?.message || 'هەڵە لە گۆڕینی دۆخ.' });
    } finally {
      setActionLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="py-24 flex flex-col items-center justify-center gap-4">
        <LoadingSpinner size="lg" />
        <p className="text-sm text-slate-400">بارکردنی پەڕەی وردەکاری بەکارهێنەر...</p>
      </div>
    );
  }

  if (error || !data?.profile) {
    return (
      <div className="py-16 text-center space-y-4">
        <div className="w-12 h-12 rounded-2xl bg-rose-500/10 text-rose-400 border border-rose-500/20 mx-auto flex items-center justify-center">
          <AlertCircle className="w-6 h-6" />
        </div>
        <h3 className="text-lg font-bold text-white">{error || 'بەکارهێنەر نەدۆزرایەوە.'}</h3>
        <button
          onClick={() => navigate('/users')}
          className="px-4 py-2 rounded-xl bg-slate-800 text-slate-200 text-xs hover:bg-slate-700"
        >
          گەڕانەوە بۆ لیستی بەکارهێنەران
        </button>
      </div>
    );
  }

  const { profile, subscriptions, payments, courses, recentAiActivity } = data;

  return (
    <div className="space-y-8 animate-fade-in">
      {/* ─── Breadcrumb & Top Bar ─── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate('/users')}
            className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
            title="گەڕانەوە"
          >
            <ArrowRight className="w-4 h-4" />
          </button>
          <div>
            <h1 className="text-2xl font-bold text-white tracking-tight">
              {profile.full_name || 'بەکارهێنەر'}
            </h1>
            <p className="text-xs text-slate-400 font-mono mt-0.5">{profile.email}</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {profile.status === 'active' ? (
            <button
              onClick={() => setSuspendModal(true)}
              className="px-4 py-2 rounded-xl bg-rose-950/60 hover:bg-rose-900 text-rose-400 border border-rose-800/40 text-xs font-semibold flex items-center gap-2 transition-all"
            >
              <UserX className="w-4 h-4" />
              <span>سڕکردنی هەژمار</span>
            </button>
          ) : (
            <button
              onClick={() => setSuspendModal(true)}
              className="px-4 py-2 rounded-xl bg-emerald-950/60 hover:bg-emerald-900 text-emerald-400 border border-emerald-800/40 text-xs font-semibold flex items-center gap-2 transition-all"
            >
              <UserCheck className="w-4 h-4" />
              <span>چالاککردنەوەی هەژمار</span>
            </button>
          )}
        </div>
      </div>

      {/* ─── Main Overview Card ─── */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Profile Card */}
        <div className="glass-card rounded-2xl p-6 border border-slate-800 space-y-4">
          <h3 className="text-sm font-bold text-white border-b border-slate-800 pb-3">
            زانیاری سەرەکی پرۆفایل
          </h3>

          <div className="space-y-3 text-xs">
            <div className="flex justify-between items-center text-slate-300">
              <span className="text-slate-500">ڕۆڵ:</span>
              <Badge variant={profile.role === 'admin' ? 'warning' : 'default'}>
                {profile.role === 'admin' ? 'ئەدمین' : 'خوێندکار'}
              </Badge>
            </div>

            <div className="flex justify-between items-center text-slate-300">
              <span className="text-slate-500">پلان:</span>
              <Badge variant={profile.plan === 'premium' || profile.is_vip ? 'success' : 'default'}>
                {profile.plan === 'premium' || profile.is_vip ? 'پریمیۆم (VIP)' : 'بەخۆڕایی (Free)'}
              </Badge>
            </div>

            <div className="flex justify-between items-center text-slate-300">
              <span className="text-slate-500">دۆخ:</span>
              <Badge variant={profile.status === 'active' ? 'success' : 'danger'}>
                {profile.status === 'active' ? 'چالاک' : 'سڕکراو'}
              </Badge>
            </div>

            <div className="flex justify-between items-center text-slate-300">
              <span className="text-slate-500">ناسنامەی داتابەیس:</span>
              <span className="font-mono text-[11px] text-slate-400">{profile.id}</span>
            </div>

            <div className="flex justify-between items-center text-slate-300">
              <span className="text-slate-500">بەرواری بەشداربوون:</span>
              <span>{new Date(profile.created_at).toLocaleDateString('ku-IQ')}</span>
            </div>
          </div>
        </div>

        {/* Academic Affiliation Card */}
        <div className="glass-card rounded-2xl p-6 border border-slate-800 space-y-4">
          <h3 className="text-sm font-bold text-white border-b border-slate-800 pb-3">
            پێکهاتەی ئەکادیمی خوێندن
          </h3>

          <div className="space-y-3 text-xs">
            <div className="flex items-center gap-2.5 text-slate-300">
              <Building2 className="w-4 h-4 text-brand-400 shrink-0" />
              <div>
                <span className="text-slate-500 block text-[11px]">زانکۆ</span>
                <span className="font-semibold text-white">{profile.university_name || 'دیارینەکراوە'}</span>
              </div>
            </div>

            <div className="flex items-center gap-2.5 text-slate-300">
              <Library className="w-4 h-4 text-brand-400 shrink-0" />
              <div>
                <span className="text-slate-500 block text-[11px]">کۆلێژ / فاکەڵتی</span>
                <span className="font-semibold text-white">{profile.faculty_name || 'دیارینەکراوە'}</span>
              </div>
            </div>

            <div className="flex items-center gap-2.5 text-slate-300">
              <Layers className="w-4 h-4 text-brand-400 shrink-0" />
              <div>
                <span className="text-slate-500 block text-[11px]">بەشی زانستی</span>
                <span className="font-semibold text-white">{profile.department_name || 'دیارینەکراوە'}</span>
              </div>
            </div>
          </div>
        </div>

        {/* VIP Status Card */}
        <div className="glass-card rounded-2xl p-6 border border-slate-800 space-y-4">
          <h3 className="text-sm font-bold text-white border-b border-slate-800 pb-3 flex items-center justify-between">
            <span>دۆخی بەشداریکردنی VIP</span>
            <Crown className="w-4 h-4 text-amber-400" />
          </h3>

          <div className="space-y-3 text-xs">
            <div className="flex justify-between items-center text-slate-300">
              <span className="text-slate-500">دۆخی تایبەت:</span>
              <span className="font-semibold text-white">{profile.vip_status || 'هیچ'}</span>
            </div>

            <div className="flex justify-between items-center text-slate-300">
              <span className="text-slate-500">بەسەرچوونی VIP:</span>
              <span>{profile.vip_expiry ? new Date(profile.vip_expiry).toLocaleDateString('ku-IQ') : 'دیارینەکراوە'}</span>
            </div>

            <div className="flex justify-between items-center text-slate-300">
              <span className="text-slate-500">کۆی بەشداریکردنەکان:</span>
              <span className="font-bold text-brand-400">{subscriptions.length} جار</span>
            </div>
          </div>
        </div>
      </div>

      {/* ─── Tabs / Related Lists ─── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Enrolled/Taught Courses */}
        <div className="glass-card rounded-2xl p-6 border border-slate-800">
          <div className="flex items-center justify-between mb-4 border-b border-slate-800 pb-3">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <BookOpen className="w-4 h-4 text-brand-400" />
              <span>کۆرسە بەشداربووەکان</span>
            </h3>
            <Badge variant="default">{courses.length} کۆرس</Badge>
          </div>

          <div className="space-y-2 max-h-60 overflow-y-auto">
            {courses.length === 0 ? (
              <p className="text-xs text-slate-500 text-center py-6">هیچ کۆرسێک تۆمار نەکراوە.</p>
            ) : (
              courses.map((c) => {
                const courseInfo = c.courses || c;
                return (
                  <div key={c.id} className="p-3 rounded-xl bg-slate-900/60 border border-slate-800 flex justify-between items-center text-xs">
                    <div>
                      <p className="font-semibold text-slate-200">{courseInfo.title}</p>
                      <span className="text-slate-500 font-mono text-[10px]">{courseInfo.code}</span>
                    </div>
                    <span className="text-slate-400 text-[11px]">{new Date(c.created_at).toLocaleDateString('ku-IQ')}</span>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Recent AI Telemetry */}
        <div className="glass-card rounded-2xl p-6 border border-slate-800">
          <div className="flex items-center justify-between mb-4 border-b border-slate-800 pb-3">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <Bot className="w-4 h-4 text-purple-400" />
              <span>چالاکییەکانی هۆشی دەستکرد (AI)</span>
            </h3>
            <Badge variant="purple">{recentAiActivity.length} داواکاری کۆتایی</Badge>
          </div>

          <div className="space-y-2 max-h-60 overflow-y-auto">
            {recentAiActivity.length === 0 ? (
              <p className="text-xs text-slate-500 text-center py-6">هیچ چالاکییەکی AI تۆمار نەکراوە لەم دواییەدا.</p>
            ) : (
              recentAiActivity.map((a, idx) => (
                <div key={idx} className="p-3 rounded-xl bg-slate-900/60 border border-slate-800 flex justify-between items-center text-xs">
                  <div>
                    <span className="font-semibold text-slate-200 uppercase tracking-wide text-[11px]">{a.feature || 'چات'}</span>
                    <p className="text-slate-500 text-[10px]">{(a.input_tokens || 0) + (a.output_tokens || 0)} تۆکن</p>
                  </div>
                  <div className="text-left">
                    <span className="text-purple-400 font-mono font-medium">${a.estimated_cost || '0.000'}</span>
                    <span className="block text-slate-500 text-[10px]">{new Date(a.created_at).toLocaleDateString('ku-IQ')}</span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* ─── Payments & Subscriptions Tables ─── */}
      <div className="glass-card rounded-2xl p-6 border border-slate-800">
        <h3 className="text-sm font-bold text-white border-b border-slate-800 pb-3 mb-4 flex items-center gap-2">
          <CreditCard className="w-4 h-4 text-emerald-400" />
          <span>مێژووی پارەدان و بەشداریکردن</span>
        </h3>

        <div className="overflow-x-auto">
          <table className="w-full text-right text-xs">
            <thead className="text-slate-500 border-b border-slate-800 pb-2">
              <tr>
                <th className="py-2 px-3">ناسنامەی داواکاری</th>
                <th className="py-2 px-3">دەروازە</th>
                <th className="py-2 px-3">بڕ</th>
                <th className="py-2 px-3">دۆخ</th>
                <th className="py-2 px-3">بەروار</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {payments.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-6 text-center text-slate-500">هیچ مامەڵەیەکی پارەدان نەدۆزرایەوە.</td>
                </tr>
              ) : (
                payments.map((p) => (
                  <tr key={p.id}>
                    <td className="py-3 px-3 font-mono text-slate-400">{p.order_id || p.id.substring(0, 8)}</td>
                    <td className="py-3 px-3 uppercase text-slate-300 font-semibold">{p.provider}</td>
                    <td className="py-3 px-3 font-bold text-white">{Number(p.amount).toLocaleString()} {p.currency || 'IQD'}</td>
                    <td className="py-3 px-3">
                      <Badge variant={p.status === 'completed' || p.status === 'paid' ? 'success' : 'warning'}>
                        {p.status}
                      </Badge>
                    </td>
                    <td className="py-3 px-3 text-slate-500">{new Date(p.created_at).toLocaleDateString('ku-IQ')}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── Status Toggle Confirmation Modal ─── */}
      <ConfirmModal
        isOpen={suspendModal}
        title={profile.status === 'active' ? 'سڕکردنی هەژمار' : 'چالاککردنەوەی هەژمار'}
        message={`ئایا دڵنیایت لە ${profile.status === 'active' ? 'سڕکردنی' : 'چالاککردنەوەی'} هەژماری ${profile.full_name || profile.email}؟`}
        confirmText={profile.status === 'active' ? 'سڕکردن' : 'چالاککردنەوە'}
        danger={profile.status === 'active'}
        loading={actionLoading}
        onConfirm={handleToggleStatus}
        onCancel={() => setSuspendModal(false)}
      >
        {profile.status === 'active' && (
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              هۆکاری سڕکردن:
            </label>
            <input
              type="text"
              value={suspendReason}
              onChange={(e) => setSuspendReason(e.target.value)}
              placeholder="بۆ نموونە: پێشێلکردنی یاسا"
              className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-rose-500"
            />
          </div>
        )}
      </ConfirmModal>

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
