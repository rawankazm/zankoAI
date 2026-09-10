import React from 'react';
import { CheckCircle2, AlertTriangle, XCircle, Info, X } from 'lucide-react';

export default function Toast({ message, type = 'info', onClose }) {
  if (!message) return null;

  const icons = {
    success: <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />,
    warning: <AlertTriangle className="w-5 h-5 text-amber-400 shrink-0" />,
    error: <XCircle className="w-5 h-5 text-rose-400 shrink-0" />,
    info: <Info className="w-5 h-5 text-indigo-400 shrink-0" />,
  };

  const borders = {
    success: 'border-emerald-500/40 bg-slate-900/95 text-emerald-200',
    warning: 'border-amber-500/40 bg-slate-900/95 text-amber-200',
    error: 'border-rose-500/40 bg-slate-900/95 text-rose-200',
    info: 'border-indigo-500/40 bg-slate-900/95 text-indigo-200',
  };

  return (
    <div className="fixed bottom-6 left-6 z-50 max-w-md animate-slide-up shadow-2xl">
      <div className={`flex items-center gap-3 p-4 rounded-xl border backdrop-blur-lg ${borders[type] || borders.info}`}>
        {icons[type] || icons.info}
        <p className="text-sm font-medium flex-1">{message}</p>
        {onClose && (
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white p-1 rounded-lg transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>
    </div>
  );
}
