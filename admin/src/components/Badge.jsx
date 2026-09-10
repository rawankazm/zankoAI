import React from 'react';

export default function Badge({ variant = 'default', children, className = '' }) {
  const variants = {
    default: 'bg-slate-800 text-slate-300 border border-slate-700',
    primary: 'bg-indigo-950/70 text-indigo-400 border border-indigo-800/60',
    success: 'bg-emerald-950/70 text-emerald-400 border border-emerald-800/60',
    warning: 'bg-amber-950/70 text-amber-400 border border-amber-800/60',
    danger: 'bg-rose-950/70 text-rose-400 border border-rose-800/60',
    purple: 'bg-purple-950/70 text-purple-400 border border-purple-800/60',
  };

  return (
    <span className={`badge ${variants[variant] || variants.default} ${className}`}>
      {children}
    </span>
  );
}
