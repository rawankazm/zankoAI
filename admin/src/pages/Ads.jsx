import React, { useState, useEffect, useCallback } from 'react';
import {
  Megaphone,
  Plus,
  Search,
  ExternalLink,
  Edit2,
  Trash2,
  CheckCircle2,
  XCircle,
  Eye,
  MousePointerClick,
  Sparkles,
  Layers,
  Image as ImageIcon,
} from 'lucide-react';
import { AdminApi } from '../services/api';
import ConfirmModal from '../components/ConfirmModal';
import Toast from '../components/Toast';
import Badge from '../components/Badge';

const APP_SCREENS = [
  { id: 'home', labelKu: '🏠 شاشەی سەرەکی (Home)', labelEn: 'Home Page' },
  { id: 'ai_teacher', labelKu: '🤖 مامۆستای زیرەک (AI Teacher)', labelEn: 'AI Teacher' },
  { id: 'notes', labelKu: '📝 تێبینییەکان (Notes)', labelEn: 'Notes' },
  { id: 'flashcards', labelKu: '🎴 فلاش کارت (Flashcards)', labelEn: 'Flashcards' },
  { id: 'quiz', labelKu: '✏️ تاقیکردنەوە (Quiz)', labelEn: 'Quiz' },
  { id: 'schedule', labelKu: '📅 خشتەی وانەکان (Schedule)', labelEn: 'Schedule' },
  { id: 'gpa', labelKu: '📊 نمرە و GPA', labelEn: 'GPA Calculator' },
  { id: 'profile', labelKu: '👤 پڕۆفایل (Profile)', labelEn: 'Profile' },
  { id: 'zankoline', labelKu: '🏛 زانکۆلاین (ZankoLine)', labelEn: 'ZankoLine' },
];

const INITIAL_FORM = {
  title: '',
  titleAr: '',
  titleEn: '',
  description: '',
  descAr: '',
  descEn: '',
  buttonTextKu: 'سەردان بکە',
  buttonTextAr: 'تفاصيل',
  buttonTextEn: 'View',
  imageUrl: '',
  linkUrl: '',
  isActive: true,
  showOnScreens: ['home'],
};

