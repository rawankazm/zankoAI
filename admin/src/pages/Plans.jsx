import React, { useState, useEffect } from 'react';
import { Sliders, Save, CheckCircle2, AlertCircle, Shield } from 'lucide-react';
import { AdminApi } from '../services/api';
import Badge from '../components/Badge';
import LoadingSpinner from '../components/LoadingSpinner';
import Toast from '../components/Toast';

export default function Plans() {
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [savingId, setSavingId] = useState(null);
  const [toast, setToast] = useState(null);

  const fetchLimits = async () => {
    setLoading(true);
    try {
      const data = await AdminApi.listPlanLimits();
      if (data && data.length > 0) {
        setPlans(data);
      } else {
        // Fallback seed structure if table is newly provisioned
        setPlans([
          {
            id: 'free-default',
            plan: 'free',
            ai_chat_daily_limit: 15,
            pdf_monthly_limit: 10,
            ocr_monthly_limit: 15,
            audio_monthly_limit: 5,
            homework_daily_limit: 5,
            quiz_monthly_limit: 10,
            flashcard_monthly_limit: 10,
            storage_limit_mb: 250,
          },
          {
            id: 'premium-default',
            plan: 'premium',
            ai_chat_daily_limit: 300,
            pdf_monthly_limit: 150,
            ocr_monthly_limit: 200,
            audio_monthly_limit: 60,
            homework_daily_limit: 100,
            quiz_monthly_limit: 200,
            flashcard_monthly_limit: 200,
            storage_limit_mb: 5000,
          },
        ]);
      }
    } catch (err) {
      console.error('Failed to load plan limits:', err);
      setToast({ type: 'error', message: 'هەڵە لە بارکردنی سنوورەکانی پلان.' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLimits();
  }, []);

  const handleChange = (index, field, value) => {
    const updated = [...plans];
    updated[index] = {
      ...updated[index],
      [field]: Number(value) || 0,
    };
    setPlans(updated);
  };

  const handleSave = async (planObj) => {
    setSavingId(planObj.id);
    try {
      if (planObj.id.includes('default')) {
        await AdminApi.createPlanLimit(planObj);
      } else {
        await AdminApi.updatePlanLimit(planObj.id, planObj);
      }
      setToast({ type: 'success', message: `سنوورەکانی پلانی ${planObj.plan} بە سەرکەوتوویی نوێکرانەوە.` });
      fetchLimits();
    } catch (err) {
      setToast({ type: 'error', message: err.response?.data?.message || 'هەڵە لە پاشەکەوتکردن.' });
    } finally {
      setSavingId(null);
    }
  };

  if (loading) {
    return (
      <div className="py-24 flex flex-col items-center justify-center gap-4">
        <LoadingSpinner size="lg" />
        <p className="text-sm text-slate-400">بارکردنی ڕێکخستنی پلانەکان...</p>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight">بەڕێوەبردنی سنووری پلانەکان (Plan Limits)</h1>
          <p className="text-xs text-slate-400 mt-1">
            دیاریکردنی کوۆتای ڕۆژانە و مانگانە بۆ چات، PDF، OCR، دەنگ، تاقیکردنەوە و بیرگە
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {plans.map((p, idx) => (
          <div key={p.id || idx} className="glass-card rounded-2xl p-6 border border-slate-800 space-y-6">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-2.5">
                <Sliders className="w-5 h-5 text-brand-400" />
                <h3 className="text-base font-bold text-white uppercase">{p.plan}</h3>
              </div>
              <Badge variant={p.plan === 'premium' ? 'success' : 'default'}>
                {p.plan === 'premium' ? 'پلانی پریمیۆم (VIP)' : 'پلانی بەخۆڕایی (Free)'}
              </Badge>
            </div>

            <div className="grid grid-cols-2 gap-4 text-xs">
              <div>
                <label className="block text-slate-400 font-medium mb-1">چاتی ڕۆژانە (AI Chat):</label>
                <input
                  type="number"
                  value={p.ai_chat_daily_limit}
                  onChange={(e) => handleChange(idx, 'ai_chat_daily_limit', e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white font-mono focus:outline-none focus:border-brand-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">شیكردنەوەی پەڕگەی PDF (مانگانە):</label>
                <input
                  type="number"
                  value={p.pdf_monthly_limit}
                  onChange={(e) => handleChange(idx, 'pdf_monthly_limit', e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white font-mono focus:outline-none focus:border-brand-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">خوێندنەوەی دەق OCR (مانگانە):</label>
                <input
                  type="number"
                  value={p.ocr_monthly_limit}
                  onChange={(e) => handleChange(idx, 'ocr_monthly_limit', e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white font-mono focus:outline-none focus:border-brand-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">دەنگی وانەکان Audio (مانگانە):</label>
                <input
                  type="number"
                  value={p.audio_monthly_limit}
                  onChange={(e) => handleChange(idx, 'audio_monthly_limit', e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white font-mono focus:outline-none focus:border-brand-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">ئەرکی ماڵەوە Homework (ڕۆژانە):</label>
                <input
                  type="number"
                  value={p.homework_daily_limit}
                  onChange={(e) => handleChange(idx, 'homework_daily_limit', e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white font-mono focus:outline-none focus:border-brand-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">تاقیکردنەوە Quiz (مانگانە):</label>
                <input
                  type="number"
                  value={p.quiz_monthly_limit}
                  onChange={(e) => handleChange(idx, 'quiz_monthly_limit', e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white font-mono focus:outline-none focus:border-brand-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">فلاشکارت Flashcards (مانگانە):</label>
                <input
                  type="number"
                  value={p.flashcard_monthly_limit}
                  onChange={(e) => handleChange(idx, 'flashcard_monthly_limit', e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white font-mono focus:outline-none focus:border-brand-500"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">قەبارەی بیرگە (MB):</label>
                <input
                  type="number"
                  value={p.storage_limit_mb}
                  onChange={(e) => handleChange(idx, 'storage_limit_mb', e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-white font-mono focus:outline-none focus:border-brand-500"
                />
              </div>
            </div>

            <div className="pt-4 border-t border-slate-800 flex justify-end">
              <button
                onClick={() => handleSave(p)}
                disabled={savingId === p.id}
                className="px-5 py-2.5 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-semibold text-xs flex items-center gap-2 shadow-lg shadow-brand-900/30 transition-all disabled:opacity-50"
              >
                {savingId === p.id ? <LoadingSpinner size="sm" /> : <Save className="w-4 h-4" />}
                <span>پاشەکەوتکردنی سنوورەکان</span>
              </button>
            </div>
          </div>
        ))}
      </div>

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
    </div>
  );
}
