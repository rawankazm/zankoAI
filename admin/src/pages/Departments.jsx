import React, { useState, useEffect } from 'react';
import { Plus, Edit2, Trash2, Layers } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function Departments() {
  const [departments, setDepartments] = useState([]);
  const [faculties, setFaculties] = useState([]);
  const [selectedFacFilter, setSelectedFacFilter] = useState('');
  const [loading, setLoading] = useState(true);

  const [editModal, setEditModal] = useState(false);
  const [deleteModal, setDeleteModal] = useState(false);
  const [selectedDept, setSelectedDept] = useState(null);
  const [form, setForm] = useState({ name: '', faculty_id: '' });
  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [deptData, facData] = await Promise.all([
        AdminApi.listDepartments(selectedFacFilter || undefined),
        AdminApi.listFaculties(),
      ]);
      setDepartments(deptData || []);
      setFaculties(facData || []);
    } catch (err) {
      console.error('Failed to load departments:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی بەشە زانستییەکان.' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [selectedFacFilter]);

  const handleOpenCreate = () => {
    setSelectedDept(null);
    setForm({ name: '', faculty_id: faculties[0]?.id || '' });
    setEditModal(true);
  };

  const handleOpenEdit = (dept) => {
    setSelectedDept(dept);
    setForm({ name: dept.name, faculty_id: dept.faculty_id });
    setEditModal(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!form.name || !form.faculty_id) {
      setToast({ type: 'error', message: 'تکایە ناوی بەش و کۆلێژ هەڵبژێرە.' });
      return;
    }

    setActionLoading(true);
    try {
      if (selectedDept) {
        await AdminApi.updateDepartment(selectedDept.id, form);
        setToast({ type: 'success', message: 'بەشەکە بە سەرکەوتوویی نوێکرایەوە.' });
      } else {
        await AdminApi.createDepartment(form);
        setToast({ type: 'success', message: 'بەشی نوێ تۆمارکرا.' });
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
    if (!selectedDept) return;
    setActionLoading(true);
    try {
      await AdminApi.deleteDepartment(selectedDept.id);
      setToast({ type: 'success', message: 'بەش سڕایەوە.' });
      setDeleteModal(false);
      fetchData();
    } catch (err) {
      setToast({
        type: 'error',
        message: err.response?.data?.message || 'ناتوانرێت بسڕدرێتەوە بەهۆی بوونی کۆرسی بەستراوە.',
      });
    } finally {
      setActionLoading(false);
    }
  };

  const facNameMap = faculties.reduce((acc, f) => {
    acc[f.id] = f.name;
    return acc;
  }, {});

  const columns = [
    {
      key: 'name',
      label: 'ناوی بەشی زانستی',
      render: (name) => (
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-cyan-950/60 border border-cyan-800/40 text-cyan-400">
            <Layers className="w-5 h-5" />
          </div>
          <span className="font-semibold text-white">{name}</span>
        </div>
      ),
    },
    {
      key: 'faculty_id',
      label: 'کۆلێژ',
      render: (facId) => <span className="text-slate-300">{facNameMap[facId] || 'کۆلێژ'}</span>,
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
      render: (_, d) => (
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={() => handleOpenEdit(d)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
            title="دەستکاری"
          >
            <Edit2 className="w-4 h-4" />
          </button>
          <button
            onClick={() => {
              setSelectedDept(d);
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
          <h1 className="text-2xl font-bold text-white tracking-tight">بەشە زانستییەکان (Departments)</h1>
          <p className="text-xs text-slate-400 mt-1">
            زیادکردن و ڕێکخستنی بەشەکان لەژێر کۆلێژەکاندا
          </p>
        </div>

        <button
          onClick={handleOpenCreate}
          className="px-4 py-2.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-semibold text-xs flex items-center gap-2 shadow-lg shadow-brand-900/30 transition-all"
        >
          <Plus className="w-4 h-4" />
          <span>زیادکردنی بەش</span>
        </button>
      </div>

      <div className="flex items-center gap-3">
        <select
          value={selectedFacFilter}
          onChange={(e) => setSelectedFacFilter(e.target.value)}
          className="w-full sm:w-64 px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو کۆلێژەکان</option>
          {faculties.map((f) => (
            <option key={f.id} value={f.id}>
              {f.name}
            </option>
          ))}
        </select>
      </div>

      <DataTable
        columns={columns}
        data={departments}
        loading={loading}
        emptyMessage="هیچ بەشێکی زانستی نەدۆزرایەوە."
      />

      {/* ─── Create/Edit Modal ─── */}
      <ConfirmModal
        isOpen={editModal}
        title={selectedDept ? 'دەستکاریکردنی بەش' : 'زیادکردنی بەشی زانستی نوێ'}
        confirmText="پاشەکەوتکردن"
        danger={false}
        loading={actionLoading}
        onConfirm={handleSave}
        onCancel={() => setEditModal(false)}
      >
        <div className="space-y-3">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">ناوی بەش:</label>
            <input
              type="text"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="بۆ نموونە: بەشی زانستی کۆمپیوتەر"
              className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
              required
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">کۆلێژی سەرپەرشتیار:</label>
            <select
              value={form.faculty_id}
              onChange={(e) => setForm({ ...form, faculty_id: e.target.value })}
              className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
              required
            >
              <option value="" disabled>کۆلێژ هەڵبژێرە</option>
              {faculties.map((f) => (
                <option key={f.id} value={f.id}>
                  {f.name}
                </option>
              ))}
            </select>
          </div>
        </div>
      </ConfirmModal>

      {/* ─── Delete Modal ─── */}
      <ConfirmModal
        isOpen={deleteModal}
        title="سڕینەوەی بەش"
        message={`ئایا دڵنیایت لە سڕینەوەی ${selectedDept?.name}؟ نابێت هیچ کۆرسێکی پەیوەست مابێت.`}
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