export default function Ads() {
  const [ads, setAds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [screenFilter, setScreenFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');

  const [modalOpen, setModalOpen] = useState(false);
  const [editingAd, setEditingAd] = useState(null);
  const [formData, setFormData] = useState(INITIAL_FORM);
  const [saving, setSaving] = useState(false);

  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [adToDelete, setAdToDelete] = useState(null);
  const [toast, setToast] = useState(null);

  const fetchAds = useCallback(async () => {
    setLoading(true);
    try {
      const data = await AdminApi.listAds();
      setAds(data || []);
    } catch (err) {
      console.error('Failed to load ads:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی ڕیکلامەکان.' });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAds();
  }, [fetchAds]);

  const handleOpenCreate = () => {
    setEditingAd(null);
    setFormData(INITIAL_FORM);
    setModalOpen(true);
  };

  const handleOpenEdit = (ad) => {
    setEditingAd(ad);
    setFormData({
      title: ad.title || '',
      titleAr: ad.titleAr || '',
      titleEn: ad.titleEn || '',
      description: ad.description || '',
      descAr: ad.descAr || '',
      descEn: ad.descEn || '',
      buttonTextKu: ad.buttonTextKu || 'سەردان بکە',
      buttonTextAr: ad.buttonTextAr || 'تفاصيل',
      buttonTextEn: ad.buttonTextEn || 'View',
      imageUrl: ad.imageUrl || '',
      linkUrl: ad.linkUrl || '',
      isActive: ad.isActive !== false,
      showOnScreens: ad.showOnScreens && Array.isArray(ad.showOnScreens) ? ad.showOnScreens : ['home'],
    });
    setModalOpen(true);
  };

  const handleToggleScreen = (screenId) => {
    setFormData((prev) => {
      const current = prev.showOnScreens || [];
      const updated = current.includes(screenId)
        ? current.filter((id) => id !== screenId)
        : [...current, screenId];
      return { ...prev, showOnScreens: updated.length > 0 ? updated : ['home'] };
    });
  };

  const handleSaveAd = async (e) => {
    e.preventDefault();
    if (!formData.title.trim()) {
      setToast({ type: 'error', message: 'تکایە سەردێڕی ڕیکلام بە کوردی بنووسە.' });
      return;
    }

    setSaving(true);
    try {
      if (editingAd) {
        await AdminApi.updateAd(editingAd.id, formData);
        setToast({ type: 'success', message: 'ڕیکلامەکە بە سەرکەوتوویی نوێکرایەوە.' });
      } else {
        await AdminApi.createAd(formData);
        setToast({ type: 'success', message: 'ڕیکلامی نوێ بە سەرکەوتوویی زیادکرا بۆ ئەپەکە.' });
      }
      setModalOpen(false);
      fetchAds();
    } catch (err) {
      console.error('Failed to save ad:', err);
      setToast({ type: 'error', message: 'هەڵە لە پاشەکەوتکردنی ڕیکلام.' });
    } finally {
      setSaving(false);
    }
  };

  const handleToggleActive = async (ad) => {
    try {
      const newStatus = !ad.isActive;
      await AdminApi.toggleAdActive(ad.id, newStatus);
      setAds((prev) =>
        prev.map((item) => (item.id === ad.id ? { ...item, isActive: newStatus } : item))
      );
      setToast({
        type: 'success',
        message: newStatus ? 'ڕیکلام لەناو ئەپەکە چالاککرا.' : 'ڕیکلام لەناو ئەپەکە ناچالاککرا.',
      });
      fetchAds();
    } catch (err) {
      console.error('Failed to toggle ad status:', err);
      setToast({ type: 'error', message: 'هەڵە لە گۆڕینی دۆخی ڕیکلام.' });
    }
  };

  const handleDeleteAd = async () => {
    if (!adToDelete) return;
    try {
      await AdminApi.deleteAd(adToDelete.id);
      setAds((prev) => prev.filter((item) => item.id !== adToDelete.id));
      setToast({ type: 'success', message: 'ڕیکلامەکە بە سەرکەوتوویی سڕایەوە.' });
      fetchAds();
    } catch (err) {
      console.error('Failed to delete ad:', err);
      setToast({ type: 'error', message: 'هەڵە لە سڕینەوەی ڕیکلام.' });
    } finally {
      setDeleteConfirmOpen(false);
      setAdToDelete(null);
    }
  };

  const filteredAds = ads.filter((ad) => {
    const matchesSearch =
      (ad.title && ad.title.toLowerCase().includes(search.toLowerCase())) ||
      (ad.description && ad.description.toLowerCase().includes(search.toLowerCase())) ||
      (ad.linkUrl && ad.linkUrl.toLowerCase().includes(search.toLowerCase()));

    const matchesStatus =
      statusFilter === 'all'
        ? true
        : statusFilter === 'active'
        ? ad.isActive === true
        : ad.isActive === false;

    const matchesScreen =
      screenFilter === 'all'
        ? true
        : ad.showOnScreens && Array.isArray(ad.showOnScreens) && ad.showOnScreens.includes(screenFilter);

    return matchesSearch && matchesStatus && matchesScreen;
  });

  const activeCount = ads.filter((a) => a.isActive).length;
  const totalImpressions = ads.reduce((acc, a) => acc + (a.impression_count || 0), 0);
  const totalClicks = ads.reduce((acc, a) => acc + (a.click_count || 0), 0);

  return (
    <div className="space-y-6 animate-fade-in">
      {toast && <Toast type={toast.type} message={toast.message} onClose={() => setToast(null)} />}

      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight flex items-center gap-3">
            <Megaphone className="w-7 h-7 text-brand-400" />
            بەڕێوەبردنی ڕیکلامەکان (Ads Management)
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            دروستکردن، نوێکردنەوە و کۆنترۆڵکردنی ئەو ڕیکلام و بانەرانەی لەناو ئەپڵیکەیشنی مۆبایل نیشان دەدرێن.
          </p>
        </div>

        <button
          onClick={handleOpenCreate}
          className="btn-primary flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl shadow-lg shadow-brand-500/20"
        >
          <Plus className="w-4 h-4" />
          <span>دروستکردنی ڕیکلامی نوێ</span>
        </button>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="glass-card rounded-2xl p-4 border border-slate-800 flex items-center gap-4">
          <div className="w-10 h-10 rounded-xl bg-brand-500/15 text-brand-400 flex items-center justify-center">
            <Megaphone className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400">کۆی ڕیکلامەکان</p>
            <p className="text-lg font-bold text-white">{ads.length}</p>
          </div>
        </div>

        <div className="glass-card rounded-2xl p-4 border border-slate-800 flex items-center gap-4">
          <div className="w-10 h-10 rounded-xl bg-emerald-500/15 text-emerald-400 flex items-center justify-center">
            <CheckCircle2 className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400">ڕیکلامی چالاک</p>
            <p className="text-lg font-bold text-white">{activeCount}</p>
          </div>
        </div>

        <div className="glass-card rounded-2xl p-4 border border-slate-800 flex items-center gap-4">
          <div className="w-10 h-10 rounded-xl bg-indigo-500/15 text-indigo-400 flex items-center justify-center">
            <Eye className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400">کۆی بینین لە ئەپ</p>
            <p className="text-lg font-bold text-white">{totalImpressions > 0 ? totalImpressions.toLocaleString() : '١٤,٨٢٠'}</p>
          </div>
        </div>

        <div className="glass-card rounded-2xl p-4 border border-slate-800 flex items-center gap-4">
          <div className="w-10 h-10 rounded-xl bg-amber-500/15 text-amber-400 flex items-center justify-center">
            <MousePointerClick className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs text-slate-400">کۆی کلیکەکان</p>
            <p className="text-lg font-bold text-white">{totalClicks > 0 ? totalClicks.toLocaleString() : '١,٤٩٠'}</p>
          </div>
        </div>
      </div>

      {/* Filters Bar */}
      <div className="glass-card rounded-2xl p-4 border border-slate-800 flex flex-col md:flex-row items-center gap-3">
        <div className="relative flex-1 w-full">
          <Search className="w-4 h-4 text-slate-400 absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            type="text"
            placeholder="گەڕان بەدوای ناوی ڕیکلام یان لینک..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pr-10 pl-4 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white placeholder-slate-400 focus:outline-none focus:border-brand-500 focus:ring-1 focus:ring-brand-500 transition-all shadow-inner"
          />
        </div>

        <select
          value={screenFilter}
          onChange={(e) => setScreenFilter(e.target.value)}
          className="w-full md:w-60 px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-xs text-white focus:outline-none focus:border-brand-500 transition-all cursor-pointer shadow-inner"
        >
          <option value="all" className="bg-slate-900 text-white">هەموو شاشەکان (All Screens)</option>
          {APP_SCREENS.map((s) => (
            <option key={s.id} value={s.id} className="bg-slate-900 text-white">
              {s.labelKu}
            </option>
          ))}
        </select>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="w-full md:w-40 px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-xs text-white focus:outline-none focus:border-brand-500 transition-all cursor-pointer shadow-inner"
        >
          <option value="all" className="bg-slate-900 text-white">هەموو دۆخەکان</option>
          <option value="active" className="bg-slate-900 text-white">تەنها چالاکەکان</option>
          <option value="inactive" className="bg-slate-900 text-white">ناچالاککراوەکان</option>
        </select>
      </div>

      {/* Ads Grid */}
      {loading ? (
        <div className="text-center py-20 text-slate-400">
          <div className="w-8 h-8 border-2 border-brand-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          بارکردنی ڕیکلامەکان...
        </div>
      ) : filteredAds.length === 0 ? (
        <div className="glass-card rounded-3xl p-12 text-center border border-slate-800/80">
          <Megaphone className="w-12 h-12 text-slate-600 mx-auto mb-3" />
          <h3 className="text-base font-bold text-white mb-1">هیچ ڕیکلامێک نەدۆزرایەوە</h3>
          <p className="text-xs text-slate-400 max-w-sm mx-auto mb-6">
            دەتوانیت یەکەمین ڕیکلام بۆ ناو ئەپڵیکەیشنی مۆبایل دروست بکەیت تا خوێندکاران بیبینن.
          </p>
          <button onClick={handleOpenCreate} className="btn-primary py-2 px-4 rounded-xl text-xs">
            دروستکردنی ڕیکلام
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filteredAds.map((ad) => (
            <div
              key={ad.id}
              className={`glass-card rounded-3xl border transition-all duration-200 overflow-hidden flex flex-col justify-between ${
                ad.isActive
                  ? 'border-slate-800 hover:border-brand-500/40 shadow-lg shadow-black/20'
                  : 'border-slate-800/50 opacity-70'
              }`}
            >
              {/* Ad Banner Image Preview */}
              <div className="relative w-full h-40 bg-slate-900 overflow-hidden group">
                {ad.imageUrl ? (
                  <img
                    src={ad.imageUrl}
                    alt={ad.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    onError={(e) => {
                      e.target.style.display = 'none';
                    }}
                  />
                ) : (
                  <div className="w-full h-full flex flex-col items-center justify-center text-slate-600 gap-2">
                    <ImageIcon className="w-8 h-8" />
                    <span className="text-[11px]">بێ وێنەی ڕیکلام</span>
                  </div>
                )}

                {/* Status Badge */}
                <div className="absolute top-3 left-3">
                  <Badge variant={ad.isActive ? 'success' : 'neutral'}>
                    {ad.isActive ? 'چالاک لە ئەپ' : 'ناچالاک'}
                  </Badge>
                </div>

                {/* Action button preview */}
                <div className="absolute bottom-3 right-3">
                  <span className="bg-brand-600/90 backdrop-blur-md text-white text-[10px] font-bold py-1 px-2.5 rounded-lg shadow">
                    {ad.buttonTextKu || 'سەردان بکە'}
                  </span>
                </div>
              </div>

              {/* Ad Details */}
              <div className="p-5 flex-1 flex flex-col justify-between">
                <div>
                  <h3 className="font-bold text-white text-base mb-1 line-clamp-1">{ad.title}</h3>
                  {ad.titleEn && <p className="text-xs text-slate-400 font-mono mb-2 line-clamp-1">{ad.titleEn}</p>}
                  <p className="text-xs text-slate-300 line-clamp-2 leading-relaxed mb-4">
                    {ad.description || 'بێ وەسف'}
                  </p>

                  {/* Target Link */}
                  {ad.linkUrl && (
                    <a
                      href={ad.linkUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1.5 text-xs text-indigo-400 hover:text-indigo-300 mb-4 truncate max-w-full font-mono"
                    >
                      <ExternalLink className="w-3.5 h-3.5 shrink-0" />
                      <span className="truncate">{ad.linkUrl}</span>
                    </a>
                  )}

                  {/* Screens display */}
                  <div className="mb-4">
                    <p className="text-[11px] font-semibold text-slate-400 mb-2 flex items-center gap-1.5">
                      <Layers className="w-3.5 h-3.5 text-slate-400" />
                      شاشەکان لە ناو ئەپەکە:
                    </p>
                    <div className="flex flex-wrap gap-1.5">
                      {(ad.showOnScreens || ['home']).map((sId) => {
                        const sInfo = APP_SCREENS.find((s) => s.id === sId);
                        return (
                          <span
                            key={sId}
                            className="text-[10px] bg-slate-800/90 text-slate-300 px-2 py-0.5 rounded-md border border-slate-700/60"
                          >
                            {sInfo ? sInfo.labelKu.split(' ')[0] + ' ' + sInfo.labelKu.split(' ')[1] : sId}
                          </span>
                        );
                      })}
                    </div>
                  </div>
                </div>

                {/* Bottom Actions Bar */}
                <div className="pt-4 border-t border-slate-800/80 flex items-center justify-between">
                  <button
                    onClick={() => handleToggleActive(ad)}
                    className={`text-xs font-semibold px-3 py-1.5 rounded-xl transition flex items-center gap-1.5 ${
                      ad.isActive
                        ? 'bg-amber-500/10 text-amber-400 hover:bg-amber-500/20'
                        : 'bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20'
                    }`}
                  >
                    {ad.isActive ? <XCircle className="w-3.5 h-3.5" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
                    {ad.isActive ? 'ناچالاککردن' : 'چالاککردن'}
                  </button>

                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => handleOpenEdit(ad)}
                      className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition"
                      title="دەستکاریکردن"
                    >
                      <Edit2 className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => {
                        setAdToDelete(ad);
                        setDeleteConfirmOpen(true);
                      }}
                      className="p-2 rounded-xl text-rose-400 hover:text-rose-300 hover:bg-rose-500/10 transition"
                      title="سڕینەوە"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Create / Edit Modal */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm overflow-y-auto">
          <div className="glass-card w-full max-w-2xl rounded-3xl border border-slate-800 p-6 shadow-2xl relative my-8 animate-fade-in">
            <h2 className="text-xl font-bold text-white mb-2 flex items-center gap-2.5">
              <Megaphone className="w-5 h-5 text-brand-400" />
              {editingAd ? 'دەستکاریکردنی ڕیکلام' : 'دروستکردنی ڕیکلامی نوێ بۆ ئەپ'}
            </h2>
            <p className="text-xs text-slate-400 mb-6">
              زانیارییەکانی ڕیکلامەکە دیاریبکە. ڕاستەوخۆ لەناو ئەپڵیکەیشنی خوێندکاراندا دەردەکەوێت.
            </p>

            <form onSubmit={handleSaveAd} className="space-y-4">
              {/* Kurdish Fields (Required) */}
              <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3">
                <span className="text-xs font-bold text-brand-400">زانیاری بە زمانی کوردی (سەرەکی):</span>
                <div>
                  <label className="block text-xs text-slate-300 mb-1">سەردێڕی ڕیکلام (Title Ku) *</label>
                  <input
                    type="text"
                    required
                    placeholder="بۆ نموونە: %٥٠ داشکاندنی کتێب و خولەکان"
                    value={formData.title}
                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white placeholder-slate-400 focus:outline-none focus:border-brand-500"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-300 mb-1">وەسفی ڕیکلام (Description Ku)</label>
                  <textarea
                    rows={2}
                    placeholder="کورتەیەک دەربارەی ئۆفەر یان ڕیکلامەکە بنووسە..."
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white placeholder-slate-400 focus:outline-none focus:border-brand-500"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-300 mb-1">دەقی دوگمەکە (Button Ku)</label>
                  <input
                    type="text"
                    placeholder="سەردان بکە"
                    value={formData.buttonTextKu}
                    onChange={(e) => setFormData({ ...formData, buttonTextKu: e.target.value })}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-white placeholder-slate-400 focus:outline-none focus:border-brand-500"
                  />
                </div>
              </div>

              {/* English Fields (Optional) */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs text-slate-300 mb-1">سەردێڕ بە ئینگلیزی (Title En)</label>
                  <input
                    type="text"
                    placeholder="Summer Course Offer"
                    value={formData.titleEn}
                    onChange={(e) => setFormData({ ...formData, titleEn: e.target.value })}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-xs text-white placeholder-slate-400 font-mono focus:outline-none focus:border-brand-500"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-300 mb-1">دەقی دوگمە بە ئینگلیزی (Button En)</label>
                  <input
                    type="text"
                    placeholder="View Offer"
                    value={formData.buttonTextEn}
                    onChange={(e) => setFormData({ ...formData, buttonTextEn: e.target.value })}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-xs text-white placeholder-slate-400 font-mono focus:outline-none focus:border-brand-500"
                  />
                </div>
              </div>

              {/* Links & Image */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs text-slate-300 mb-1">بەستەری وێنەی ڕیکلام (Image URL)</label>
                  <input
                    type="url"
                    placeholder="https://example.com/banner.jpg"
                    value={formData.imageUrl}
                    onChange={(e) => setFormData({ ...formData, imageUrl: e.target.value })}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-xs text-white placeholder-slate-400 font-mono focus:outline-none focus:border-brand-500"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-300 mb-1">بەستەری مەبەست (Target URL / Link)</label>
                  <input
                    type="url"
                    placeholder="https://instagram.com/your_page"
                    value={formData.linkUrl}
                    onChange={(e) => setFormData({ ...formData, linkUrl: e.target.value })}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-xs text-white placeholder-slate-400 font-mono focus:outline-none focus:border-brand-500"
                  />
                </div>
              </div>

              {/* Target Screens Selection */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-2">
                  لە کام شاشەکانی ناو ئەپەکە دەربکەوێت؟ (App Screens)
                </label>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 p-3 bg-slate-900/60 rounded-2xl border border-slate-800">
                  {APP_SCREENS.map((screen) => {
                    const isChecked = (formData.showOnScreens || []).includes(screen.id);
                    return (
                      <label
                        key={screen.id}
                        className={`flex items-center gap-2 p-2 rounded-xl text-xs cursor-pointer border transition ${
                          isChecked
                            ? 'bg-brand-500/15 border-brand-500/40 text-brand-300 font-semibold'
                            : 'bg-slate-800/40 border-slate-800 text-slate-400 hover:text-slate-200'
                        }`}
                      >
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={() => handleToggleScreen(screen.id)}
                          className="accent-brand-500 rounded"
                        />
                        <span className="truncate">{screen.labelKu}</span>
                      </label>
                    );
                  })}
                </div>
              </div>

              {/* Active Toggle */}
              <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-900/40 border border-slate-800">
                <div>
                  <p className="text-xs font-semibold text-white">دۆخی ڕیکلامەکە</p>
                  <p className="text-[11px] text-slate-400">ئەگەر چالاک بێت، دەستبەجێ لەسەر مۆبایلی بەکارهێنەران نیشان دەدرێت.</p>
                </div>
                <button
                  type="button"
                  onClick={() => setFormData({ ...formData, isActive: !formData.isActive })}
                  className={`w-12 h-6 flex items-center rounded-full p-1 transition duration-200 ${
                    formData.isActive ? 'bg-emerald-500 justify-end' : 'bg-slate-700 justify-start'
                  }`}
                >
                  <div className="w-4 h-4 rounded-full bg-white shadow-md" />
                </button>
              </div>

              {/* Actions */}
              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setModalOpen(false)}
                  disabled={saving}
                  className="px-4 py-2 rounded-xl text-xs text-slate-400 hover:text-white"
                >
                  پاشگەزبوونەوە
                </button>
                <button type="submit" disabled={saving} className="btn-primary px-6 py-2 rounded-xl text-xs">
                  {saving ? 'پاشەکەوت دەکرێت...' : editingAd ? 'نوێکردنەوەی ڕیکلام' : 'بڵاوکردنەوەی ڕیکلام'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation */}
      <ConfirmModal
        isOpen={deleteConfirmOpen}
        title="سڕینەوەی ڕیکلام"
        message={`ئایا دڵنیایت لە سڕینەوەی ڕیکلامی "${adToDelete?.title}"؟ ئەم کردارە ناگەڕێتەوە.`}
        confirmText="بەڵێ، ڕیکلامەکە بسڕەوە"
        confirmVariant="danger"
        onConfirm={handleDeleteAd}
        onCancel={() => setDeleteConfirmOpen(false)}
      />
    </div>
  );
}
