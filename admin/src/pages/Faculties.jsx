import React, { useState, useEffect } from 'react';
import { Plus, Edit2, Trash2, Library } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function Faculties() {
  const [faculties, setFaculties] = useState([]);
  const [universities, setUniversities] = useState([]);
  const [selectedUniFilter, setSelectedUniFilter] = useState('');
  const [loading, setLoading] = useState(true);

  const [editModal, setEditModal] = useState(false);
  const [deleteModal, setDeleteModal] = useState(false);
  const [selectedFaculty, setSelectedFaculty] = useState(null);
  const [form, setForm] = useState({ name: '', university_id: '' });
  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [facData, uniData] = await Promise.all([
        AdminApi.listFaculties(selectedUniFilter || undefined),
        AdminApi.listUniversities(),
      ]);
      setFaculties(facData || []);
      setUniversities(uniData || []);
    } catch (err) {
      console.error('Failed to load faculties:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی فاکەڵتییەکان.' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [selectedUniFilter]);

  const handleOpenCreate = () => {
    setSelectedFaculty(null);
    setForm({ name: '', university_id: universities[0]?.id || '' });
    setEditModal(true);
  };

  const handleOpenEdit = (fac) => {
    setSelectedFaculty(fac);
    setForm({ name: fac.name, university_id: fac.university_id });
    setEditModal(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!form.name || !form.university_id) {
      setToast({ type: 'error', message: 'تکایە ناوی فاکەڵتی و زانکۆ هەڵبژێرە.' });
      return;
    }

    setActionLoading(true);
    try {
      if (selectedFaculty) {
        await AdminApi.updateFaculty(selectedFaculty.id, form);
        setToast({ type: 'success', message: 'فاکەڵتی بە سەرکەوتوویی نوێکرایەوە.' });
      } else {
        await AdminApi.createFaculty(form);
        setToast({ type: 'success', message: 'فاکەڵتی نوێ تۆمارکرا.' });
      }
      setEditModal(false);
      fetchData();
    } catch (err) {
      setToast({ type: 'error', message: err.response?.data?.message || 'هەڵە لە پاشەکەوتکردن.' });
    } finally {
      setActionLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!selectedFaculty) return;
    setActionLoading(true);
    try {
      await AdminApi.deleteFaculty(selectedFaculty.id);
      setToast({ type: 'success', message: 'فاکەڵتی سڕایەوە.' });
      setDeleteModal(false);
      fetchData();
    } catch (err) {
      setToast({
        type: 'error',
        message: err.response?.data?.message || 'ناتوانرێت بسڕدرێتەوە بەهۆی بوونی بەشی زانستی بەستراوە.',
      });
    } finally {
      setActionLoading(false);
    }
  };

  const uniNameMap = universities.reduce((acc, u) => {
    acc[u.id] = u.name;
    return acc;
  }, {});

  const columns = [
    {
      key: 'name',
      label: 'ناوی فاکەڵتی / کۆلێژ',
      render: (name) => (
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-indigo-950/60 border border-indigo-800/40 text-indigo-400">
            <Library className="w-5 h-5" />
          </div>
          <span className="font-semibold text-white">{name}</span>
        </div>
      ),
    },
    {
      key: 'university_id',
      label: 'زانکۆ',
      render: (uniId) => <span className="text-slate-300">{uniNameMap[uniId] || 'زانکۆ'}</span>,
    },
    {
      key: 'created_at',
      label: 'بەرواری تۆمارکردن',
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
      render: (_, f) => (
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={() => handleOpenEdit(f)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
            title="دەستکاری"
          >
            <Edit2 className="w-4 h-4" />
          </button>
          <button
            onClick={() => {
              setSelectedFaculty(f);
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
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی کۆلێژەکان (Faculties)</h1>
          <p className="text-xs text-slate-400 mt-1">
            زیادکردن و ڕێکخستنی کۆلێژەکان لەژێر زانکۆکاندا
          </p>
        </div>

        <button
          onClick={handleOpenCreate}
          className="px-4 py-2.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-semibold text-xs flex items-center gap-2 shadow-lg shadow-brand-900/30 transition-all"
        >
          <Plus className="w-4 h-4" />
          <span>زیادکردنی کۆلێژ</span>
        </button>
      </div>

      <div className="flex items-center gap-3">
        <select
          value={selectedUniFilter}
          onChange={(e) => setSelectedUniFilter(e.target.value)}
          className="w-full sm:w-64 px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو زانکۆکان</option>
          {universities.map((u) => (
            <option key={u.id} value={u.id}>
              {u.name}
            </option>
          ))}
        </select>
      </div>

      <DataTable
        columns={columns}
        data={faculties}
        loading={loading}
        emptyMessage="هیچ کۆلێژێک نەدۆزرایەوە."
      />

      {/* ─── Create/Edit Modal ─── */}
      <ConfirmModal
        isOpen={editModal}
        title={selectedFaculty ? 'دەستکاریکردنی کۆلێژ' : 'زیادکردنی کۆلێژی نوێ'}
        confirmText="پاشەکەوتکردن"
        danger={false}
        loading={actionLoading}
        onConfirm={handleSave}
        onCancel={() => setEditModal(false)}
      >
        <div className="space-y-3">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">ناوی کۆلێژ:</label>
            <input
              type="text"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="بۆ نموونە: کۆلێژی زانست"
              className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
              required
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">زانکۆی سەرپەرشتیار:</label>
            <select
              value={form.university_id}
              onChange={(e) => setForm({ ...form, university_id: e.target.value })}
              className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
              required
            >
              <option value="" disabled>زانکۆ هەڵبژێرە</option>
              {universities.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.name}
                </option>
              ))}
            </select>
          </div>
        </div>
      </ConfirmModal>

      {/* ─── Delete Modal ─── */}
      <ConfirmModal
        isOpen={deleteModal}
        title="سڕینەوەی کۆلێژ"
        message={`ئایا دڵنیایت لە سڕینەوەی کۆلێژی ${selectedFaculty?.name}؟ نابێت بەشی زانستی بەستراو مابێت.`}
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
