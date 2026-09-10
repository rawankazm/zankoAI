import React, { useState, useEffect } from 'react';
import { Plus, Edit2, Trash2, Building2, AlertCircle } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function Universities() {
  const [universities, setUniversities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editModal, setEditModal] = useState(false);
  const [deleteModal, setDeleteModal] = useState(false);
  const [selectedUni, setSelectedUni] = useState(null);
  const [form, setForm] = useState({ name: '', code: '', city: 'هەولێر', is_active: true });
  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const fetchUniversities = async () => {
    setLoading(true);
    try {
      const data = await AdminApi.listUniversities();
      setUniversities(data || []);
    } catch (err) {
      console.error('Failed to load universities:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی زانکۆکان.' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUniversities();
  }, []);

  const handleOpenCreate = () => {
    setSelectedUni(null);
    setForm({ name: '', code: '', city: 'هەولێر', is_active: true });
    setEditModal(true);
  };

  const handleOpenEdit = (uni) => {
    setSelectedUni(uni);
    setForm({ name: uni.name, code: uni.code || '', city: uni.city || 'هەولێر', is_active: uni.is_active !== false });
    setEditModal(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!form.name || !form.code) {
      setToast({ type: 'error', message: 'تکایە ناوی زانکۆ و کۆد بنووسە.' });
      return;
    }

    setActionLoading(true);
    try {
      if (selectedUni) {
        await AdminApi.updateUniversity(selectedUni.id, form);
        setToast({ type: 'success', message: 'زانکۆکە بە سەرکەوتوویی نوێکرایەوە.' });
      } else {
        await AdminApi.createUniversity(form);
        setToast({ type: 'success', message: 'زانکۆی نوێ بە سەرکەوتوویی تۆمارکرا.' });
      }
      setEditModal(false);
      fetchUniversities();
    } catch (err) {
      setToast({ type: 'error', message: err.response?.data?.message || 'هەڵە لە پاشەکەوتکردن.' });
    } finally {
      setActionLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!selectedUni) return;
    setActionLoading(true);
    try {
      await AdminApi.deleteUniversity(selectedUni.id);
      setToast({ type: 'success', message: 'زانکۆ بە سەرکەوتوویی سڕایەوە.' });
      setDeleteModal(false);
      fetchUniversities();
    } catch (err) {
      setToast({
        type: 'error',
        message: err.response?.data?.message || 'ناتوانرێت بسڕدرێتەوە بەهۆی بوونی فاکەڵتی بەستراوە.',
      });
    } finally {
      setActionLoading(false);
    }
  };

  const columns = [
    {
      key: 'name',
      label: 'ناوی زانکۆ',
      render: (name, u) => (
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-brand-950/60 border border-brand-800/40 text-brand-400">
            <Building2 className="w-5 h-5" />
          </div>
          <div>
            <p className="font-semibold text-white">{name}</p>
            <p className="text-xs text-slate-400">کۆد: <span className="font-mono text-slate-300">{u.code}</span></p>
          </div>
        </div>
      ),
    },
    {
      key: 'city',
      label: 'شار',
      render: (city) => <span className="text-slate-300">{city || '—'}</span>,
    },
    {
      key: 'is_active',
      label: 'دۆخ',
      render: (active) => (
        <Badge variant={active !== false ? 'success' : 'default'}>
          {active !== false ? 'چالاک' : 'ناچالاک'}
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
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={() => handleOpenEdit(u)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
            title="دەستکاری"
          >
            <Edit2 className="w-4 h-4" />
          </button>
          <button
            onClick={() => {
              setSelectedUni(u);
              setDeleteModal(true);
            }}
            className="p-1.5 rounded-lg bg-rose-950/60 hover:bg-rose-900 text-rose-400 border border-rose-800/40 transition-colors"
            title="سڕینەوە"
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
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی زانکۆکان</h1>
          <p className="text-xs text-slate-400 mt-1">
            دروستکردن، نوێکردنەوە و سڕینەوەی زانکۆکان بە ڕەچاوکردنی پەیوەندییە ئەکادیمییەکان
          </p>
        </div>

        <button
          onClick={handleOpenCreate}
          className="px-4 py-2.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-semibold text-xs flex items-center gap-2 shadow-lg shadow-brand-900/30 transition-all"
        >
          <Plus className="w-4 h-4" />
          <span>زیادکردنی زانکۆ</span>
        </button>
      </div>

      <DataTable
        columns={columns}
        data={universities}
        loading={loading}
        emptyMessage="هیچ زانکۆیەک تۆمار نەکراوە."
      />

      {/* ─── Create/Edit Modal ─── */}
      <ConfirmModal
        isOpen={editModal}
        title={selectedUni ? 'دەستکاریکردنی زانکۆ' : 'زیادکردنی زانکۆی نوێ'}
        message="تکایە زانیارییە پێویستەکان پڕبکەرەوە."
        confirmText="پاشەکەوتکردن"
        danger={false}
        loading={actionLoading}
        onConfirm={handleSave}
        onCancel={() => setEditModal(false)}
      >
        <div className="space-y-3">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">ناوی زانکۆ:</label>
            <input
              type="text"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="بۆ نموونە: زانکۆی سەڵاحەدین"
              className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1">کۆدی زانکۆ:</label>
              <input
                type="text"
                value={form.code}
                onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })}
                placeholder="SUH"
                className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white uppercase focus:outline-none focus:border-brand-500"
                required
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1">شار:</label>
              <input
                type="text"
                value={form.city}
                onChange={(e) => setForm({ ...form, city: e.target.value })}
                placeholder="هەولێر / سلێمانی / دهۆک"
                className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
              />
            </div>
          </div>

          <div className="flex items-center gap-2 pt-2">
            <input
              type="checkbox"
              id="uniActive"
              checked={form.is_active}
              onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
              className="rounded bg-slate-900 border-slate-700 text-brand-600 focus:ring-0"
            />
            <label htmlFor="uniActive" className="text-xs text-slate-300 font-medium">
              زانکۆکە چالاک بێت لە سیستەمدا
            </label>
          </div>
        </div>
      </ConfirmModal>

      {/* ─── Delete Modal ─── */}
      <ConfirmModal
        isOpen={deleteModal}
        title="سڕینەوەی زانکۆ"
        message={`ئایا دڵنیایت لە سڕینەوەی ${selectedUni?.name}؟ سیستەم ڕێگری دەکات ئەگەر فاکەڵتی یان بەش بەستراو بێت بەم زانکۆیەوە.`}
        confirmText="سڕینەوە"
        danger={true}
        loading={actionLoading}
        onConfirm={handleDelete}
        onCancel={() => setDeleteModal(false)}
      />

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
