/**
 * Text Cleaning & Phonetics Normalization for Multilingual TTS
 * Supports Kurdish (Sorani), Arabic, and English
 */

export class TTSTextCleaner {
  /**
   * Cleans Markdown, code syntax, citations, and formatting for natural speech synthesis
   */
  static cleanForSpeech(rawText: string, language: string = 'ku'): string {
    if (!rawText || rawText.trim().length === 0) return '';

    let text = rawText
      // Remove code blocks and convert to natural speech notice
      .replace(/```[a-zA-Z]*\n([\s\S]*?)```/g, (_match, code) => {
        const lineCount = code.trim().split('\n').length;
        if (language === 'ku') return ` نموونەی کۆد بە ${lineCount} دێڕ `;
        if (language === 'ar') return ` مثال برمجي في ${lineCount} أسطر `;
        return ` Code snippet with ${lineCount} lines `;
      })
      // Remove inline code
      .replace(/`([^`]+)`/g, '$1')
      // Convert markdown links [Text](URL) -> Text
      .replace(/\[([^\]]+)\]\([^\)]+\)/g, '$1')
      // Remove markdown headings, bold, italic, strikethrough, blockquotes
      .replace(/^#{1,6}\s+/gm, '')
      .replace(/[*_~`]/g, '')
      .replace(/^>\s+/gm, '')
      // Remove LaTeX / Math delimiters and dollar signs
      .replace(/\$\$[\s\S]*?\$\$/g, ' ')
      .replace(/\$[^\$]+\$/g, ' ')
      .replace(/\\\[[\s\S]*?\\\]/g, ' ')
      .replace(/\\\([\s\S]*?\\\)/g, ' ')
      // Remove UI symbols and emojis
      .replace(/[\u{1F300}-\u{1F9FF}]/gu, '')
      .replace(/[\u{2600}-\u{26FF}]/gu, '')
      .replace(/[\u{2700}-\u{27BF}]/gu, '')
      .replace(/[•●▪■◆★☆✓✔✕✖]/g, ' ')
      // Normalize whitespace
      .replace(/\s+/g, ' ')
      .trim();

    if (language === 'ku') {
      text = this.normalizeKurdishPhonetics(text);
    } else if (language === 'ar') {
      text = this.normalizeArabicPhonetics(text);
    }

    return text;
  }

  /**
   * Kurdish Sorani phonetic normalization for smooth, natural TTS pronunciation
   */
  static normalizeKurdishPhonetics(text: string): string {
    let result = text;

    // Technical acronym expansions in Kurdish phonetics
    const acronyms: Record<string, string> = {
      PDF: 'پی دی ئێف',
      AI: 'ئەی ئای',
      IT: 'ئای تی',
      API: 'ئەی پی ئای',
      HTML: 'ئێچ تی ئێم ئێڵ',
      CSS: 'سی ئێس ئێس',
      SQL: 'ئێس کیوو ئێڵ',
      CPU: 'سی پی یو',
      GPU: 'جی پی یو',
      RAM: 'ڕام',
      ROM: 'ڕۆم',
      USB: 'یو ئێس بی',
      URL: 'یو ئاڕ ئێڵ',
      UI: 'یوو ئای',
      UX: 'یوو ئێکس',
      OS: 'ئۆ ئێس',
    };

    for (const [acronym, spoken] of Object.entries(acronyms)) {
      const reg = new RegExp(`\\b${acronym}\\b`, 'gi');
      result = result.replace(reg, spoken);
    }

    // Kurdish numeral word conversions (0-9)
    const digits: Record<string, string> = {
      '0': ' صفر ',
      '٠': ' صفر ',
      '1': ' یەک ',
      '١': ' یەک ',
      '2': ' دوو ',
      '٢': ' دوو ',
      '3': ' سێ ',
      '٣': ' سێ ',
      '4': ' چوار ',
      '٤': ' چوار ',
      '5': ' پێنج ',
      '٥': ' پێنج ',
      '6': ' شەش ',
      '٦': ' شەش ',
      '7': ' حەوت ',
      '٧': ' حەوت ',
      '8': ' هەشت ',
      '٨': ' هەشت ',
      '9': ' نۆ ',
      '٩': ' نۆ ',
    };

    for (const [digit, word] of Object.entries(digits)) {
      result = result.split(digit).join(word);
    }

    // Punctuation normalization for natural pacing and breath pauses
    result = result
      .replace(/[;؛]/g, '،')
      .replace(/[:]/g, '، ')
      .replace(/[—–]/g, '، ')
      .replace(/[«»"“”]/g, '')
      .replace(/\s+/g, ' ')
      .trim();

    return result;
  }

  /**
   * Arabic phonetic and punctuation normalization
   */
  static normalizeArabicPhonetics(text: string): string {
    return text
      .replace(/[;؛]/g, '،')
      .replace(/[—–]/g, '، ')
      .replace(/[«»"“”]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Splits long educational text into safe chunks (<= maxChunkChars)
   * Splits at paragraph boundaries, sentence boundaries, punctuation, or safe word boundaries.
   * NEVER cuts words, URLs, or mathematical expressions in half!
   */
  static splitIntoChunks(text: string, maxChunkChars: number = 280): string[] {
    const cleaned = text.trim();
    if (!cleaned) return [];
    if (cleaned.length <= maxChunkChars) return [cleaned];

    const chunks: string[] = [];

    // 1. Split by paragraphs or sentence ends (. ! ? ، ؟ \n)
    const sentenceRegex = /(?<=[.،!؟\n;؛?])\s+/;
    const rawSentences = cleaned.split(sentenceRegex);

    let currentChunk = '';

    for (const sentence of rawSentences) {
      const s = sentence.trim();
      if (!s) continue;

      if (currentChunk.length === 0) {
        currentChunk = s;
      } else if (currentChunk.length + s.length + 1 <= maxChunkChars) {
        currentChunk += ` ${s}`;
      } else {
        chunks.push(currentChunk);
        currentChunk = s;
      }
    }

    if (currentChunk.length > 0) {
      chunks.push(currentChunk);
    }

    // 2. Further split any individual sentence that still exceeds maxChunkChars
    const safeFinalChunks: string[] = [];

    for (const chunk of chunks) {
      if (chunk.length <= maxChunkChars) {
        safeFinalChunks.push(chunk);
      } else {
        const words = chunk.split(' ');
        let sub = '';
        for (const w of words) {
          if (sub.length + w.length + 1 <= maxChunkChars) {
            sub = sub.length === 0 ? w : `${sub} ${w}`;
          } else {
            if (sub.length > 0) safeFinalChunks.push(sub);
            sub = w;
          }
        }
        if (sub.length > 0) safeFinalChunks.push(sub);
      }
    }

    return safeFinalChunks.filter((c) => c.trim().length > 0);
  }
}
