import React, { useState, useEffect } from 'react';
import { Plus, Edit2, Archive, BookOpen, User, Eye, AlertCircle } from 'lucide-react';
import { AdminApi } from '../services/api';
import DataTable from '../components/DataTable';
import Badge from '../components/Badge';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';

export default function Courses() {
  const [courses, setCourses] = useState([]);
  const [departments, setDepartments] = useState([]);
  const [selectedDeptFilter, setSelectedDeptFilter] = useState('');
  const [loading, setLoading] = useState(true);

  // Modals
  const [editModal, setEditModal] = useState(false);
  const [archiveModal, setArchiveModal] = useState(false);
  const [detailModal, setDetailModal] = useState(false);
  const [selectedCourse, setSelectedCourse] = useState(null);
  const [courseDetail, setCourseDetail] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const [form, setForm] = useState({
    title: '',
    code: '',
    department_id: '',
    instructor_id: '',
    description: '',
    stage: 1,
    semester: 1,
    credits: 3,
  });

  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState(null);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [crsData, deptData] = await Promise.all([
        AdminApi.listCourses(selectedDeptFilter || undefined),
        AdminApi.listDepartments(),
      ]);
      setCourses(crsData || []);
      setDepartments(deptData || []);
    } catch (err) {
      console.error('Failed to load courses:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی کۆرسەکان.' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [selectedDeptFilter]);

  const handleOpenCreate = () => {
    setSelectedCourse(null);
    setForm({
      title: '',
      code: '',
      department_id: departments[0]?.id || '',
      instructor_id: teachers[0]?.id || '',
      description: '',
      stage: 1,
      semester: 1,
      credits: 3,
    });
    setEditModal(true);
  };

  const handleOpenEdit = (c) => {
    setSelectedCourse(c);
    setForm({
      title: c.title,
      code: c.code,
      department_id: c.department_id,
      instructor_id: c.instructor_id || '',
      description: c.description || '',
      stage: c.stage || 1,
      semester: c.semester || 1,
      credits: c.credits || 3,
    });
    setEditModal(true);
  };

  const handleViewDetail = async (c) => {
    setSelectedCourse(c);
    setDetailModal(true);
    setDetailLoading(true);
    try {
      const res = await AdminApi.getCourseDetail(c.id);
      setCourseDetail(res);
    } catch (err) {
      console.error('Failed to load course details:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی وردەکاری کۆرس.' });
    } finally {
      setDetailLoading(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!form.title || !form.code || !form.department_id) {
      setToast({ type: 'error', message: 'تکایە ناوی کۆرس، کۆد و بەش پڕبکەرەوە.' });
      return;
    }

    setActionLoading(true);
    try {
      if (selectedCourse) {
        await AdminApi.updateCourse(selectedCourse.id, form);
        setToast({ type: 'success', message: 'کۆرس نوێکرایەوە.' });
      } else {
        await AdminApi.createCourse(form);
        setToast({ type: 'success', message: 'کۆرسی نوێ بە سەرکەوتوویی دروستکرا.' });
      }
      setEditModal(false);
      fetchData();
    } catch (err) {
      setToast({ type: 'error', message: err.response?.data?.message || 'هەڵە لە پاشەکەوتکردن.' });
    } finally {
      setActionLoading(false);
    }
  };

  const handleArchive = async () => {
    if (!selectedCourse) return;
    setActionLoading(true);
    try {
      await AdminApi.archiveCourse(selectedCourse.id);
      setToast({ type: 'success', message: 'کۆرسەکە ئەرشیڤ کرا.' });
      setArchiveModal(false);
      fetchData();
    } catch (err) {
      setToast({ type: 'error', message: err.response?.data?.message || 'هەڵە لە ئەرشیڤکردن.' });
    } finally {
      setActionLoading(false);
    }
  };

  const deptNameMap = departments.reduce((acc, d) => {
    acc[d.id] = d.name;
    return acc;
  }, {});

  const columns = [
    {
      key: 'title',
      label: 'ناوی کۆرس',
      render: (title, c) => (
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-purple-950/60 border border-purple-800/40 text-purple-400">
            <BookOpen className="w-5 h-5" />
          </div>
          <div>
            <p className="font-semibold text-white">{title}</p>
            <span className="font-mono text-xs text-slate-400">{c.code}</span>
          </div>
        </div>
      ),
    },
    {
      key: 'department_id',
      label: 'بەشی زانستی',
      render: (deptId) => <span className="text-slate-300">{deptNameMap[deptId] || 'بەش'}</span>,
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
      render: (_, c) => (
        <div className="flex items-center justify-end gap-2">
          <button
            onClick={() => handleViewDetail(c)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
            title="بینینی ئەندامان و وانەکان"
          >
            <Eye className="w-4 h-4" />
          </button>
          <button
            onClick={() => handleOpenEdit(c)}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
            title="دەستکاری"
          >
            <Edit2 className="w-4 h-4" />
          </button>
          <button
            onClick={() => {
              setSelectedCourse(c);
              setArchiveModal(true);
            }}
            className="p-1.5 rounded-lg bg-rose-950/60 hover:bg-rose-900 text-rose-400 border border-rose-800/40 transition-colors"
            title="ئەرشیڤکردن"
          >
            <Archive className="w-4 h-4" />
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی کۆرسەکان</h1>
          <p className="text-xs text-slate-400 mt-1">
            دروستکردن، دەستکاری، دیاریکردنی مامۆستا و ئەرشیڤکردنی کۆرسە ئەکادیمییەکان
          </p>
        </div>

        <button
          onClick={handleOpenCreate}
          className="px-4 py-2.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-semibold text-xs flex items-center gap-2 shadow-lg shadow-brand-900/30 transition-all"
        >
          <Plus className="w-4 h-4" />
          <span>زیادکردنی کۆرس</span>
        </button>
      </div>

      <div className="flex items-center gap-3">
        <select
          value={selectedDeptFilter}
          onChange={(e) => setSelectedDeptFilter(e.target.value)}
          className="w-full sm:w-64 px-3 py-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-sm text-slate-300 focus:outline-none focus:border-brand-500"
        >
          <option value="">هەموو بەشەکان</option>
          {departments.map((d) => (
            <option key={d.id} value={d.id}>
              {d.name}
            </option>
          ))}
        </select>
      </div>

      <DataTable
        columns={columns}
        data={courses}
        loading={loading}
        emptyMessage="هیچ کۆرسێک نەدۆزرایەوە."
      />

      {/* ─── Create/Edit Modal ─── */}
      <ConfirmModal
        isOpen={editModal}
        title={selectedCourse ? 'دەستکاریکردنی کۆرس' : 'زیادکردنی کۆرسی نوێ'}
        confirmText="پاشەکەوتکردن"
        danger={false}
        loading={actionLoading}
        onConfirm={handleSave}
        onCancel={() => setEditModal(false)}
      >
        <div className="space-y-3">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">ناوی کۆرس:</label>
            <input
              type="text"
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              placeholder="بۆ نموونە: داتابەیس و SQL"
              className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1">کۆدی کۆرس:</label>
              <input
                type="text"
                value={form.code}
                onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })}
                placeholder="CS204"
                className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white uppercase focus:outline-none focus:border-brand-500"
                required
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1">بەش:</label>
              <select
                value={form.department_id}
                onChange={(e) => setForm({ ...form, department_id: e.target.value })}
                className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
                required
              >
                <option value="" disabled>بەش هەڵبژێرە</option>
                {departments.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">سەرپەرشتیاری کۆرس (Coordinator):</label>
            <input
              type="text"
              value={form.instructor_id}
              onChange={(e) => setForm({ ...form, instructor_id: e.target.value })}
              placeholder="تیمی ئەکادیمی ZankoAI"
              className="w-full px-3.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white focus:outline-none focus:border-brand-500"
            />
          </div>
        </div>
      </ConfirmModal>

      {/* ─── Archive Modal ─── */}
      <ConfirmModal
        isOpen={archiveModal}
        title="ئەرشیڤکردنی کۆرس"
        message={`ئایا دڵنیایت لە ئەرشیڤکردنی کۆرسی ${selectedCourse?.title}؟ کۆرسەکە لە پیشاندان دەشاردرێتەوە بەڵام داتاکانی پارێزراو دەبن.`}
        confirmText="ئەرشیڤکردن"
        danger={true}
        loading={actionLoading}
        onConfirm={handleArchive}
        onCancel={() => setArchiveModal(false)}
      />

      {/* ─── Detail Modal (Members, Lectures, Quizzes) ─── */}
      <ConfirmModal
        isOpen={detailModal}
        title={`وردەکاری کۆرسی: ${selectedCourse?.title || ''}`}
        confirmText="داخستن"
        cancelText=""
        danger={false}
        loading={detailLoading}
        onConfirm={() => setDetailModal(false)}
        onCancel={() => setDetailModal(false)}
      >
        {detailLoading ? (
          <div className="py-8 flex justify-center">
            <LoadingSpinner size="md" />
          </div>
        ) : (
          <div className="space-y-4 text-xs">
            <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-1.5">
              <p className="text-slate-300">مامۆستا: <span className="font-semibold text-white">{courseDetail?.course?.profiles?.full_name || 'دیارینەکراوە'}</span></p>
              <p className="text-slate-300">بەش: <span className="font-semibold text-white">{courseDetail?.course?.departments?.name || 'دیارینەکراوە'}</span></p>
            </div>

            <div className="grid grid-cols-3 gap-2 text-center">
              <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                <span className="text-slate-500 block text-[10px]">ئەندامان</span>
                <span className="font-bold text-white text-sm">{courseDetail?.members?.length || 0}</span>
              </div>
              <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                <span className="text-slate-500 block text-[10px]">وانەکان</span>
                <span className="font-bold text-white text-sm">{courseDetail?.lectures?.length || 0}</span>
              </div>
              <div className="p-2.5 rounded-xl bg-slate-900 border border-slate-800">
                <span className="text-slate-500 block text-[10px]">تاقیکردنەوەکان</span>
                <span className="font-bold text-white text-sm">{courseDetail?.quizzes?.length || 0}</span>
              </div>
            </div>
          </div>
        )}
      </ConfirmModal>

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
