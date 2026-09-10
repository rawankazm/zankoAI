import React from 'react';
import { AlertTriangle, X } from 'lucide-react';
import LoadingSpinner from './LoadingSpinner';

export default function ConfirmModal({
  isOpen,
  title = 'دڵنیابوونەوە لە کرداری هەستیار',
  message = 'ئایا دڵنیایت لە ئەنجامدانی ئەم کردارە؟ گۆڕانکارییەکان تۆمار دەکرێن لە یۆمەنەی ئاسایشدا.',
  confirmText = 'پشتڕاستکردنەوە',
  cancelText = 'پاشگەزبوونەوە',
  danger = true,
  loading = false,
  onConfirm,
  onCancel,
  children,
}) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-fade-in">
      <div className="relative w-full max-w-lg glass-panel rounded-2xl p-6 shadow-2xl border border-slate-700">
        <button
          onClick={onCancel}
          disabled={loading}
          className="absolute top-4 left-4 p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="flex items-start gap-4 mb-4">
          <div className={`p-3 rounded-xl ${danger ? 'bg-rose-500/10 text-rose-400 border border-rose-500/20' : 'bg-brand-500/10 text-brand-400 border border-brand-500/20'}`}>
            <AlertTriangle className="w-6 h-6" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-slate-100">{title}</h3>
            <p className="text-sm text-slate-400 mt-1">{message}</p>
          </div>
        </div>

        {children && <div className="my-4">{children}</div>}

        <div className="flex items-center justify-end gap-3 mt-6 pt-4 border-t border-slate-800">
          <button
            type="button"
            onClick={onCancel}
            disabled={loading}
            className="px-4 py-2 text-sm font-medium text-slate-300 hover:text-white bg-slate-800 hover:bg-slate-700 rounded-xl transition-colors"
          >
            {cancelText}
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={loading}
            className={`px-5 py-2 text-sm font-semibold rounded-xl flex items-center gap-2 transition-all ${
              danger
                ? 'bg-rose-600 hover:bg-rose-500 text-white shadow-lg shadow-rose-900/30'
                : 'bg-brand-600 hover:bg-brand-500 text-white shadow-lg shadow-brand-900/30'
            }`}
          >
            {loading && <LoadingSpinner size="sm" />}
            {confirmText}
          </button>
        </div>
      </div>
    </div>
  );
}
