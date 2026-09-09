import 'dart:io';

void main() {
  final content = '''import { useState } from 'react'
import { sendNotification, sendDirectMessage } from '../services/adminService'

const TEMPLATES = [
  { label: '👑 VIP پیرۆزبایی', title: '👑 پیرۆزە! بوویت بە VIP', body: 'پیرۆزە! هەژمارەکەت لە ZankoAI بە سەرکەوتوویی بوو بە VIP 👑. ئێستا دەتوانیت سوود لە سەرجەم تایبەتمەندییە بێسنوورەکان وەربگریت 🎉' },
  { label: '📢 ئاگاداری نوێ', title: '📢 ئاگاداری گرنگ لە ZankoAI!', body: 'سیستەمی ZankoAI نوێکرایەوە. بۆ سوودمەندبوون لە خزمەتگوزاری و تایبەتمەندییە نوێیەکان، تکایە ئەپەکەت نوێ بکەرەوە.' },
  { label: '📚 تاقیکردنەوەکان', title: '🎓 ئامادەکاری بۆ تاقیکردنەوەکان!', body: 'کاتی تاقیکردنەوەکان نزیک بووەتەوە. ئێستا لەگەڵ مامۆستای زیرەک پرسیارەکان شی بکەرەوە و پرسیاری ئەگەری وەربگرە! 💡' },
  { label: '🎁 داشکاندنی تایبەت', title: '🎁 ئۆفەری داشکاندنی تایبەت', body: 'داشکاندنی کاتی بۆ بەشداربوونی VIP! بە کەمترین نرخ ببە خاوەنی خزمەتگوزارییە پێشکەوتووەکانی ZankoAI.' },
]

export default function Notifications({ user: adminUser }) {
  const [title, setTitle]   = useState('')
  const [body, setBody]     = useState('')
  const [target, setTarget] = useState('all') // 'all' | 'vip' | 'user' | 'direct'
  const [userId, setUserId] = useState('')
  const [loading, setLoading] = useState(false)
  const [toast, setToast]   = useState(null)
  const [history, setHistory] = useState([])

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 3000)
  }

  const handleSend = async () => {
    if (!title.trim() || !body.trim()) return showToast('تکایە ناونیشان و دەقی ئاگاداری بنووسە', 'error')
    if ((target === 'user' || target === 'direct') && !userId.trim()) return showToast('تکایە IDی بەکارهێنەر بنووسە', 'error')

    setLoading(true)
    try {
      if (target === 'direct') {
        await sendDirectMessage({ userId, title, message: body, adminEmail: adminUser?.email })
        showToast('✉️ پەیامی تایبەت (In-App) بە سەرکەوتوویی نێردرا!')
      } else {
        await sendNotification({ title, body, target, userId: target === 'user' ? userId : null, adminEmail: adminUser?.email })
        showToast('🔔 ئاگادارییەکە بە سەرکەوتوویی بۆ قوتابیان نێردرا!')
      }
      const entry = { title, body, target, userId: (target === 'user' || target === 'direct') ? userId : null, sentAt: new Date() }
      setHistory(h => [entry, ...h].slice(0, 10))
      setTitle(''); setBody(''); setUserId('')
    } catch (e) {
      showToast('❌ هەڵە: ' + e.message, 'error')
    }
    setLoading(false)
  }

  return (
    <>
      <div className="page-header">
        <h1>🔔 ئاگادارییەکان (Notifications)</h1>
        <p>ناردنی ئاگاداری فەرمی و ئاگادارییەکانی مۆبایل بۆ قوتابیان</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: 20 }}>
        {/* Compose */}
        <div className="card">
          <div className="section-header">
            <span className="section-title">✏️ دروستکردنی ئاگاداری نوێ</span>
          </div>

          {/* Templates */}
          <div style={{ marginBottom: 20 }}>
            <label>قالبە ئامادەکراوەکان:</label>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {TEMPLATES.map(t => (
                <button
                  key={t.label}
                  className="btn btn-ghost btn-sm"
                  onClick={() => { setTitle(t.title); setBody(t.body) }}
                >{t.label}</button>
              ))}
            </div>
          </div>

          <div className="form-group">
            <label>ناونیشانی ئاگاداری (Title)</label>
            <input className="input" placeholder="نموونە: 👑 پیرۆزە! بوویت بە VIP" value={title} onChange={e => setTitle(e.target.value)} />
          </div>
          <div className="form-group">
            <label>دەقی ئاگاداری (Body)</label>
            <textarea
              className="input"
              rows={4}
              placeholder="دەقی ئاگادارییەکە لێرە بنووسە..."
              value={body}
              onChange={e => setBody(e.target.value)}
              style={{ resize: 'vertical' }}
            />
          </div>

          {/* Target */}
          <div className="form-group">
            <label>ناردن بۆ کێ؟</label>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {[
                ['all', '📢 گشت قوتابیان (FCM)'],
                ['vip', '👑 تەنها ئەندامانی VIP'],
                ['user', '👤 قوتابییەکی دیاریکراو (Push)'],
                ['direct', '✉️ پەیامی ناوەخۆ (In-App)'],
              ].map(([v, l]) => (
                <button
                  key={v}
                  className={`btn btn-sm \${target === v ? 'btn-primary' : 'btn-ghost'}`}
                  onClick={() => setTarget(v)}
                >{l}</button>
              ))}
            </div>
          </div>

          {(target === 'user' || target === 'direct') && (
            <div className="form-group">
              <label>IDی بەکارهێنەر (User ID)</label>
              <input className="input" placeholder="UUID ی بەکارهێنەر لە سیستەم" value={userId} onChange={e => setUserId(e.target.value)} />
            </div>
          )}

          {/* Preview */}
          {(title || body) && (
            <div style={{
              background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 14,
              padding: 16, marginBottom: 20,
            }}>
              <div style={{ fontSize: 11, color: 'var(--text2)', marginBottom: 8 }}>📱 پێشبینین لە مۆبایل:</div>
              <div style={{
                background: 'var(--card2)', borderRadius: 12, padding: '12px 16px',
                boxShadow: '0 4px 20px rgba(0,0,0,0.4)',
              }}>
                <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                  <div style={{ fontSize: 28 }}>🔔</div>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: 14, marginBottom: 3 }}>{title || 'ناونیشان...'}</div>
                    <div style={{ fontSize: 12, color: 'var(--text2)', lineHeight: 1.5 }}>{body || 'دەق...'}</div>
                  </div>
                </div>
              </div>
            </div>
          )}

          <button className="btn btn-primary btn-lg" onClick={handleSend} disabled={loading} style={{ width: '100%', justifyContent: 'center' }}>
            {loading ? '⏳ دەنێردرێت...' : '🚀 ناردنی ئاگاداری بە دەستبەجێ'}
          </button>
        </div>

        {/* History */}
        <div className="card" style={{ alignSelf: 'flex-start' }}>
          <div className="section-header">
            <span className="section-title">📜 دوایین ئاگادارییە نێردراوەکان</span>
          </div>
          {history.length === 0 ? (
            <div className="empty-state" style={{ padding: '40px 20px' }}>
              <div className="icon">📭</div>
              <h3>هیچ ئاگادارییەک نەنێردراوە</h3>
            </div>
          ) : history.map((h, i) => (
            <div key={i} style={{
              borderBottom: i < history.length - 1 ? '1px solid var(--border)' : 'none',
              paddingBottom: 14, marginBottom: 14,
            }}>
              <div style={{ fontWeight: 600, fontSize: 13, marginBottom: 4 }}>{h.title}</div>
              <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 6 }}>{h.body.slice(0, 60)}...</div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <span className="badge badge-approved" style={{ fontSize: 10 }}>{h.target}</span>
                <span style={{ fontSize: 11, color: 'var(--text3)' }}>{h.sentAt.toLocaleTimeString()}</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {toast && <div className={`toast \${toast.type}`}>{toast.msg}</div>}
    </>
  )
}
''';

  File(r'C:\dev\zanko-admin\src\pages\Notifications.jsx').writeAsStringSync(content);
  print('Successfully rewrote C:\\dev\\zanko-admin\\src\\pages\\Notifications.jsx in clean Kurdish UTF-8');
}
